import Foundation
import AuthenticationServices

public protocol EntityAuthSSOHandling: AnyObject {
    func startSSO(provider: String, returnTo: URL?) async throws -> URL
    func handleCallback(url: URL) async throws -> (accessToken: String, refreshToken: String, sessionId: String, userId: String)
}

public final class EntityAuthSSO: NSObject, EntityAuthSSOHandling, ASWebAuthenticationPresentationContextProviding {
    private let baseURL: URL
    private var webAuthSession: ASWebAuthenticationSession?

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }

    public func startSSO(provider: String, returnTo: URL?) async throws -> URL {
        let url = baseURL.appendingPathComponent("api/auth/sso/start")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "workspaceTenantId": "default",
            "provider": provider,
            "returnTo": returnTo?.absoluteString ?? "/",
            "client": "mobile"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "EntityAuthSSO", code: 1)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let auth = json?["authorizationUrl"] as? String, let authURL = URL(string: auth) else {
            throw NSError(domain: "EntityAuthSSO", code: 2)
        }
        return authURL
    }

    /// Convenience method to perform the full SSO flow on iOS/macOS using ASWebAuthenticationSession.
    /// - Parameters:
    ///   - provider: Provider key, e.g. "google".
    ///   - returnTo: Callback deep-link URL (must be handled by app and be listed in AASA).
    /// - Returns: Access/refresh tokens and identifiers.
    @MainActor
    public func signIn(provider: String, returnTo: URL) async throws -> (accessToken: String, refreshToken: String, sessionId: String, userId: String) {
        let authURL = try await startSSO(provider: provider, returnTo: returnTo)

        let callbackScheme = returnTo.scheme ?? ""

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                guard let callbackURL else {
                    continuation.resume(with: .failure(error ?? NSError(domain: "EntityAuthSSO", code: -1)))
                    return
                }
                Task {
                    do {
                        let result = try await self?.handleCallback(url: callbackURL)
                        if let result { continuation.resume(returning: result) }
                        else { continuation.resume(throwing: NSError(domain: "EntityAuthSSO", code: -2)) }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            self.webAuthSession = session
            _ = session.start()
        }
    }

    public func handleCallback(url: URL) async throws -> (accessToken: String, refreshToken: String, sessionId: String, userId: String) {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let ticket = comps?.queryItems?.first { $0.name == "ticket" }?.value
        guard let ticket else { throw NSError(domain: "EntityAuthSSO", code: 3) }
        let endpoint = baseURL.appendingPathComponent("api/auth/sso/exchange-ticket")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["ticket": ticket])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "EntityAuthSSO", code: 4)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard
            let access = json?["accessToken"] as? String,
            let refresh = json?["refreshToken"] as? String,
            let sid = json?["sessionId"] as? String,
            let uid = json?["userId"] as? String
        else { throw NSError(domain: "EntityAuthSSO", code: 5) }
        return (access, refresh, sid, uid)
    }
}


