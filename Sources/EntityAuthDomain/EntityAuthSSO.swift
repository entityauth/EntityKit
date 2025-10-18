import Foundation
@preconcurrency import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public protocol EntityAuthSSOHandling: AnyObject {
    func startSSO(provider: String, returnTo: URL?, workspaceTenantId: String) async throws -> URL
    func handleCallback(url: URL) async throws -> (accessToken: String, refreshToken: String, sessionId: String, userId: String)
}

public final class EntityAuthSSO: NSObject, EntityAuthSSOHandling, ASWebAuthenticationPresentationContextProviding {
    private let baseURL: URL
    private var webAuthSession: ASWebAuthenticationSession?

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        // Prefer a real window as the anchor to avoid pre-sheet failures
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            if let key = scene.keyWindow { return key }
            if let any = scene.windows.first { return any }
        }
        #endif
        #if canImport(AppKit)
        if let key = NSApplication.shared.keyWindow { return key }
        if let any = NSApplication.shared.windows.first { return any }
        #endif
        return ASPresentationAnchor()
    }

    public func startSSO(provider: String, returnTo: URL?, workspaceTenantId: String) async throws -> URL {
        let url = baseURL.appendingPathComponent("api/auth/sso/start")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        #if DEBUG
        print("[EntityAuthSSO] startSSO url=\(url.absoluteString) tenant=\(workspaceTenantId) provider=\(provider) returnTo=\(returnTo?.absoluteString ?? "/")")
        #endif
        let body: [String: Any] = [
            "workspaceTenantId": workspaceTenantId,
            "provider": provider,
            "returnTo": returnTo?.absoluteString ?? "/",
            "client": "mobile"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            let text = String(data: data, encoding: .utf8) ?? ""
            #if DEBUG
            print("[EntityAuthSSO] startSSO failed status=\(http.statusCode) body=\(text)")
            #endif
            throw NSError(
                domain: "EntityAuthSSO",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "SSO start failed",
                           "status": http.statusCode,
                           "body": text]
            )
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let auth = json?["authorizationUrl"] as? String, let authURL = URL(string: auth) else {
            throw NSError(domain: "EntityAuthSSO", code: 2)
        }
        #if DEBUG
        print("[EntityAuthSSO] startSSO ok authorizationUrl=\(authURL.absoluteString)")
        #endif
        return authURL
    }

    /// Convenience method to perform the full SSO flow on iOS/macOS using ASWebAuthenticationSession.
    /// - Parameters:
    ///   - provider: Provider key, e.g. "google".
    ///   - returnTo: Callback deep-link URL (must be handled by app and be listed in AASA).
    /// - Returns: Access/refresh tokens and identifiers.
    public func signIn(provider: String, returnTo: URL, workspaceTenantId: String) async throws -> (accessToken: String, refreshToken: String, sessionId: String, userId: String) {
        let authURL = try await startSSO(provider: provider, returnTo: returnTo, workspaceTenantId: workspaceTenantId)

        guard let callbackScheme = returnTo.scheme, !callbackScheme.isEmpty else {
            throw NSError(domain: "EntityAuthSSO", code: -3, userInfo: [NSLocalizedDescriptionKey: "Missing callback URL scheme"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Capture baseURL as a local immutable value to avoid any actor context
            let endpointBase = self.baseURL
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: NSError(domain: "EntityAuthSSO", code: -2, userInfo: [NSLocalizedDescriptionKey: "SSO handler deallocated"]))
                    return
                }
                
                // Create a non-Sendable completion that doesn't cross concurrency boundaries
                let completionHandler: (URL?, Error?) -> Void = { callbackURL, error in
                    // This closure must not capture anything actor-isolated
                    // Run the continuation resume in a detached task to break actor context
                    Task.detached {
                        guard let callbackURL else {
                            continuation.resume(with: .failure(error ?? NSError(domain: "EntityAuthSSO", code: -1)))
                            return
                        }
                        var comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
                        let ticket = comps?.queryItems?.first { $0.name == "ticket" }?.value
                        guard let ticket else {
                            continuation.resume(throwing: NSError(domain: "EntityAuthSSO", code: 3))
                            return
                        }
                        var req = URLRequest(url: endpointBase.appendingPathComponent("api/auth/sso/exchange-ticket"))
                        req.httpMethod = "POST"
                        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        req.httpBody = try? JSONSerialization.data(withJSONObject: ["ticket": ticket])
                        
                        let (data, resp, err) = await withCheckedContinuation { dataCont in
                            URLSession.shared.dataTask(with: req) { data, resp, err in
                                dataCont.resume(returning: (data, resp, err))
                            }.resume()
                        }
                        
                        if let err {
                            continuation.resume(throwing: err)
                            return
                        }
                        guard let data, let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                            continuation.resume(throwing: NSError(domain: "EntityAuthSSO", code: 4))
                            return
                        }
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let access = json?["accessToken"] as? String,
                               let refresh = json?["refreshToken"] as? String,
                               let sid = json?["sessionId"] as? String,
                               let uid = json?["userId"] as? String {
                                continuation.resume(returning: (access, refresh, sid, uid))
                            } else {
                                continuation.resume(throwing: NSError(domain: "EntityAuthSSO", code: 5))
                            }
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: callbackScheme,
                    completionHandler: completionHandler
                )
                session.prefersEphemeralWebBrowserSession = true
                session.presentationContextProvider = self
                self.webAuthSession = session
                _ = session.start()
            }
        }
    }

    public func handleCallback(url: URL) async throws -> (accessToken: String, refreshToken: String, sessionId: String, userId: String) {
        return try await EntityAuthSSO.handleCallbackStatic(baseURL: baseURL, url: url)
    }

    private static func handleCallbackStatic(baseURL: URL, url: URL) async throws -> (accessToken: String, refreshToken: String, sessionId: String, userId: String) {
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


