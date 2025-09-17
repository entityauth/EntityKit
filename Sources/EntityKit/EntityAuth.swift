import Foundation
import Security
import SwiftUI
import Combine
import AuthenticationServices
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Keychain helpers
private func keychainSet(_ key: String, _ value: String) {
    let data = value.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
    ]
    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
}

private func keychainGet(_ key: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: kCFBooleanTrue as Any,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}

// MARK: - Shared EntityAuth client
@MainActor
public final class EntityAuth: NSObject, ObservableObject {
    public static let shared = EntityAuth()

    private let baseURLDefaultsKey = "EA_BASE_URL"
    public var persistedBaseURL: String { UserDefaults.standard.string(forKey: baseURLDefaultsKey) ?? "https://entity-auth.com" }
    @Published public var baseURL: URL

    @Published public private(set) var accessToken: String?
    @Published public private(set) var sessionId: String?
    @Published public private(set) var userId: String?
    @Published public private(set) var logs: [String] = []
    @Published public private(set) var isPasskeyBusy: Bool = false
    @Published public private(set) var passkeyStatus: (rpId: String, count: Int)?
    @Published public private(set) var cachedTenantId: String?

    public var onLogout: (() -> Void)?

    private var watcherTask: Task<Void, Never>?
    private var lastTenantFetchAt: Date?
    private var tenantFetchInFlight = false
    private var activeAuthController: ASAuthorizationController?
    private var pendingRegistration: CheckedContinuation<ASAuthorizationPublicKeyCredentialRegistration, Error>?
    private var pendingAssertion: CheckedContinuation<ASAuthorizationPublicKeyCredentialAssertion, Error>?

    private override init() {
        let initial = UserDefaults.standard.string(forKey: baseURLDefaultsKey) ?? "https://entity-auth.com"
        self.baseURL = URL(string: initial) ?? URL(string: "https://entity-auth.com")!
        super.init()
    }

    public func updateBaseURL(_ urlString: String) {
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else { return }
        self.baseURL = url
        UserDefaults.standard.set(urlString, forKey: baseURLDefaultsKey)
    }

    // MARK: Logging
    func log(_ s: String) {
        let line = "[\(Date())] \(s)"
        logs.insert(line, at: 0)
        if logs.count > 200 { _ = logs.popLast() }
        print(line)
    }
    
    func clearLogs() {
        logs.removeAll()
    }

    // MARK: Public API
    public func register(email: String, password: String, tenantId: String) async throws {
        log("register start: tenant=\(tenantId) email=\(email)")
        let body: [String: Any] = ["email": email, "password": password, "tenantId": tenantId]
        _ = try await post(path: "/api/auth/register", headers: ["x-client": "native"], json: body, authorized: false)
        log("register ok")
    }

    public func login(email: String, password: String, tenantId: String) async throws {
        log("login start: tenant=\(tenantId) email=\(email)")
        let body: [String: Any] = ["email": email, "password": password, "tenantId": tenantId]
        var headers: [String: String] = ["x-client": "native"]
        if let did = ensureDeviceId() { headers["x-device-id"] = did }
        headers["x-device-platform"] = platformHeader()
        let data = try await post(path: "/api/auth/login", headers: headers, json: body, authorized: false)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard
            let access = json?["accessToken"] as? String,
            let refresh = json?["refreshToken"] as? String,
            let sid = json?["sessionId"] as? String,
            let uid = json?["userId"] as? String
        else { throw NSError(domain: "EntityAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid login response"]) }

        keychainSet("ea_refresh", refresh)
        self.accessToken = access
        self.sessionId = sid
        self.userId = uid
        log("login ok: userId=\(uid) sessionId=\(sid)")
        // Upsert device entity
        if let did = keychainGet("ea_device_id") {
            _ = try? await post(path: "/api/device/upsert", headers: [:], json: [
                "uuid": did,
                "platform": platformHeader(),
                "name": deviceName(),
                "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            ], authorized: true)
        }
        startSessionWatcher()
    }

    public func refresh() async throws {
        log("refresh start")
        let url = baseURL.appendingPathComponent("/api/auth/refresh")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let refreshToken = keychainGet("ea_refresh") { req.addValue(refreshToken, forHTTPHeaderField: "x-refresh-token") }
        if let did = keychainGet("ea_device_id") { req.addValue(did, forHTTPHeaderField: "x-device-id") }
        req.addValue(platformHeader(), forHTTPHeaderField: "x-device-platform")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw NSError(domain: "EntityAuth", code: 500) }
        if http.statusCode == 401 { throw URLError(.userAuthenticationRequired) }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let access = json?["accessToken"] as? String else { throw NSError(domain: "EntityAuth", code: 4) }
        if let newRefresh = json?["refreshToken"] as? String {
            keychainSet("ea_refresh", newRefresh)
        }
        self.accessToken = access
        log("refresh ok")
    }

    public func logout() async {
        log("logout start")
        if let sid = self.sessionId {
            _ = try? await post(path: "/api/auth/logout", headers: [:], json: ["sessionId": sid], authorized: true)
        } else if let refresh = keychainGet("ea_refresh") {
            _ = try? await post(path: "/api/auth/logout", headers: ["x-refresh-token": refresh], json: [:], authorized: false)
        } else {
            _ = try? await post(path: "/api/auth/logout", headers: [:], json: [:], authorized: false)
        }
        self.accessToken = nil
        self.sessionId = nil
        self.userId = nil
        watcherTask?.cancel()
        watcherTask = nil
        log("logout ok")
    }

    // MARK: - Passkeys
    public func passkeyRegister(username: String) async throws {
        if isPasskeyBusy {
            log("passkey.register aborted: another passkey operation is in progress")
            return
        }
        isPasskeyBusy = true
        defer { isPasskeyBusy = false }
        guard let uid = self.userId else {
            throw NSError(domain: "EntityAuth", code: 700, userInfo: [NSLocalizedDescriptionKey: "Login required before creating a passkey"])
        }
        log("passkey.register options start: userId=\(uid) username=\(username)")
        let data = try await post(path: "/api/passkey/register/options", headers: ["x-client": "native"], json: ["userId": uid, "username": username], authorized: true)
        // Parse options (legacy internal API kept for backwards compat of this overload)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let options = json["options"] as? [String: Any],
              let challengeB64u = options["challenge"] as? String,
              let rp = options["rp"] as? [String: Any],
              let rpId = rp["id"] as? String,
              let user = options["user"] as? [String: Any],
              let userIdB64u = user["id"] as? String
        else { throw NSError(domain: "EntityAuth", code: 701, userInfo: [NSLocalizedDescriptionKey: "Invalid register options response"]) }

        guard let challenge = Data(base64URLEncoded: challengeB64u), let userIdBytes = Data(base64URLEncoded: userIdB64u) else {
            throw NSError(domain: "EntityAuth", code: 702, userInfo: [NSLocalizedDescriptionKey: "Invalid challenge or user id encoding"])
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialRegistrationRequest(challenge: challenge, name: username, userID: userIdBytes)
        request.userVerificationPreference = .preferred

        let registration: ASAuthorizationPublicKeyCredentialRegistration
        do {
            registration = try await performPasskeyRegistration(request: request)
        } catch let nsError as NSError {
            if nsError.domain == ASAuthorizationError.errorDomain {
                let code = ASAuthorizationError.Code(rawValue: nsError.code) ?? .unknown
                let reason: String
                switch code {
                case .canceled: reason = "canceled by user"
                case .notHandled: reason = "not handled"
                case .invalidResponse: reason = "invalid response"
                case .failed: reason = "authorization failed"
                case .unknown: reason = "unknown error"
                default: reason = "unknown error"
                }
                log("passkey.register error: \(reason) (code=\(nsError.code)) rpId=\(rpId)")
            } else {
                log("passkey.register error: \(nsError.localizedDescription)")
            }
            throw nsError
        }

        // Build RegistrationResponseJSON
        let credId = registration.credentialID.base64URLEncodedString()
        let clientData = registration.rawClientDataJSON.base64URLEncodedString()
        guard let rawAttestation = registration.rawAttestationObject else {
            throw NSError(domain: "EntityAuth", code: 703, userInfo: [NSLocalizedDescriptionKey: "Missing attestation object from registration"]) }
        let attestation = rawAttestation.base64URLEncodedString()

        let response: [String: Any] = [
            "id": credId,
            "rawId": credId,
            "type": "public-key",
            "response": [
                "attestationObject": attestation,
                "clientDataJSON": clientData,
            ],
            "clientExtensionResults": [:],
            "authenticatorAttachment": "platform",
        ]

        _ = try await post(path: "/api/passkey/register/verify", headers: ["x-client": "native"], json: ["userId": uid, "response": response], authorized: true)
        log("passkey.register verify ok")
    }

    // New email-based registration flow: auto-creates user if missing and auto-logs-in on verify
    public func passkeyRegister(email: String, tenantId: String = "t1") async throws {
        if isPasskeyBusy {
            log("passkey.register aborted: another passkey operation is in progress")
            return
        }
        isPasskeyBusy = true
        defer { isPasskeyBusy = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw NSError(domain: "EntityAuth", code: 704, userInfo: [NSLocalizedDescriptionKey: "Email is required for passkey registration"])
        }
        log("passkey.register options (email) start: email=\(trimmedEmail) tenant=\(tenantId)")
        let data = try await post(path: "/api/passkey/register/options", headers: ["x-client": "native"], json: ["tenantId": tenantId, "email": trimmedEmail], authorized: false)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let options = json["options"] as? [String: Any],
              let challengeB64u = options["challenge"] as? String,
              let rp = options["rp"] as? [String: Any],
              let rpId = rp["id"] as? String,
              let user = options["user"] as? [String: Any],
              let userIdB64u = user["id"] as? String,
              let uid = json["userId"] as? String
        else { throw NSError(domain: "EntityAuth", code: 705, userInfo: [NSLocalizedDescriptionKey: "Invalid register options response"]) }

        guard let challenge = Data(base64URLEncoded: challengeB64u), let userIdBytes = Data(base64URLEncoded: userIdB64u) else {
            throw NSError(domain: "EntityAuth", code: 706, userInfo: [NSLocalizedDescriptionKey: "Invalid challenge or user id encoding"])
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialRegistrationRequest(challenge: challenge, name: trimmedEmail, userID: userIdBytes)
        request.userVerificationPreference = .preferred

        let registration: ASAuthorizationPublicKeyCredentialRegistration
        do {
            registration = try await performPasskeyRegistration(request: request)
        } catch let nsError as NSError {
            if nsError.domain == ASAuthorizationError.errorDomain {
                let code = ASAuthorizationError.Code(rawValue: nsError.code) ?? .unknown
                let reason: String
                switch code {
                case .canceled: reason = "canceled by user"
                case .notHandled: reason = "not handled"
                case .invalidResponse: reason = "invalid response"
                case .failed: reason = "authorization failed"
                case .unknown: reason = "unknown error"
                default: reason = "unknown error"
                }
                log("passkey.register error: \(reason) (code=\(nsError.code)) rpId=\(rpId)")
            } else {
                log("passkey.register error: \(nsError.localizedDescription)")
            }
            throw nsError
        }

        let credId = registration.credentialID.base64URLEncodedString()
        let clientData = registration.rawClientDataJSON.base64URLEncodedString()
        guard let rawAttestation = registration.rawAttestationObject else {
            throw NSError(domain: "EntityAuth", code: 707, userInfo: [NSLocalizedDescriptionKey: "Missing attestation object from registration"]) }
        let attestation = rawAttestation.base64URLEncodedString()

        let response: [String: Any] = [
            "id": credId,
            "rawId": credId,
            "type": "public-key",
            "response": [
                "attestationObject": attestation,
                "clientDataJSON": clientData,
            ],
            "clientExtensionResults": [:],
            "authenticatorAttachment": "platform",
        ]

        var headers: [String: String] = ["x-client": "native"]
        if let did = ensureDeviceId() { headers["x-device-id"] = did }
        headers["x-device-platform"] = platformHeader()
        let verifyData = try await post(path: "/api/passkey/register/verify", headers: headers, json: ["userId": uid, "response": response], authorized: false)
        let verified = try JSONSerialization.jsonObject(with: verifyData) as? [String: Any]
        guard let access = verified?["accessToken"] as? String,
              let refresh = verified?["refreshToken"] as? String,
              let sid = verified?["sessionId"] as? String,
              let userId = verified?["userId"] as? String else {
            throw NSError(domain: "EntityAuth", code: 708, userInfo: [NSLocalizedDescriptionKey: "Invalid register verify response"])
        }

        keychainSet("ea_refresh", refresh)
        self.accessToken = access
        self.sessionId = sid
        self.userId = userId
        log("passkey.register ok: userId=\(userId) sessionId=\(sid)")
        if let did = keychainGet("ea_device_id") {
            _ = try? await post(path: "/api/device/upsert", headers: [:], json: [
                "uuid": did,
                "platform": platformHeader(),
                "name": deviceName(),
                "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            ], authorized: true)
        }
        startSessionWatcher()
    }

    public func passkeyLogin(email: String, tenantId: String) async throws {
        if isPasskeyBusy {
            log("passkey.login aborted: another passkey operation is in progress")
            return
        }
        isPasskeyBusy = true
        defer { isPasskeyBusy = false }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            log("passkey.login aborted: Email required. Enter an email first.")
            throw NSError(domain: "EntityAuth", code: 709, userInfo: [NSLocalizedDescriptionKey: "Email is required for passkey sign-in"])
        }
        log("passkey.login options start: email=\(trimmedEmail) tenant=\(tenantId)")
        let data = try await post(path: "/api/passkey/login/options", headers: ["x-client": "native"], json: ["tenantId": tenantId, "email": trimmedEmail], authorized: false)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let options = json["options"] as? [String: Any],
              let challengeB64u = options["challenge"] as? String
        else { throw NSError(domain: "EntityAuth", code: 711, userInfo: [NSLocalizedDescriptionKey: "Invalid login options response"]) }

        let serverRpId = json["rpId"] as? String
        let rpId = (options["rpId"] as? String) ?? serverRpId ?? (URL(string: persistedBaseURL)?.host ?? "")
        guard let challenge = Data(base64URLEncoded: challengeB64u), !rpId.isEmpty else {
            throw NSError(domain: "EntityAuth", code: 712, userInfo: [NSLocalizedDescriptionKey: "Invalid rpId or challenge"])
        }
        log("passkey.login using rpId=\(rpId)")

        guard let uid = json["userId"] as? String else {
            throw NSError(domain: "EntityAuth", code: 714, userInfo: [NSLocalizedDescriptionKey: "Missing userId in options response"])
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        request.userVerificationPreference = .preferred

        let assertion: ASAuthorizationPublicKeyCredentialAssertion
        do {
            assertion = try await performPasskeyAssertion(request: request)
        } catch let nsError as NSError {
            if nsError.domain == ASAuthorizationError.errorDomain {
                let code = ASAuthorizationError.Code(rawValue: nsError.code) ?? .unknown
                let reason: String
                switch code {
                case .canceled:
                    reason = "canceled by user"
                case .notHandled:
                    reason = "not handled / no matching passkey for rpId"
                case .invalidResponse:
                    reason = "invalid response"
                case .failed:
                    reason = "authorization failed (likely no matching passkey)"
                case .unknown:
                    reason = "unknown error"
                default:
                    reason = "unknown error"
                }
                log("passkey.login assertion error: \(reason) (code=\(nsError.code)) rpId=\(rpId)")
            } else {
                log("passkey.login assertion error: \(nsError.localizedDescription)")
            }
            throw nsError
        }

        let credId = assertion.credentialID.base64URLEncodedString()
        let clientData = assertion.rawClientDataJSON.base64URLEncodedString()
        let authData = assertion.rawAuthenticatorData.base64URLEncodedString()
        let signature = assertion.signature.base64URLEncodedString()
        let userHandle = assertion.userID.isEmpty ? nil : assertion.userID.base64URLEncodedString()

        var response: [String: Any] = [
            "id": credId,
            "rawId": credId,
            "type": "public-key",
            "response": [
                "authenticatorData": authData,
                "clientDataJSON": clientData,
                "signature": signature,
            ],
            "clientExtensionResults": [:],
            "authenticatorAttachment": "platform",
        ]
        if let userHandle { (response["response"] as? [String: Any]).map { _ in } ; var resp = response["response"] as! [String: Any]; resp["userHandle"] = userHandle; response["response"] = resp }

        var headers: [String: String] = ["x-client": "native"]
        if let did = ensureDeviceId() { headers["x-device-id"] = did }
        headers["x-device-platform"] = platformHeader()
        let verifyData = try await post(path: "/api/passkey/login/verify", headers: headers, json: ["userId": uid, "response": response], authorized: false)
        let verified = try JSONSerialization.jsonObject(with: verifyData) as? [String: Any]
        guard let access = verified?["accessToken"] as? String,
              let refresh = verified?["refreshToken"] as? String,
              let sid = verified?["sessionId"] as? String,
              let userId = verified?["userId"] as? String else {
            throw NSError(domain: "EntityAuth", code: 713, userInfo: [NSLocalizedDescriptionKey: "Invalid login verify response"])
        }

        keychainSet("ea_refresh", refresh)
        self.accessToken = access
        self.sessionId = sid
        self.userId = userId
        log("passkey.login ok: userId=\(userId) sessionId=\(sid)")
        // Upsert device entity
        if let did = keychainGet("ea_device_id") {
            _ = try? await post(path: "/api/device/upsert", headers: [:], json: [
                "uuid": did,
                "platform": platformHeader(),
                "name": deviceName(),
                "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            ], authorized: true)
        }
        startSessionWatcher()
    }

    // MARK: - Username APIs
    public func setUsername(_ username: String) async throws {
        let body: [String: Any] = ["username": username]
        let data = try await post(path: "/api/user/username/set", headers: ["x-client": "native"], json: body, authorized: true)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let ok = json["ok"] as? Bool, ok {
            log("username.set ok: \(username)")
        } else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "Unknown error"
            throw NSError(domain: "EntityAuth", code: 801, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    public func fetchCurrentUser() async throws -> (id: String, username: String?) {
        log("fetchCurrentUser start: base=\(baseURL.absoluteString)")
        let data = try await get(path: "/api/user/me", authorized: true)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let id = json["id"] as? String else {
            throw NSError(domain: "EntityAuth", code: 802, userInfo: [NSLocalizedDescriptionKey: "Invalid /me response"])
        }
        let username = json["username"] as? String
        log("fetchCurrentUser ok: id=\(id) username=\(username ?? "nil")")
        return (id: id, username: username)
    }

    public func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let data = try await get(path: "/api/user/username/check?value=\(encoded)", authorized: true)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        let isValid = (json["valid"] as? Bool) ?? false
        let isAvailable = (json["available"] as? Bool) ?? false
        return isValid && isAvailable
    }

    // Derive current session (tenantId) from API
    public func fetchCurrentTenantId() async -> String? {
        // Throttle to avoid tight loops from view re-renders
        if let last = lastTenantFetchAt, Date().timeIntervalSince(last) < 5.0 {
            return cachedTenantId
        }
        if tenantFetchInFlight {
            return cachedTenantId
        }
        tenantFetchInFlight = true
        defer { tenantFetchInFlight = false; lastTenantFetchAt = Date() }
        do {
            let data = try await get(path: "/api/session/current", authorized: true)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sess = json["session"] as? [String: Any] {
                if let tid = sess["tid"] as? String { cachedTenantId = tid; return tid }
                if let tidNum = sess["tid"] as? NSNumber { let s = tidNum.stringValue; cachedTenantId = s; return s }
            }
            return cachedTenantId
        } catch {
            return cachedTenantId
        }
    }

    private func performPasskeyRegistration(request: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest) async throws -> ASAuthorizationPublicKeyCredentialRegistration {
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ASAuthorizationPublicKeyCredentialRegistration, Error>) in
            self.pendingRegistration = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.activeAuthController = controller
            #if os(macOS)
            NSApp.activate(ignoringOtherApps: true)
            #endif
            controller.performRequests()
        }
    }

    private func performPasskeyAssertion(request: ASAuthorizationPlatformPublicKeyCredentialAssertionRequest) async throws -> ASAuthorizationPublicKeyCredentialAssertion {
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ASAuthorizationPublicKeyCredentialAssertion, Error>) in
            self.pendingAssertion = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.activeAuthController = controller
            #if os(macOS)
            NSApp.activate(ignoringOtherApps: true)
            #endif
            controller.performRequests()
        }
    }

    // MARK: - Internal
    private func startSessionWatcher() {
        watcherTask?.cancel()
        guard let sid = sessionId else { return }
        watcherTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let body = try JSONSerialization.data(withJSONObject: ["sessionId": sid])
                    var headers = authHeader()
                    if let did = keychainGet("ea_device_id") { headers["x-device-id"] = did }
                    headers["x-device-platform"] = platformHeader()
                    let data = try await request(method: "POST", path: "/api/session/by-id", headers: headers, body: body)
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let session = json?["session"] as? [String: Any] {
                        if let status = session["status"] as? String, status != "active" {
                            self.log("watcher: remote logout detected (status=\(status))")
                            await self.handleRemoteLogout()
                            return
                        }
                    } else {
                        self.log("watcher: session missing -> remote logout")
                        await self.handleRemoteLogout()
                        return
                    }
                } catch {
                    self.log("watcher: transient error: \(error.localizedDescription)")
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func handleRemoteLogout() async {
        await logout()
        onLogout?()
    }

    private func authHeader() -> [String: String] {
        guard let token = accessToken else { return ["content-type": "application/json"] }
        return ["authorization": "Bearer \(token)", "content-type": "application/json"]
    }

    private func get(path: String, authorized: Bool) async throws -> Data {
        return try await request(method: "GET", path: path, headers: authorized ? authHeader() : ["content-type": "application/json"], body: nil)
    }

    private func post(path: String, headers: [String: String], json: [String: Any], authorized: Bool = true) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: json)
        return try await request(method: "POST", path: path, headers: (authorized ? authHeader() : ["content-type": "application/json"]).merging(headers, uniquingKeysWith: { a, _ in a }), body: body)
    }

    private func request(method: String, path: String, headers: [String: String], body: Data?, allowRetry: Bool = true) async throws -> Data {
        // Build URL safely: avoid encoding '?' when path contains query
        let url: URL = {
            if path.contains("?") {
                return URL(string: baseURL.absoluteString + path) ?? baseURL.appendingPathComponent(path)
            } else {
                return baseURL.appendingPathComponent(path)
            }
        }()
        var req = URLRequest(url: url)
        req.httpMethod = method
        headers.forEach { req.addValue($1, forHTTPHeaderField: $0) }
        req.httpBody = body
        let hasAuth = headers.keys.map { $0.lowercased() }.contains("authorization")
        log("http -> \(method) \(url.absoluteString) auth=\(hasAuth)")
        let start = Date()
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw NSError(domain: "EntityAuth", code: 500) }
        log("request \(method) \(path) -> \(http.statusCode) in \(Int(Date().timeIntervalSince(start)*1000))ms")
        if http.statusCode == 401 {
            // Attempt one refresh + retry
            if allowRetry && !path.hasPrefix("/api/auth/refresh") {
                do {
                    try await refresh()
                    var merged = headers
                    // Ensure updated Authorization header is present on retry
                    authHeader().forEach { merged[$0.key] = $0.value }
                    return try await request(method: method, path: path, headers: merged, body: body, allowRetry: false)
                } catch {
                    throw URLError(.userAuthenticationRequired)
                }
            }
            throw URLError(.userAuthenticationRequired)
        }
        if !(200...299).contains(http.statusCode) {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            if !bodyText.isEmpty { log("error body: \(bodyText)") }
            throw NSError(domain: "EntityAuth", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: bodyText.isEmpty ? "HTTP \(http.statusCode)" : bodyText])
        }
        return data
    }

    // MARK: Utilities
    public func currentDeviceId() -> String? {
        return keychainGet("ea_device_id")
    }

    @discardableResult
    public func upsertDevice(name: String?) async -> Bool {
        do {
            let did = ensureDeviceId() ?? currentDeviceId() ?? UUID().uuidString.lowercased()
            let body: [String: Any] = [
                "uuid": did,
                "platform": platformHeader(),
                "name": (name?.isEmpty == false ? name! : deviceName()),
                "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            ]
            _ = try await post(path: "/api/device/upsert", headers: [:], json: body, authorized: true)
            log("device upsert ok")
            return true
        } catch {
            log("device upsert error: \(error.localizedDescription)")
            return false
        }
    }

    public func fetchPasskeyStatus() async {
        guard let uid = self.userId else {
            self.passkeyStatus = nil
            return
        }
        do {
            let data = try await post(path: "/api/passkey/exists", headers: ["x-client": "native"], json: ["userId": uid], authorized: true)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rp = json["rpId"] as? String,
               let count = json["count"] as? Int {
                self.passkeyStatus = (rpId: rp, count: count)
            }
        } catch {
            self.passkeyStatus = nil
        }
    }
    public func testConnection() async {
        do {
            _ = try await request(method: "GET", path: "/", headers: ["accept": "text/html"], body: nil)
            log("connectivity: OK -> \(baseURL.absoluteString)")
        } catch {
            log("connectivity: FAIL -> \(baseURL.absoluteString) error=\(error.localizedDescription)")
        }
    }
}

// MARK: - Device helpers
extension EntityAuth {
    private func platformHeader() -> String {
        #if os(iOS)
        return "ios"
        #elseif os(macOS)
        return "macos"
        #else
        return "unknown"
        #endif
    }

    private func ensureDeviceId() -> String? {
        if let existing = keychainGet("ea_device_id"), !existing.isEmpty { return existing }
        let newId = UUID().uuidString.lowercased()
        keychainSet("ea_device_id", newId)
        return newId
    }

    private func deviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Unknown"
        #endif
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension EntityAuth: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let reg = authorization.credential as? ASAuthorizationPublicKeyCredentialRegistration {
            pendingRegistration?.resume(returning: reg)
            pendingRegistration = nil
        } else if let assertion = authorization.credential as? ASAuthorizationPublicKeyCredentialAssertion {
            pendingAssertion?.resume(returning: assertion)
            pendingAssertion = nil
        } else {
            let err = NSError(domain: "EntityAuth", code: 720, userInfo: [NSLocalizedDescriptionKey: "Unknown credential type"])
            pendingRegistration?.resume(throwing: err)
            pendingAssertion?.resume(throwing: err)
            pendingRegistration = nil
            pendingAssertion = nil
        }
        activeAuthController = nil
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        pendingRegistration?.resume(throwing: error)
        pendingAssertion?.resume(throwing: error)
        pendingRegistration = nil
        pendingAssertion = nil
        activeAuthController = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension EntityAuth: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            if let win = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                return win
            }
            // Fallback: create a temporary window attached to the scene to satisfy API
            return UIWindow(windowScene: scene)
        }
        // Last resort: return the first app window if any
        if let anyWindow = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }).first {
            return anyWindow
        }
        // Should not happen in normal app lifecycle; crash to avoid deprecated empty init
        preconditionFailure("No presentation anchor available")
        #elseif os(macOS)
        if let anchor = NSApplication.shared.keyWindow
            ?? NSApplication.shared.mainWindow
            ?? NSApplication.shared.windows.first(where: { $0.isVisible }) {
            return anchor
        }
        // Fallback to any existing window; avoid returning a detached window
        return NSApplication.shared.windows.first ?? NSWindow()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

// MARK: - Base64URL helpers
private extension Data {
    init?(base64URLEncoded: String) {
        var s = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (s.count % 4)
        if padding < 4 { s += String(repeating: "=", count: padding) }
        self.init(base64Encoded: s)
    }

    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}


