import Foundation

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

public protocol PasskeyAuthProviding: Sendable {
    func register(userId: String, rpId: String, origins: [String]) async throws -> FinishRegistrationResponse
    func signIn(userId: String?, rpId: String, origins: [String]) async throws -> LoginResponse
}

public final class PasskeyAuthService: NSObject, Sendable {
    private let authService: AuthProviding
    private let workspaceTenantId: String?

    public init(authService: AuthProviding) {
        self.authService = authService
        self.workspaceTenantId = nil
    }

    public init(authService: AuthProviding, workspaceTenantId: String?) {
        self.authService = authService
        self.workspaceTenantId = workspaceTenantId
    }
}

extension PasskeyAuthService: PasskeyAuthProviding {
    public func register(userId: String, rpId: String, origins: [String]) async throws -> FinishRegistrationResponse {
        #if canImport(AuthenticationServices)
        let begin = try await authService.beginRegistration(workspaceTenantId: requiredWorkspace(), userId: userId, rpId: rpId, origins: origins)
        let challenge = try decodeBase64url(begin.options.challenge)
        let userIdData = Data(userId.utf8)

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: begin.options.rpId)
        let request = provider.createCredentialRegistrationRequest(challenge: challenge, name: userId, userID: userIdData)
        request.attestationPreference = .none

        let result = try await performAuthorization(requests: [request])
        guard let reg = result.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            throw EntityAuthError.invalidResponse
        }
        // Build WebAuthn registration credential payload as expected by server
        // Note: rawId and response fields are base64url encoded
        let credential = WebAuthnRegistrationCredential(
            id: reg.credentialID.base64urlEncodedString(),
            rawId: reg.credentialID.base64urlEncodedString(),
            response: .init(
                attestationObject: (reg.rawAttestationObject ?? Data()).base64urlEncodedString(),
                clientDataJSON: (reg.rawClientDataJSON ?? Data()).base64urlEncodedString()
            )
        )
        return try await authService.finishRegistration(
            workspaceTenantId: requiredWorkspace(),
            challengeId: begin.challengeId,
            userId: userId,
            credential: credential
        )
        #else
        throw EntityAuthError.configurationMissingBaseURL
        #endif
    }

    public func signIn(userId: String?, rpId: String, origins: [String]) async throws -> LoginResponse {
        #if canImport(AuthenticationServices)
        let begin = try await authService.beginAuthentication(workspaceTenantId: requiredWorkspace(), userId: userId, rpId: rpId, origins: origins)
        let challenge = try decodeBase64url(begin.options.challenge)
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: begin.options.rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        let result = try await performAuthorization(requests: [request])
        guard let assertion = result.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw EntityAuthError.invalidResponse
        }
        let credential = WebAuthnAuthenticationCredential(
            id: assertion.credentialID.base64urlEncodedString(),
            rawId: assertion.credentialID.base64urlEncodedString(),
            response: .init(
                authenticatorData: assertion.rawAuthenticatorData.base64urlEncodedString(),
                clientDataJSON: assertion.rawClientDataJSON.base64urlEncodedString(),
                signature: assertion.signature.base64urlEncodedString(),
                userHandle: assertion.userID.base64urlEncodedString()
            )
        )
        return try await authService.finishAuthentication(
            workspaceTenantId: requiredWorkspace(),
            challengeId: begin.challengeId,
            credential: credential,
            userId: userId
        )
        #else
        throw EntityAuthError.configurationMissingBaseURL
        #endif
    }
}

// MARK: - Helpers

extension PasskeyAuthService {
    private func requiredWorkspace() -> String {
        // Prefer explicitly provided workspace tenant id if available; fallback to a sensible default
        if let workspaceTenantId, !workspaceTenantId.isEmpty {
            return workspaceTenantId
        }
        return "default"
    }

    #if canImport(AuthenticationServices)
    private func performAuthorization(requests: [ASAuthorizationRequest]) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: requests)
            let delegate = AuthorizationDelegate { result in
                continuation.resume(returning: result)
            } onError: { error in
                continuation.resume(throwing: error)
            }
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            // Keep delegate alive until callbacks
            objc_setAssociatedObject(controller, Unmanaged.passUnretained(controller).toOpaque(), delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            controller.performRequests()
        }
    }
    #endif
}

#if canImport(AuthenticationServices)
private final class AuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let onSuccess: (ASAuthorization) -> Void
    private let onError: (Error) -> Void

    init(onSuccess: @escaping (ASAuthorization) -> Void, onError: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onSuccess(authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onError(error)
    }
}
#endif

private enum EntityAuthError: Error {
    case invalidResponse
    case configurationMissingBaseURL
}

// MARK: - Base64url helpers

private func decodeBase64url(_ s: String) throws -> Data {
    var str = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    let padding = (4 - (str.count % 4)) % 4
    if padding > 0 { str.append(String(repeating: "=", count: padding)) }
    guard let data = Data(base64Encoded: str) else { throw EntityAuthError.invalidResponse }
    return data
}

private extension Data {
    func base64urlEncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}


