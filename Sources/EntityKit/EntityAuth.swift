import Foundation
import Security
import SwiftUI
import Combine
import ConvexMobile
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
final class EntityAuth: NSObject, ObservableObject {
    static let shared = EntityAuth()

    private let baseURLDefaultsKey = "EA_BASE_URL"
    var persistedBaseURL: String { UserDefaults.standard.string(forKey: baseURLDefaultsKey) ?? "https://entity-auth.com" }
    @Published var baseURL: URL

    @Published private(set) var accessToken: String?
    @Published private(set) var sessionId: String?
    @Published private(set) var userId: String?
    @Published private(set) var liveUsername: String?
    @Published private(set) var logs: [String] = []
    @Published private(set) var isPasskeyBusy: Bool = false
    @Published private(set) var passkeyStatus: (rpId: String, count: Int)?
    @Published private(set) var cachedTenantId: String?
    @Published private(set) var liveSessions: [SessionDoc] = []

    var onLogout: (() -> Void)?

    private var sessionSubscription: AnyCancellable?
    private var userSubscription: AnyCancellable?
    private var sessionsSubscription: AnyCancellable?
    private var convexClient: ConvexClient?
    private var convexClientTag: String?
    private var clientCreationTask: Task<ConvexClient?, Never>?
    private var lastTenantFetchAt: Date?
    private var tenantFetchInFlight = false
    private var activeAuthController: ASAuthorizationController?
    private var pendingRegistration: CheckedContinuation<ASAuthorizationPublicKeyCredentialRegistration, Error>?
    private var pendingAssertion: CheckedContinuation<ASAuthorizationPublicKeyCredentialAssertion, Error>?

    struct SessionDoc: Decodable, Equatable {
        let _id: String?
        let status: String?
        let deviceId: String?
        struct Device: Decodable, Equatable { let userAgent: String?; let ip: String?; let platform: String? }
        let device: Device?
    }

    private override init() {
        let initial = UserDefaults.standard.string(forKey: baseURLDefaultsKey) ?? "https://entity-auth.com"
        self.baseURL = URL(string: initial) ?? URL(string: "https://entity-auth.com")!
        super.init()
    }

    func updateBaseURL(_ urlString: String) {
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else { return }
        self.baseURL = url
        UserDefaults.standard.set(urlString, forKey: baseURLDefaultsKey)
    }

    public func clearLogs() {
        logs.removeAll()
    }

    // MARK: Public API
    func register(email: String, password: String, tenantId: String) async throws {
        let body: [String: Any] = ["email": email, "password": password, "tenantId": tenantId]
        _ = try await post(path: "/api/auth/register", headers: ["x-client": "native"], json: body, authorized: false)
    }

    func login(email: String, password: String, tenantId: String) async throws {
        let body: [String: Any] = ["email": email, "password": password, "tenantId": tenantId]
        var headers: [String: String] = ["x-client": "native"]
        if let did = ensureDeviceId() { headers["x-device-uuid"] = did }
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
        print("[EA-DEBUG] login: access token set? \(self.accessToken != nil)")
        self.sessionId = sid
        self.userId = uid
        // Upsert device entity
        if let did = keychainGet("ea_device_id") {
            _ = try? await post(path: "/api/device/upsert", headers: [:], json: [
                "uuid": did,
                "platform": platformHeader(),
                "name": deviceName(),
                "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            ], authorized: true)
        }
        print("[EA-DEBUG] login: starting watchers with token? \(self.accessToken != nil)")
        startSessionWatcher()
        startUserWatcher()
        startSessionsWatcher()
        // Eagerly populate profile fields for immediate UI
        Task { await self.fetchCurrentUserProfile() }
    }

    func refresh() async throws {
        let url = baseURL.appendingPathComponent("/api/auth/refresh")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let refreshToken = keychainGet("ea_refresh") { req.addValue(refreshToken, forHTTPHeaderField: "x-refresh-token") }
        if let did = keychainGet("ea_device_id") { req.addValue(did, forHTTPHeaderField: "x-device-uuid") }
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
        print("[EA-DEBUG] refresh: new access token set")
    }

    func logout() async {
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
        self.liveUsername = nil
        self.liveSessions = []
        sessionSubscription?.cancel()
        sessionSubscription = nil
        userSubscription?.cancel()
        userSubscription = nil
        sessionsSubscription?.cancel()
        sessionsSubscription = nil
        // Clear Convex client on logout
        self.convexClient = nil
        #if os(macOS)
        stopMacOSFallbackPolling()
        #endif
    }

    // MARK: - Passkeys
    func passkeyRegister(username: String) async throws {
        if isPasskeyBusy {
            return
        }
        isPasskeyBusy = true
        defer { isPasskeyBusy = false }
        guard let uid = self.userId else {
            throw NSError(domain: "EntityAuth", code: 700, userInfo: [NSLocalizedDescriptionKey: "Login required before creating a passkey"])
        }
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
    }

    // New email-based registration flow: auto-creates user if missing and auto-logs-in on verify
    func passkeyRegister(email: String, tenantId: String = "t1") async throws {
        if isPasskeyBusy {
            return
        }
        isPasskeyBusy = true
        defer { isPasskeyBusy = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw NSError(domain: "EntityAuth", code: 704, userInfo: [NSLocalizedDescriptionKey: "Email is required for passkey registration"])
        }
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
        if let did = ensureDeviceId() { headers["x-device-uuid"] = did }
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
        if let did = keychainGet("ea_device_id") {
            _ = try? await post(path: "/api/device/upsert", headers: [:], json: [
                "uuid": did,
                "platform": platformHeader(),
                "name": deviceName(),
                "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            ], authorized: true)
        }
        startSessionWatcher()
        startUserWatcher()
        startSessionsWatcher()
        // Eagerly populate profile fields for immediate UI
        Task { await self.fetchCurrentUserProfile() }
    }

    func passkeyLogin(email: String, tenantId: String) async throws {
        if isPasskeyBusy {
            return
        }
        isPasskeyBusy = true
        defer { isPasskeyBusy = false }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw NSError(domain: "EntityAuth", code: 709, userInfo: [NSLocalizedDescriptionKey: "Email is required for passkey sign-in"])
        }
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
        if let did = ensureDeviceId() { headers["x-device-uuid"] = did }
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
        startUserWatcher()
        // Eagerly populate profile fields for immediate UI
        Task { await self.fetchCurrentUserProfile() }
    }

    // MARK: - Username APIs
    func setUsername(_ username: String) async throws {
        let body: [String: Any] = ["username": username]
        let data = try await post(path: "/api/user/username/set", headers: ["x-client": "native"], json: body, authorized: true)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let ok = json["ok"] as? Bool, ok {
            // Immediately reflect in UI; realtime subscription will confirm/update as needed
            self.liveUsername = username
        } else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "Unknown error"
            throw NSError(domain: "EntityAuth", code: 801, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    // fetchCurrentUser removed in favor of realtime Convex subscription

    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let data = try await get(path: "/api/user/username/check?value=\(encoded)", authorized: true)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        let isValid = (json["valid"] as? Bool) ?? false
        let isAvailable = (json["available"] as? Bool) ?? false
        return isValid && isAvailable
    }

    // Derive current session (tenantId) from API
    func fetchCurrentTenantId() async -> String? {
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
    private func fetchCurrentUserProfile() async {
        do {
            let data = try await get(path: "/api/user/me", authorized: true)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let username = json["username"] as? String
                await MainActor.run { self.liveUsername = username }
            }
        } catch {
            // Best-effort population; realtime watcher will eventually fill
        }
    }
    private func startSessionWatcher() {
        sessionSubscription?.cancel()
        guard let sid = sessionId else { return }
        guard self.accessToken != nil else {
            print("[EA-DEBUG] startSessionWatcher: aborted, token missing")
            return
        }
        Task { [weak self] in
            guard let self else { return }
            guard let client = await ensureConvexClient() else { return }
            struct SessionDoc: Decodable { let status: String? }
            let updates: AnyPublisher<SessionDoc?, ClientError> = client.subscribe(
                to: "auth/sessions.js:getById",
                with: [
                    "id": sid
                ],
                yielding: SessionDoc?.self
            )
            self.sessionSubscription = updates
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] value in
                    guard let self else { return }
                    let status = value?.status ?? "missing"
                    if status != "active" {
                        Task { await self.handleRemoteLogout() }
                    }
                })
        }
    }

    private func startUserWatcher() {
        userSubscription?.cancel()
        guard let uid = userId else {
            print("[EA-DEBUG] startUserWatcher: No userId")
            return
        }
        guard self.accessToken != nil else {
            print("[EA-DEBUG] startUserWatcher: aborted, token missing")
            return
        }
        print("[EA-DEBUG] startUserWatcher: Starting for uid=\(uid), tokenPresent=\(self.accessToken != nil)")
        Task { [weak self] in
            guard let self else {
                print("[EA-DEBUG] startUserWatcher: Self deallocated")
                return
            }
            guard let client = await ensureConvexClient() else {
                print("[EA-DEBUG] startUserWatcher: Failed to get Convex client, tokenPresent=\(self.accessToken != nil)")
                return
            }
            print("[EA-DEBUG] startUserWatcher: Got Convex client, setting up subscription, tokenPresent=\(self.accessToken != nil)")
            struct UserDoc: Decodable { struct Props: Decodable { let username: String? }; let properties: Props? }
            let updates: AnyPublisher<UserDoc?, ClientError> = client.subscribe(
                to: "auth/users.js:getById",
                with: [
                    "id": uid
                ],
                yielding: UserDoc?.self
            )
            self.userSubscription = updates
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        print("[EA-DEBUG] startUserWatcher: Subscription completed: \(completion)")
                    },
                    receiveValue: { [weak self] value in
                        let username = value?.properties?.username
                        print("[EA-DEBUG] startUserWatcher: Received update - username=\(username ?? "nil"), full value: \(String(describing: value))")
                        DispatchQueue.main.async {
                            self?.liveUsername = username
                            print("[EA-DEBUG] startUserWatcher: Updated liveUsername to: \(username ?? "nil")")
                        }
                    }
                )
            print("[EA-DEBUG] startUserWatcher: Subscription set up successfully")

            // Add a periodic check to see if we're getting initial data
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                print("[EA-DEBUG] startUserWatcher: 2s check - current liveUsername: \(self?.liveUsername ?? "nil")")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                print("[EA-DEBUG] startUserWatcher: 5s check - current liveUsername: \(self?.liveUsername ?? "nil")")
            }
        }
    }

    private func startSessionsWatcher() {
        sessionsSubscription?.cancel()
        guard let uid = userId else { return }
        guard self.accessToken != nil else {
            print("[EA-DEBUG] startSessionsWatcher: aborted, token missing")
            return
        }
        Task { [weak self] in
            guard let self else { return }
            guard let client = await ensureConvexClient() else { return }
            let updates: AnyPublisher<[SessionDoc], ClientError> = client.subscribe(
                to: "auth/sessions.js:getByUser",
                with: [
                    "userId": uid
                ],
                yielding: [SessionDoc].self
            )
            self.sessionsSubscription = updates
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] value in
                    self?.liveSessions = value
                })
        }
    }

    private func ensureConvexClient() async -> ConvexClient? {
        if let existing = convexClient {
            print("[EA-DEBUG] ensureConvexClient: Using existing client tag=\(convexClientTag ?? "nil"), tokenPresent=\(self.accessToken != nil)")
            return existing
        }
        if let task = clientCreationTask {
            print("[EA-DEBUG] ensureConvexClient: Awaiting in-flight creation task, tokenPresent=\(self.accessToken != nil)")
            return await task.value
        }
        let task = Task { [weak self] () -> ConvexClient? in
            guard let self else { return nil }
            print("[EA-DEBUG] ensureConvexClient: Creating new client, tokenPresent=\(self.accessToken != nil)")
            do {
                let data = try await self.get(path: "/api/convex", authorized: false)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let url = json["convexUrl"] as? String {
                    print("[EA-DEBUG] ensureConvexClient: Got convex URL: \(url)")
                    let client = ConvexClient(deploymentUrl: url)
                    await MainActor.run {
                        self.convexClient = client
                        self.convexClientTag = UUID().uuidString.prefix(8).description
                        print("[EA-DEBUG] ensureConvexClient: Client created successfully tag=\(self.convexClientTag ?? "nil")")
                    }
                    return client
                } else {
                    print("[EA-DEBUG] ensureConvexClient: Failed to parse convex URL from response")
                    return nil
                }
            } catch {
                print("[EA-DEBUG] ensureConvexClient: Error getting convex config: \(error)")
                return nil
            }
        }
        clientCreationTask = task
        let client = await task.value
        clientCreationTask = nil
        return client
    }

    #if os(macOS)
    private var macOSPollingTimer: Timer?

    private func startMacOSFallbackPolling() { }

    private func stopMacOSFallbackPolling() { macOSPollingTimer?.invalidate(); macOSPollingTimer = nil }

    private func pollUsernameUpdate() async { }
    #endif

    // Helper to encode Convex Id argument shape {"$id": "..."}
    struct ConvexIdArg: ConvexEncodable {
        let id: String
        init(_ id: String) { self.id = id }
        func convexEncode() throws -> String {
            return "{\"$id\":\"\(id)\"}"
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
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw NSError(domain: "EntityAuth", code: 500) }
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
            throw NSError(domain: "EntityAuth", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: bodyText.isEmpty ? "HTTP \(http.statusCode)" : bodyText])
        }
        return data
    }

    // MARK: Utilities
    func currentDeviceId() -> String? {
        return keychainGet("ea_device_id")
    }

    @discardableResult
    func upsertDevice(name: String?) async -> Bool {
        do {
            let did = ensureDeviceId() ?? currentDeviceId() ?? UUID().uuidString.lowercased()
            let body: [String: Any] = [
                "uuid": did,
                "platform": platformHeader(),
                "name": (name?.isEmpty == false ? name! : deviceName()),
                "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            ]
            _ = try await post(path: "/api/device/upsert", headers: [:], json: body, authorized: true)
            return true
        } catch {
            return false
        }
    }

    func fetchPasskeyStatus() async {
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
    func testConnection() async {
        do {
            _ = try await request(method: "GET", path: "/", headers: ["accept": "text/html"], body: nil)
        } catch {
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
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
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

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        pendingRegistration?.resume(throwing: error)
        pendingAssertion?.resume(throwing: error)
        pendingRegistration = nil
        pendingAssertion = nil
        activeAuthController = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension EntityAuth: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
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


