import Foundation
import EntityAuthCore
import EntityAuthNetworking

public protocol AuthProviding: Sendable {
    func register(request: RegisterRequest) async throws
    func login(request: LoginRequest) async throws -> LoginResponse
    func refresh() async throws -> RefreshResponse
    func logout(sessionId: String?, refreshToken: String?) async throws
    // Passkeys
    func beginRegistration(workspaceTenantId: String, userId: String, rpId: String, origins: [String]) async throws -> BeginRegistrationResponse
    func beginRegistrationWithEmail(workspaceTenantId: String, email: String, rpId: String, origins: [String]) async throws -> BeginRegistrationResponse
    func finishRegistration(workspaceTenantId: String, challengeId: String, userId: String, credential: WebAuthnRegistrationCredential) async throws -> FinishRegistrationResponse
    func finishRegistrationWithEmail(workspaceTenantId: String, challengeId: String, email: String, credential: WebAuthnRegistrationCredential) async throws -> LoginResponse
    func beginAuthentication(workspaceTenantId: String, userId: String?, rpId: String, origins: [String]) async throws -> BeginAuthenticationResponse
    func finishAuthentication(workspaceTenantId: String, challengeId: String, credential: WebAuthnAuthenticationCredential, userId: String?) async throws -> LoginResponse
}

public final class AuthService: AuthProviding, RefreshService {
    private let client: APIClientType
    private let authState: AuthState

    public init(client: APIClientType, authState: AuthState) {
        self.client = client
        self.authState = authState
    }

    public func register(request: RegisterRequest) async throws {
        let body = try JSONEncoder().encode(request)
        let apiRequest = APIRequest(method: .post, path: "/api/auth/register", headers: ["content-type": "application/json"], body: body, requiresAuthentication: false)
        _ = try await client.send(apiRequest)
    }

    public func login(request: LoginRequest) async throws -> LoginResponse {
        let body = try JSONEncoder().encode(request)
        let apiRequest = APIRequest(method: .post, path: "/api/auth/login", headers: ["content-type": "application/json"], body: body, requiresAuthentication: false)
        return try await client.send(apiRequest, decode: LoginResponse.self)
    }

    public func refresh() async throws -> RefreshResponse {
        var headers: [String: String] = ["content-type": "application/json"]
        if let refreshToken = await authState.currentTokens.refreshToken {
            headers["x-refresh-token"] = refreshToken
        }
        let apiRequest = APIRequest(method: .post, path: "/api/auth/refresh", headers: headers, requiresAuthentication: false)
        return try await client.send(apiRequest, decode: RefreshResponse.self)
    }

    public func logout(sessionId: String?, refreshToken: String?) async throws {
        var headers: [String: String] = ["content-type": "application/json"]
        if let refreshToken {
            headers["x-refresh-token"] = refreshToken
        }
        let payload: [String: String?] = [
            "sessionId": sessionId
        ]
        let body = try JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 })
        let apiRequest = APIRequest(method: .post, path: "/api/auth/logout", headers: headers, body: body, requiresAuthentication: false)
        _ = try await client.send(apiRequest)
    }

    // MARK: - Passkeys

    public func beginRegistration(workspaceTenantId: String, userId: String, rpId: String, origins: [String]) async throws -> BeginRegistrationResponse {
        // Backend derives rpId and origins server-side, only send workspaceTenantId and userId
        let payload: [String: String] = [
            "workspaceTenantId": workspaceTenantId,
            "userId": userId
        ]
        let body = try JSONEncoder().encode(payload)
        let request = APIRequest(method: .post, path: "/api/auth/webauthn/begin/registration", headers: ["content-type": "application/json"], body: body, requiresAuthentication: false)
        return try await client.send(request, decode: BeginRegistrationResponse.self)
    }

    public func beginRegistrationWithEmail(workspaceTenantId: String, email: String, rpId: String, origins: [String]) async throws -> BeginRegistrationResponse {
        // Backend derives rpId and origins server-side, only send workspaceTenantId and email
        let payload: [String: String] = [
            "workspaceTenantId": workspaceTenantId,
            "email": email
        ]
        print("[AuthService] beginRegistrationWithEmail payload:", payload)
        let body = try JSONEncoder().encode(payload)
        let request = APIRequest(method: .post, path: "/api/auth/webauthn/begin/registration", headers: ["content-type": "application/json"], body: body, requiresAuthentication: false)
        return try await client.send(request, decode: BeginRegistrationResponse.self)
    }

    public func finishRegistration(workspaceTenantId: String, challengeId: String, userId: String, credential: WebAuthnRegistrationCredential) async throws -> FinishRegistrationResponse {
        struct Payload: Encodable { let workspaceTenantId: String; let challengeId: String; let userId: String; let credential: WebAuthnRegistrationCredential }
        let body = try JSONEncoder().encode(Payload(workspaceTenantId: workspaceTenantId, challengeId: challengeId, userId: userId, credential: credential))
        let request = APIRequest(method: .post, path: "/api/auth/webauthn/finish/registration", headers: ["content-type": "application/json"], body: body, requiresAuthentication: false)
        return try await client.send(request, decode: FinishRegistrationResponse.self)
    }

    public func finishRegistrationWithEmail(workspaceTenantId: String, challengeId: String, email: String, credential: WebAuthnRegistrationCredential) async throws -> LoginResponse {
        struct Payload: Encodable { let workspaceTenantId: String; let challengeId: String; let email: String; let credential: WebAuthnRegistrationCredential }
        let body = try JSONEncoder().encode(Payload(workspaceTenantId: workspaceTenantId, challengeId: challengeId, email: email, credential: credential))
        let request = APIRequest(method: .post, path: "/api/auth/webauthn/finish/registration", headers: ["content-type": "application/json"], body: body, requiresAuthentication: false)
        return try await client.send(request, decode: LoginResponse.self)
    }

    public func beginAuthentication(workspaceTenantId: String, userId: String?, rpId: String, origins: [String]) async throws -> BeginAuthenticationResponse {
        // Backend derives rpId and origins server-side
        struct Payload: Encodable {
            let workspaceTenantId: String
            let userId: String?
        }
        let payload = Payload(workspaceTenantId: workspaceTenantId, userId: userId)
        let body = try JSONEncoder().encode(payload)
        let request = APIRequest(method: .post, path: "/api/auth/webauthn/begin/authentication", headers: ["content-type": "application/json"], body: body, requiresAuthentication: false)
        return try await client.send(request, decode: BeginAuthenticationResponse.self)
    }

    public func finishAuthentication(workspaceTenantId: String, challengeId: String, credential: WebAuthnAuthenticationCredential, userId: String?) async throws -> LoginResponse {
        struct Payload: Encodable { let workspaceTenantId: String; let challengeId: String; let credential: WebAuthnAuthenticationCredential; let userId: String? }
        let body = try JSONEncoder().encode(Payload(workspaceTenantId: workspaceTenantId, challengeId: challengeId, credential: credential, userId: userId))
        let request = APIRequest(method: .post, path: "/api/auth/webauthn/finish/authentication", headers: ["content-type": "application/json"], body: body, requiresAuthentication: false)
        return try await client.send(request, decode: LoginResponse.self)
    }
}
