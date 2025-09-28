import Foundation
import Security
import SwiftUI
import Combine
import ConvexMobile
 
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

private func keychainDelete(_ key: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
}

// MARK: - Shared EntityAuth client
@MainActor
public final class EntityAuth: NSObject, ObservableObject {
    public static let shared = EntityAuth()

    private let baseURLDefaultsKey = "EA_BASE_URL"
    public var persistedBaseURL: String { UserDefaults.standard.string(forKey: baseURLDefaultsKey) ?? "https://entity-auth.com" }
    @Published public var baseURL: URL

    @Published public private(set) var accessToken: String?
    { didSet { notifyTokenListeners(accessToken) } }
    @Published public private(set) var sessionId: String?
    @Published public private(set) var userId: String?
    @Published public private(set) var liveUsername: String?
    @Published public private(set) var liveOrganizations: [LiveOrganization]? = nil
    public var liveOrganizationsPublisher: AnyPublisher<[LiveOrganization]?, Never> { $liveOrganizations.eraseToAnyPublisher() }
    @Published public private(set) var logs: [String] = []
    
    @Published private(set) var cachedTenantId: String?
    

    var onLogout: (() -> Void)?

    private var sessionSubscription: AnyCancellable?
    private var userSubscription: AnyCancellable?
    private var orgsSubscription: AnyCancellable?
    
    private var convexClient: ConvexClient?
    private var convexClientTag: String?
    private var clientCreationTask: Task<ConvexClient?, Never>?
    private var lastTenantFetchAt: Date?
    private var tenantFetchInFlight = false
    

    

    private override init() {
        let initial = UserDefaults.standard.string(forKey: baseURLDefaultsKey) ?? "https://entity-auth.com"
        self.baseURL = URL(string: initial) ?? URL(string: "https://entity-auth.com")!
        super.init()
    }

    // MARK: Token change callbacks (web parity)
    private var tokenListeners: [UUID: (String?) -> Void] = [:]

    private func notifyTokenListeners(_ token: String?) {
        for listener in tokenListeners.values { listener(token) }
    }

    /// Register a token change listener. Dispose the returned cancellable to unsubscribe.
    @discardableResult
    public func onTokenChange(_ listener: @escaping (String?) -> Void) -> AnyCancellable {
        let id = UUID()
        tokenListeners[id] = listener
        return AnyCancellable { [weak self] in self?.tokenListeners.removeValue(forKey: id) }
    }

    /// Apply a new access token from an external auth flow (web parity)
    public func applyAccessToken(_ token: String) {
        self.accessToken = token
    }

    public func updateBaseURL(_ urlString: String) {
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else { return }
        self.baseURL = url
        UserDefaults.standard.set(urlString, forKey: baseURLDefaultsKey)
    }

    public func clearLogs() {
        logs.removeAll()
    }

    public func addLog(_ message: String) {
        logs.append(message)
    }

    // MARK: Public API
    public func register(email: String, password: String, workspaceTenantId: String) async throws {
        let body: [String: Any] = ["email": email, "password": password, "workspaceTenantId": workspaceTenantId]
        _ = try await post(path: "/api/auth/register", headers: ["x-client": "native"], json: body, authorized: false)
    }

    public func login(email: String, password: String, workspaceTenantId: String) async throws {
        let body: [String: Any] = ["email": email, "password": password, "workspaceTenantId": workspaceTenantId]
        let headers: [String: String] = ["x-client": "native"]
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
        startUserWatcher()
        startOrganizationsWatcher()
        startSessionWatcher()
        // Eagerly populate profile fields for immediate UI
        Task { await self.fetchCurrentUserProfile() }
    }

    public func refresh() async throws {
        let url = baseURL.appendingPathComponent("/api/auth/refresh")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let refreshToken = keychainGet("ea_refresh") { req.addValue(refreshToken, forHTTPHeaderField: "x-refresh-token") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw NSError(domain: "EntityAuth", code: 500) }
        if http.statusCode == 401 { throw URLError(.userAuthenticationRequired) }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let access = json?["accessToken"] as? String else { throw NSError(domain: "EntityAuth", code: 4) }
        if let newRefresh = json?["refreshToken"] as? String {
            keychainSet("ea_refresh", newRefresh)
        }
        self.accessToken = access
    }

    public func logout() async {
        if let sid = self.sessionId {
            _ = try? await post(path: "/api/auth/logout", headers: [:], json: ["sessionId": sid], authorized: true)
        } else if let refresh = keychainGet("ea_refresh") {
            _ = try? await post(path: "/api/auth/logout", headers: ["x-refresh-token": refresh], json: [:], authorized: false)
        } else {
            _ = try? await post(path: "/api/auth/logout", headers: [:], json: [:], authorized: false)
        }
        // Explicitly remove locally stored refresh token
        keychainDelete("ea_refresh")
        self.accessToken = nil
        self.sessionId = nil
        self.userId = nil
        self.liveUsername = nil
        
        sessionSubscription?.cancel()
        sessionSubscription = nil
        userSubscription?.cancel()
        userSubscription = nil
        orgsSubscription?.cancel()
        orgsSubscription = nil
        
        // Clear Convex client on logout
        self.convexClient = nil
        #if os(macOS)
        stopMacOSFallbackPolling()
        #endif
    }

    // MARK: - Organizations
    public struct LiveOrganization: Identifiable, Hashable, Codable {
        public let id: String
        public let name: String
        public let slug: String
        public let role: String
        public let memberCount: Int?
        public let joinedAtMs: Double
        public let createdAtMs: Double
    }
    public func createOrg(workspaceTenantId: String, name: String, slug: String, ownerId: String) async throws {
        let body: [String: Any] = [
            "workspaceTenantId": workspaceTenantId,
            "name": name,
            "slug": slug,
            "ownerId": ownerId,
        ]
        _ = try await post(path: "/api/org/create", headers: [:], json: body, authorized: true)
    }

    public func addMember(orgId: String, userId: String, role: String) async throws {
        let body: [String: Any] = [
            "orgId": orgId,
            "userId": userId,
            "role": role,
        ]
        _ = try await post(path: "/api/org/add-member", headers: [:], json: body, authorized: true)
    }

    public func switchOrg(orgId: String) async throws {
        let body: [String: Any] = ["orgId": orgId]
        _ = try await post(path: "/api/org/switch", headers: [:], json: body, authorized: true)
        // After switching org, refresh to obtain a new access token with updated tenant (tid)
        // and clear cached tenant so subsequent reads reflect the new org immediately
        self.cachedTenantId = nil
        try await refresh()
    }

    public func getUserOrganizations() async throws -> [String: Any] {
        let data = try await get(path: "/api/org/list", authorized: true)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }


    // MARK: - Username APIs
    public func setUsername(_ username: String) async throws {
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

    public func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let result = try await checkUsername(username)
        return result.valid && result.available
    }

    /// Returns both validity and availability flags for a username (web parity)
    public func checkUsername(_ value: String) async throws -> (valid: Bool, available: Bool) {
        let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        let data = try await get(path: "/api/user/username/check?value=\(encoded)", authorized: true)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let valid = (json["valid"] as? Bool) ?? false
        let available = (json["available"] as? Bool) ?? false
        return (valid, available)
    }

    // MARK: - Users
    public func getUserMe() async throws -> [String: Any]? {
        let data = try await get(path: "/api/user/me", authorized: true)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    public func userByUsername(_ username: String) async throws -> [String: Any]? {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let data = try await get(path: "/api/user/by-username?username=\(encoded)", authorized: true)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    public func userByEmail(_ email: String) async throws -> [String: Any]? {
        let body: [String: Any] = ["email": email]
        let data = try await post(path: "/api/user/by-email", headers: [:], json: body, authorized: true)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // MARK: - Sessions
    public func getCurrentSession() async throws -> [String: Any]? {
        let data = try await get(path: "/api/session/current", authorized: true)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    public func listSessions(includeRevoked: Bool = false) async throws -> [[String: Any]] {
        let path = includeRevoked ? "/api/session/list?includeRevoked=true" : "/api/session/list"
        let data = try await get(path: path, authorized: true)
        return (try JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    public func getSessionById(_ id: String) async throws -> [String: Any]? {
        let data = try await get(path: "/api/session/by-id?id=\(id)", authorized: true)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    public func revokeSession(_ sessionId: String) async throws -> [String: Any] {
        let body: [String: Any] = ["sessionId": sessionId]
        let data = try await post(path: "/api/session/revoke", headers: [:], json: body, authorized: true)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    public func revokeSessionsByUser(_ userId: String) async throws -> [String: Any] {
        let body: [String: Any] = ["userId": userId]
        let data = try await post(path: "/api/session/revoke-by-user", headers: [:], json: body, authorized: true)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // Derive current session (workspaceTenantId) from API
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

        // Skip JWT decode to match web behavior - use API call for reliable tenant ID
        if false, let token = accessToken, let tid = Self.decodeTenantId(fromJWT: token) {
            cachedTenantId = tid
            return tid
        }

        // Fallback to server-side session: mirrors web SDK behavior
        do {
            if let me = try await getUserMe(), let tid = me["workspaceTenantId"] as? String, !tid.isEmpty {
                cachedTenantId = tid
                return tid
            }
        } catch {
            // best-effort; ignore errors here
        }
        return cachedTenantId
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
            return
        }
        guard self.accessToken != nil else {
            return
        }
        Task { [weak self] in
            guard let self else {
                return
            }
            guard let client = await ensureConvexClient() else {
                return
            }
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
                    },
                    receiveValue: { [weak self] value in
                        let username = value?.properties?.username
                        DispatchQueue.main.async {
                            self?.liveUsername = username
                        }
                    }
                )

            // Add a periodic check to see if we're getting initial data

        }
    }

    private func startOrganizationsWatcher() {
        orgsSubscription?.cancel()
        guard let uid = userId else {
            return
        }
        guard self.accessToken != nil else {
            return
        }
        Task { [weak self] in
            guard let self else {
                return
            }
            guard let client = await ensureConvexClient() else {
                return
            }
            struct OrgItem: Decodable {
                struct OrgDoc: Decodable { struct Props: Decodable { let name: String?; let slug: String?; let memberCount: Int? }; let _id: String?; let properties: Props?; let createdAt: Double? }
                let organization: OrgDoc?
                let role: String?
                let joinedAt: Double?
            }
            let updates: AnyPublisher<[OrgItem]?, ClientError> = client.subscribe(
                to: "memberships.js:getOrganizationsForUser",
                with: [
                    "userId": uid
                ],
                yielding: [OrgItem]?.self
            )
            self.orgsSubscription = updates
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                    },
                    receiveValue: { [weak self] value in
                        guard let self else { return }
                        let mapped: [LiveOrganization] = (value ?? []).compactMap { item in
                            guard let doc = item.organization, let id = doc._id else { return nil }
                            let name = doc.properties?.name ?? ""
                            let slug = doc.properties?.slug ?? ""
                            let role = item.role ?? "member"
                            let memberCount = doc.properties?.memberCount
                            let joinedAtMs = item.joinedAt ?? 0
                            let createdAtMs = doc.createdAt ?? 0
                            return LiveOrganization(id: id, name: name, slug: slug, role: role, memberCount: memberCount, joinedAtMs: joinedAtMs, createdAtMs: createdAtMs)
                        }
                        self.liveOrganizations = mapped
                        let ids = mapped.map { $0.id }.joined(separator: ",")
                        let slugs = mapped.map { $0.slug }.joined(separator: ",")
                        let names = mapped.map { $0.name }.joined(separator: ",")

                        // Debug: check if any org matches current tenant
                        if let tid = self.cachedTenantId {
                            let matchingOrgs = mapped.filter { $0.id == tid }
                        } else {
                        }
                    }
                )
        }
    }

    

    private func ensureConvexClient() async -> ConvexClient? {
        if let existing = convexClient {
            return existing
        }
        if let task = clientCreationTask {
            return await task.value
        }
        let task = Task { [weak self] () -> ConvexClient? in
            guard let self else { return nil }
            do {
                let data = try await self.get(path: "/api/convex", authorized: false)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let url = json["convexUrl"] as? String {
                    let client = ConvexClient(deploymentUrl: url)
                    await MainActor.run {
                        self.convexClient = client
                        self.convexClientTag = UUID().uuidString.prefix(8).description
                    }
                    return client
                } else {
                    return nil
                }
            } catch {
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
    

    
    public func testConnection() async {
        do {
            _ = try await request(method: "GET", path: "/", headers: ["accept": "text/html"], body: nil)
        } catch {
        }
    }

    // MARK: - GraphQL & OpenAPI helpers
    public func openAPI() async throws -> [String: Any] {
        let data = try await get(path: "/api/openapi", authorized: false)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    public func graphql<T: Decodable>(query: String, variables: [String: Any]? = nil) async throws -> T {
        let body: [String: Any] = [
            "query": query,
            "variables": variables ?? [:]
        ]
        let data = try await post(path: "/api/graphql", headers: [:], json: body, authorized: true)
        struct GraphQLResponse<U: Decodable>: Decodable { let data: U? }
        let decoded = try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)
        if let d = decoded.data { return d }
        throw NSError(domain: "EntityAuth", code: 902, userInfo: [NSLocalizedDescriptionKey: "GraphQL error"])
    }

    // Expose Convex config (web parity)
    public func getConvexConfig() async throws -> [String: Any] {
        let data = try await get(path: "/api/convex", authorized: false)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Public auth-aware request helper with automatic refresh on 401 (web-like fetch)
    public func fetch(_ path: String, method: String = "GET", headers: [String: String] = [:], body: Data? = nil, authorized: Bool = true) async throws -> Data {
        let baseHeaders = authorized ? authHeader() : ["content-type": "application/json"]
        let merged = baseHeaders.merging(headers, uniquingKeysWith: { a, _ in a })
        return try await request(method: method, path: path, headers: merged, body: body)
    }
}

// MARK: - Device helpers
extension EntityAuth {
    private static func decodeTenantId(fromJWT token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payloadB64 = String(parts[1])
        guard let data = Data(base64URLEncoded: payloadB64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let tid = json["tid"] as? String { return tid }
        if let tidNum = json["tid"] as? NSNumber { return tidNum.stringValue }
        return nil
    }

    private static func decodeJWTPayload(fromJWT token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payloadB64 = String(parts[1])
        guard let data = Data(base64URLEncoded: payloadB64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
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


