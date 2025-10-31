import Foundation
import EntityAuthCore
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
        req.setValue(workspaceTenantId, forHTTPHeaderField: "x-workspace-tenant-id")
        req.setValue("mobile", forHTTPHeaderField: "x-client")
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
        EntityAuthDebugLog.log("[EntityAuthSSO] signIn begin provider=\(provider) returnTo=\(returnTo.absoluteString) authURL=\(authURL.absoluteString)")

        guard let callbackScheme = returnTo.scheme, !callbackScheme.isEmpty else {
            throw NSError(domain: "EntityAuthSSO", code: -3, userInfo: [NSLocalizedDescriptionKey: "Missing callback URL scheme"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Capture immutable values to avoid actor context issues
            let endpointBase = self.baseURL
            let captureTenant = workspaceTenantId
            let captureReturnTo = returnTo.absoluteString
            
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
                        if let error { EntityAuthDebugLog.log("[EntityAuthSSO] ASWebAuthenticationSession completed with error:", error.localizedDescription) }
                        if let callbackURL { EntityAuthDebugLog.log("[EntityAuthSSO] received callbackURL=", callbackURL.absoluteString) }
                        guard let callbackURL else {
                            continuation.resume(with: .failure(error ?? NSError(domain: "EntityAuthSSO", code: -1)))
                            return
                        }
                        let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
                        let ticket = comps?.queryItems?.first { $0.name == "ticket" }?.value
                        EntityAuthDebugLog.log("[EntityAuthSSO] parsed ticket=", ticket ?? "<nil>")
                        guard let ticket else {
                            continuation.resume(throwing: NSError(domain: "EntityAuthSSO", code: 3))
                            return
                        }
                        var req = URLRequest(url: endpointBase.appendingPathComponent("api/auth/exchange-ticket"))
                        req.httpMethod = "POST"
                        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        req.setValue(captureTenant, forHTTPHeaderField: "x-workspace-tenant-id")
                        req.setValue("mobile", forHTTPHeaderField: "x-client")
                        let payload: [String: Any] = [
                            "ticket": ticket,
                            "workspaceTenantId": captureTenant,
                            "returnTo": captureReturnTo,
                            "client": "mobile"
                        ]
                        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
                        EntityAuthDebugLog.log("[EntityAuthSSO] exchanging ticket at=", req.url?.absoluteString ?? "<nil>", "payload=", String(describing: payload))
                        
                        let (data, resp, err) = await withCheckedContinuation { dataCont in
                            URLSession.shared.dataTask(with: req) { data, resp, err in
                                dataCont.resume(returning: (data, resp, err))
                            }.resume()
                        }
                        
                        if let err {
                            EntityAuthDebugLog.log("[EntityAuthSSO] exchange failed transport error:", err.localizedDescription)
                            continuation.resume(throwing: err)
                            return
                        }
                        if let http = resp as? HTTPURLResponse {
                            let bodyText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no-body>"
                            EntityAuthDebugLog.log("[EntityAuthSSO] exchange response status=\(http.statusCode) body=", bodyText)
                        } else {
                            EntityAuthDebugLog.log("[EntityAuthSSO] exchange response invalid or missing HTTPURLResponse")
                        }
                        guard let data, let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                            continuation.resume(throwing: NSError(domain: "EntityAuthSSO", code: 4, userInfo: [NSLocalizedDescriptionKey: "Ticket exchange failed"]))
                            return
                        }
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let access = json?["accessToken"] as? String,
                               let refresh = json?["refreshToken"] as? String,
                               let sid = json?["sessionId"] as? String,
                               let uid = json?["userId"] as? String {
                                EntityAuthDebugLog.log("[EntityAuthSSO] exchange success userId=\(uid) sessionId=\(sid) access.len=\(access.count) refresh.len=\(refresh.count)")
                                continuation.resume(returning: (access, refresh, sid, uid))
                            } else {
                                EntityAuthDebugLog.log("[EntityAuthSSO] exchange payload missing expected fields")
                                continuation.resume(throwing: NSError(domain: "EntityAuthSSO", code: 5))
                            }
                        } catch {
                            EntityAuthDebugLog.log("[EntityAuthSSO] exchange json decode error:", error.localizedDescription)
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
                let started = session.start()
                EntityAuthDebugLog.log("[EntityAuthSSO] ASWebAuthenticationSession started=", String(started))
            }
        }
    }

    public func handleCallback(url: URL) async throws -> (accessToken: String, refreshToken: String, sessionId: String, userId: String) {
        return try await EntityAuthSSO.handleCallbackStatic(baseURL: baseURL, url: url)
    }

    static func handleCallbackStatic(baseURL: URL, url: URL) async throws -> (accessToken: String, refreshToken: String, sessionId: String, userId: String) {
        EntityAuthDebugLog.log("[EntityAuthSSO] handleCallbackStatic url=", url.absoluteString)
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let ticket = comps?.queryItems?.first { $0.name == "ticket" }?.value
        EntityAuthDebugLog.log("[EntityAuthSSO] parsed ticket=", ticket ?? "<nil>")
        guard let ticket else { throw NSError(domain: "EntityAuthSSO", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing ticket"]) }
        let endpoint = baseURL.appendingPathComponent("api/auth/exchange-ticket")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["ticket": ticket])
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no-body>"
            EntityAuthDebugLog.log("[EntityAuthSSO] static exchange response status=\(http.statusCode) body=", bodyText)
        }
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "EntityAuthSSO", code: 4, userInfo: [NSLocalizedDescriptionKey: "Ticket exchange failed (static)"])
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard
            let access = json?["accessToken"] as? String,
            let refresh = json?["refreshToken"] as? String,
            let sid = json?["sessionId"] as? String,
            let uid = json?["userId"] as? String
        else {
            EntityAuthDebugLog.log("[EntityAuthSSO] static exchange payload missing expected fields")
            throw NSError(domain: "EntityAuthSSO", code: 5)
        }
        return (access, refresh, sid, uid)
    }
}


