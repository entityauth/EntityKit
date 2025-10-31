import Foundation
@preconcurrency import Combine
import EntityAuthCore
import EntityAuthNetworking
import EntityAuthRealtime

public protocol EntityAuthFacadeType: Sendable {
    func currentSnapshot() async -> EntityAuthFacade.Snapshot
    func snapshotStream() -> AsyncStream<EntityAuthFacade.Snapshot>
    func updateBaseURL(_ baseURL: URL) async
    func register(request: RegisterRequest) async throws
    func login(request: LoginRequest) async throws
    func logout() async throws
    func refreshTokens() async throws
    func organizations() async throws -> [OrganizationSummary]
    func activeOrganization() async throws -> ActiveOrganization?
}

public actor EntityAuthFacade {
    private struct LastUserStore {
        private let userDefaults: UserDefaults
        private let key = "com.entityauth.lastUserId"
        init(suiteName: String?) {
            if let suiteName, let ud = UserDefaults(suiteName: suiteName) {
                self.userDefaults = ud
            } else {
                self.userDefaults = .standard
            }
        }
        func load() -> String? { userDefaults.string(forKey: key) }
        func save(id: String?) { userDefaults.set(id, forKey: key) }
        func clear() { userDefaults.removeObject(forKey: key) }
    }
    public struct Dependencies {
        public var config: EntityAuthConfig
        public var baseURLStore: BaseURLPersisting
        public var authState: AuthState
        public var authService: any (AuthProviding & RefreshService)
        public var organizationService: OrganizationsProviding
        public var entitiesService: EntitiesProviding
        public var refreshHandler: TokenRefresher
        public var apiClient: any APIClientType
        public var realtime: RealtimeSubscriptionHandling
        public init(
            config: EntityAuthConfig,
            baseURLStore: BaseURLPersisting,
            authState: AuthState,
            authService: any (AuthProviding & RefreshService),
            organizationService: OrganizationsProviding,
            entitiesService: EntitiesProviding,
            refreshHandler: TokenRefresher,
            apiClient: any APIClientType,
            realtime: RealtimeSubscriptionHandling
        ) {
            self.config = config
            self.baseURLStore = baseURLStore
            self.authState = authState
            self.authService = authService
            self.organizationService = organizationService
            self.entitiesService = entitiesService
            self.refreshHandler = refreshHandler
            self.apiClient = apiClient
            self.realtime = realtime
        }
    }

    struct DependenciesBuilder {
        let config: EntityAuthConfig

        func build() -> Dependencies {
            let baseURLStore = UserDefaultsBaseURLStore(suiteName: config.userDefaultsSuiteName)
            let tokenStore = KeychainTokenStore()
            let authState = AuthState(tokenStore: tokenStore)
            var finalConfig = config
            if let persisted = baseURLStore.loadBaseURL() {
                finalConfig.baseURL = persisted
            }
            let refresher = TokenRefresher(authState: authState, refreshService: DummyRefreshService())
            let client = APIClient(
                config: finalConfig,
                authState: authState,
                refreshHandler: refresher
            )
            let authService = AuthService(client: client, authState: authState)
            let organizationService = OrganizationService(client: client)
            let entitiesService = EntitiesService(client: client)
            let realtime = RealtimeCoordinator(baseURL: finalConfig.baseURL) { baseURL in
                let request = APIRequest(method: .get, path: "/api/convex", requiresAuthentication: false)
                let data = try await client.send(request)
                struct ConvexConfig: Decodable { let convexUrl: String }
                let decoded = try JSONDecoder().decode(ConvexConfig.self, from: data)
                return decoded.convexUrl
            }
            return Dependencies(
                config: finalConfig,
                baseURLStore: baseURLStore,
                authState: authState,
                authService: authService,
                organizationService: organizationService,
                entitiesService: entitiesService,
                refreshHandler: refresher,
                apiClient: client,
                realtime: realtime
            )
        }
    }

    public struct Snapshot: Sendable {
        public var accessToken: String?
        public var refreshToken: String?
        public var sessionId: String?
        public var userId: String?
        public var username: String?
        public var organizations: [OrganizationSummary]
        public var activeOrganization: ActiveOrganization?

        public init(
            accessToken: String?,
            refreshToken: String?,
            sessionId: String?,
            userId: String?,
            username: String?,
            organizations: [OrganizationSummary],
            activeOrganization: ActiveOrganization?
        ) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.sessionId = sessionId
            self.userId = userId
            self.username = username
            self.organizations = organizations
            self.activeOrganization = activeOrganization
        }
    }

    private let authState: AuthState
    private let dependencies: Dependencies
    private var snapshot: Snapshot
    private let subject: CurrentValueSubject<Snapshot, Never>
    private var realtimeCancellable: AnyCancellable?
    private let lastUserStore: LastUserStore

    public var snapshotPublisher: AnyPublisher<Snapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(config: EntityAuthConfig) {
        let builder = DependenciesBuilder(config: config)
        let dependencies = builder.build()
        self.authState = dependencies.authState
        self.dependencies = dependencies
        self.lastUserStore = LastUserStore(suiteName: dependencies.config.userDefaultsSuiteName)
        self.snapshot = Snapshot(
            accessToken: authState.currentTokens.accessToken,
            refreshToken: authState.currentTokens.refreshToken,
            sessionId: nil,
            userId: nil,
            username: nil,
            organizations: [],
            activeOrganization: nil
        )
        self.subject = CurrentValueSubject(snapshot)
        Task { await self.initializeAsync() }
    }

    public init(dependencies: Dependencies, state: Snapshot) {
        self.dependencies = dependencies
        self.authState = dependencies.authState
        self.lastUserStore = LastUserStore(suiteName: dependencies.config.userDefaultsSuiteName)
        self.snapshot = state
        self.subject = CurrentValueSubject(state)
        Task { await self.initializeAsync() }
    }

    public func publisher() -> AnyPublisher<Snapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    public func snapshotStream() -> AsyncStream<Snapshot> {
        let subject = subject
        return AsyncStream { continuation in
            let cancellable = subject.sink { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    }

    public func currentSnapshot() -> Snapshot {
        snapshot
    }

    public func updateBaseURL(_ baseURL: URL) async {
        dependencies.baseURLStore.save(baseURL: baseURL)
        dependencies.apiClient.updateConfiguration { config in
            config.baseURL = baseURL
        }
        dependencies.realtime.update(baseURL: baseURL)
    }

    public func register(request: RegisterRequest) async throws {
        let req = request
        try await dependencies.authService.register(request: req)
    }

    public func login(request: LoginRequest) async throws {
        let req = request
        let response = try await dependencies.authService.login(request: req)
        try authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
        snapshot.accessToken = response.accessToken
        snapshot.refreshToken = response.refreshToken
        snapshot.sessionId = response.sessionId
        snapshot.userId = response.userId
        lastUserStore.save(id: response.userId)
        subject.send(snapshot)
        if let userId = snapshot.userId {
            await dependencies.realtime.start(userId: userId, sessionId: snapshot.sessionId)
        }
        try await refreshUserData()
    }

    public func logout() async throws {
        try await dependencies.authService.logout(sessionId: snapshot.sessionId, refreshToken: snapshot.refreshToken)
        try authState.clear()
        snapshot = Snapshot(accessToken: nil, refreshToken: nil, sessionId: nil, userId: nil, username: nil, organizations: [], activeOrganization: nil)
        subject.send(snapshot)
        await dependencies.realtime.stop()
        lastUserStore.clear()
    }

    /// Hard reset local auth state without contacting the server.
    /// Useful in development to clear Keychain tokens and local snapshot if state becomes inconsistent.
    public func hardResetLocalAuth() async {
        try? authState.clear()
        snapshot = Snapshot(accessToken: nil, refreshToken: nil, sessionId: nil, userId: nil, username: nil, organizations: [], activeOrganization: nil)
        subject.send(snapshot)
        await dependencies.realtime.stop()
        lastUserStore.clear()
    }

    public func refreshTokens() async throws {
        let response = try await dependencies.authService.refresh()
        try authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
        snapshot.accessToken = response.accessToken
        snapshot.refreshToken = response.refreshToken
        subject.send(snapshot)
    }

    // MARK: - Passkeys
    
    /// Sign in with passkey
    public func passkeySignIn(rpId: String, origins: [String]) async throws -> LoginResponse {
        let passkeyService = PasskeyAuthService(
            authService: dependencies.authService,
            workspaceTenantId: dependencies.config.workspaceTenantId
        )
        let response = try await passkeyService.signIn(userId: nil, rpId: rpId, origins: origins)
        try authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
        snapshot.accessToken = response.accessToken
        snapshot.refreshToken = response.refreshToken
        snapshot.sessionId = response.sessionId
        snapshot.userId = response.userId
        lastUserStore.save(id: response.userId)
        subject.send(snapshot)
        if let userId = snapshot.userId {
            await dependencies.realtime.start(userId: userId, sessionId: snapshot.sessionId)
        }
        try await refreshUserData()
        return response
    }
    
    /// Sign up with passkey
    public func passkeySignUp(email: String, rpId: String, origins: [String]) async throws -> LoginResponse {
        let passkeyService = PasskeyAuthService(
            authService: dependencies.authService,
            workspaceTenantId: dependencies.config.workspaceTenantId
        )
        let response = try await passkeyService.signUp(email: email, rpId: rpId, origins: origins)
        try authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
        snapshot.accessToken = response.accessToken
        snapshot.refreshToken = response.refreshToken
        snapshot.sessionId = response.sessionId
        snapshot.userId = response.userId
        lastUserStore.save(id: response.userId)
        subject.send(snapshot)
        if let userId = snapshot.userId {
            await dependencies.realtime.start(userId: userId, sessionId: snapshot.sessionId)
        }
        try await refreshUserData()
        return response
    }

    // MARK: - Convenience helpers for SSO/Passkeys

    /// Apply externally obtained tokens (e.g., from SSO exchange) and hydrate state
    public func applyTokens(accessToken: String, refreshToken: String?, sessionId: String?, userId: String?) async throws {
        try dependencies.authState.update(accessToken: accessToken, refreshToken: refreshToken)
        snapshot.accessToken = accessToken
        snapshot.refreshToken = refreshToken ?? snapshot.refreshToken
        snapshot.sessionId = sessionId
        snapshot.userId = userId
        subject.send(snapshot)
        if let userId = snapshot.userId {
            await dependencies.realtime.start(userId: userId, sessionId: snapshot.sessionId)
        }
        try await refreshUserData()
    }

    // MARK: - Post-SSO Bootstrap (parity with Web)

    public struct SSOBootstrapOptions: Sendable {
        public var createEAOrgIfMissing: Bool
        public var defaultOrgName: String?
        public init(createEAOrgIfMissing: Bool = false, defaultOrgName: String? = nil) {
            self.createEAOrgIfMissing = createEAOrgIfMissing
            self.defaultOrgName = defaultOrgName
        }
    }

    /// Mirrors web's SSOBootstrap: ensures EA has an organization and invokes Convex ensureUser/ensureOrganization.
    /// - Parameters:
    ///   - options: Controls EA org auto-creation behavior and naming.
    ///   - ensureUser: Closure that must invoke the backend action to ensure a Convex user exists.
    ///   - ensureOrganization: Closure that must invoke the backend action to ensure a Convex org exists, optionally using the EA org id.
    public func bootstrapAfterSSO(
        options: SSOBootstrapOptions = SSOBootstrapOptions(),
        ensureUser: @escaping @Sendable () async throws -> Void,
        ensureOrganization: @escaping @Sendable (_ eaOrgId: String?) async throws -> Void
    ) async throws {
        print("[EntityAuth][Bootstrap] begin")
        // Step 1: Make sure we have fresh tokens and a hydrated snapshot
        do {
            try await refreshTokens()
            print("[EntityAuth][Bootstrap] refreshTokens ✓ access=\(snapshot.accessToken != nil) refresh=\(snapshot.refreshToken != nil)")
        } catch {
            // Proceed even if refresh fails; snapshot may already have valid tokens
            print("[EntityAuth][Bootstrap] refreshTokens error: \(error)")
        }

        // Ensure we know current user id for EA operations
        if snapshot.userId == nil {
            do {
                let req = APIRequest(method: .get, path: "/api/user/me")
                let me = try await dependencies.apiClient.send(req, decode: UserResponse.self)
                snapshot.userId = me.id
                subject.send(snapshot)
                print("[EntityAuth][Bootstrap] resolved userId=\(me.id)")
            } catch {
                // If we cannot resolve user id, we cannot create EA org with an actorId
                print("[EntityAuth][Bootstrap] failed to resolve userId: \(error)")
            }
        }

        // Step 2: Read EA organizations (no client-side creation)
        var eaOrgId: String? = nil
        do {
            let orgs = try await organizations()
            print("[EntityAuth][Bootstrap] orgs count=\(orgs.count)")
            if let existing = orgs.first { // Pick first membership as active org
                eaOrgId = existing.orgId
            }
        } catch {
            // If listing organizations fails, continue; Convex ensure may still create membership
            print("[EntityAuth][Bootstrap] organizations() failed: \(error)")
        }

        // Step 3: Ensure Convex user and organization
        print("[EntityAuth][Bootstrap] ensuring user in Convex...")
        try await ensureUser()
        print("[EntityAuth][Bootstrap] ensuring organization in Convex with eaOrgId=\(eaOrgId ?? "<none>")...")
        try await ensureOrganization(eaOrgId)
        print("[EntityAuth][Bootstrap] complete")
    }

    /// Register a passkey using native platform APIs and server WebAuthn endpoints
    public func registerPasskey(userId: String, rpId: String, origins: [String]) async throws -> FinishRegistrationResponse {
        guard let workspaceTenantId = dependencies.apiClient.workspaceTenantId else { throw EntityAuthError.configurationMissingBaseURL }
        let service = PasskeyAuthService(authService: dependencies.authService, workspaceTenantId: workspaceTenantId)
        return try await service.register(userId: userId, rpId: rpId, origins: origins)
    }

    /// Sign in with a passkey and update the current session
    public func signInWithPasskey(userId: String?, rpId: String, origins: [String]) async throws {
        guard let workspaceTenantId = dependencies.apiClient.workspaceTenantId else { throw EntityAuthError.configurationMissingBaseURL }
        let service = PasskeyAuthService(authService: dependencies.authService, workspaceTenantId: workspaceTenantId)
        let response = try await service.signIn(userId: userId, rpId: rpId, origins: origins)
        try dependencies.authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
        snapshot.accessToken = response.accessToken
        snapshot.refreshToken = response.refreshToken
        snapshot.sessionId = response.sessionId
        snapshot.userId = response.userId
        subject.send(snapshot)
        if let userId = snapshot.userId {
            await dependencies.realtime.start(userId: userId, sessionId: snapshot.sessionId)
        }
        try await refreshUserData()
    }

    /// Sign up with a passkey using email (creates new user account) and update the current session
    public func signUpWithPasskey(email: String, rpId: String, origins: [String]) async throws {
        guard let workspaceTenantId = dependencies.apiClient.workspaceTenantId else {
            print("[Facade] signUpWithPasskey: workspaceTenantId is nil!")
            throw EntityAuthError.configurationMissingBaseURL
        }
        print("[Facade] signUpWithPasskey: workspaceTenantId=", workspaceTenantId, "email=", email)
        let service = PasskeyAuthService(authService: dependencies.authService, workspaceTenantId: workspaceTenantId)
        let response = try await service.signUp(email: email, rpId: rpId, origins: origins)
        try dependencies.authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
        snapshot.accessToken = response.accessToken
        snapshot.refreshToken = response.refreshToken
        snapshot.sessionId = response.sessionId
        snapshot.userId = response.userId
        lastUserStore.save(id: response.userId)
        subject.send(snapshot)
        if let userId = snapshot.userId {
            await dependencies.realtime.start(userId: userId, sessionId: snapshot.sessionId)
        }
        try await refreshUserData()
    }

    public func organizations() async throws -> [OrganizationSummary] {
        try await dependencies.organizationService.list().map { $0.asDomain }
    }

    public func createOrganization(name: String, slug: String, ownerId: String) async throws {
        try await dependencies.organizationService.create(name: name, slug: slug, ownerId: ownerId)
        try await refreshUserData()
    }

    public func addMember(orgId: String, userId: String, role: String) async throws {
        try await dependencies.organizationService.addMember(orgId: orgId, userId: userId, role: role)
        try await refreshUserData()
    }

    public func switchOrg(orgId: String) async throws {
        let newAccessToken = try await dependencies.organizationService.switchOrg(orgId: orgId)
        try dependencies.authState.update(accessToken: newAccessToken)
        snapshot.accessToken = newAccessToken
        subject.send(snapshot)
        try await refreshUserData()
    }

    public func activeOrganization() async throws -> ActiveOrganization? {
        try await dependencies.organizationService.active()?.asDomain
    }

    public func setUsername(_ username: String) async throws {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EntityAuthError.invalidResponse }
        guard let userId = snapshot.userId else { throw EntityAuthError.unauthorized }
        let slug = normalizeUsername(trimmed)
        let _ = try await dependencies.entitiesService.updateEnforced(
            id: userId,
            patch: [
                "properties": ["username": trimmed],
                "metadata": ["usernameSlug": slug]
            ],
            actorId: userId
        )
        // UI will update via realtime; optimistic reflect username
        snapshot.username = trimmed
        subject.send(snapshot)
    }

    public func checkUsername(_ value: String) async throws -> UsernameCheckResponse {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return UsernameCheckResponse(valid: false, available: false) }
        let slug = normalizeUsername(trimmed)
        guard let workspaceTenantId = dependencies.apiClient.workspaceTenantId else {
            return UsernameCheckResponse(valid: false, available: false)
        }
        let results = try await dependencies.entitiesService.list(
            workspaceTenantId: workspaceTenantId,
            kind: "user",
            filter: ListEntitiesFilter(status: "active", email: nil, slug: slug),
            limit: 1
        )
        // Available if none found or found id equals current user
        let foundId = results.first?.id
        let available: Bool = {
            if let foundId, let current = snapshot.userId { return foundId == current }
            return results.isEmpty
        }()
        return UsernameCheckResponse(valid: true, available: available)
    }

    public func fetchGraphQL<T: Decodable>(query: String, variables: [String: Any]?) async throws -> T {
        let data = try GraphQLRequestBuilder.make(query: query, variables: variables)
        let request = APIRequest(method: .post, path: "/api/graphql", body: data)
        let response = try await dependencies.apiClient.send(request)
        do {
            let wrapper = try JSONDecoder().decode(GraphQLWrapper<T>.self, from: response)
            guard let data = wrapper.data else { throw EntityAuthError.invalidResponse }
            return data
        } catch let error as DecodingError {
            throw EntityAuthError.decoding(error)
        }
    }

    private func refreshUserData() async throws {
        let organizations = try await dependencies.organizationService.list().map { $0.asDomain }
        let active = try await dependencies.organizationService.active()?.asDomain
        snapshot.organizations = organizations
        snapshot.activeOrganization = active
        subject.send(snapshot)
    }

    private func handle(event: RealtimeEvent) async {
        switch event {
        case let .username(value):
            snapshot.username = value
        case let .organizations(orgs):
            snapshot.organizations = orgs.map { $0.asDomain }
        case let .activeOrganization(org):
            snapshot.activeOrganization = org.map { $0.asDomain }
        case .sessionInvalid:
            snapshot = Snapshot(accessToken: nil, refreshToken: nil, sessionId: nil, userId: nil, username: nil, organizations: [], activeOrganization: nil)
            try? authState.clear()
        }
        subject.send(snapshot)
    }
}

extension EntityAuthFacade {
    private func isAccessTokenExpiringSoon(_ jwt: String, skewSeconds: Int = 90) -> Bool {
        // Very lightweight JWT exp decoder: split by '.', base64url decode payload, read 'exp'
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return false }
        let payloadPart = String(parts[1])
        func base64urlToData(_ s: String) -> Data? {
            var str = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let padding = (4 - (str.count % 4)) % 4
            if padding > 0 { str.append(String(repeating: "=", count: padding)) }
            return Data(base64Encoded: str)
        }
        guard let data = base64urlToData(payloadPart),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double else { return false }
        let now = Date().timeIntervalSince1970
        return exp <= (now + Double(skewSeconds))
    }

    private func shouldAttemptRefresh(after error: Error) -> Bool {
        // Treat Unauthorized and HTTP 400 with exp claim failures as refreshable
        if case EntityAuthError.unauthorized = error { return true }
        if case let EntityAuthError.network(status, message) = error {
            if status == 400, (message ?? "").lowercased().contains("exp") { return true }
        }
        // Also for generic decoding/network that mention exp claim
        let text = (error as NSError).localizedDescription.lowercased()
        return text.contains("exp") || text.contains("unauthorized")
    }
    private func initializeAsync() async {
        await dependencies.refreshHandler.replaceRefreshService(with: dependencies.authService)
        setupRealtimeSubscriptions()
        // Prefill last-known userId immediately for seamless UI
        if snapshot.userId == nil, let last = lastUserStore.load() {
            snapshot.userId = last
            subject.send(snapshot)
        }
        // Eagerly hydrate userId on cold start if tokens are present
        if dependencies.authState.currentTokens.accessToken != nil || dependencies.authState.currentTokens.refreshToken != nil {
            do {
                let access = dependencies.authState.currentTokens.accessToken
                if let access, isAccessTokenExpiringSoon(access) {
                    let refreshed = try await dependencies.authService.refresh()
                    try? dependencies.authState.update(accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken)
                    snapshot.accessToken = refreshed.accessToken
                    snapshot.refreshToken = refreshed.refreshToken ?? snapshot.refreshToken
                    subject.send(snapshot)
                }
                let req = APIRequest(method: .get, path: "/api/user/me")
                let me = try await dependencies.apiClient.send(req, decode: UserResponse.self)
                snapshot.userId = me.id
                subject.send(snapshot)
            } catch {
                _ = (error as? EntityAuthError)?.errorDescription ?? error.localizedDescription
                // If failure indicates expired/invalid access token, attempt one refresh then retry hydration
                if shouldAttemptRefresh(after: error) {
                    do {
                        let refreshed = try await dependencies.authService.refresh()
                        try? dependencies.authState.update(accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken)
                        snapshot.accessToken = refreshed.accessToken
                        snapshot.refreshToken = refreshed.refreshToken ?? snapshot.refreshToken
                        subject.send(snapshot)
                        let req = APIRequest(method: .get, path: "/api/user/me")
                        let me = try await dependencies.apiClient.send(req, decode: UserResponse.self)
                        snapshot.userId = me.id
                        subject.send(snapshot)
                    } catch {
                        _ = (error as? EntityAuthError)?.errorDescription ?? error.localizedDescription
                    }
                }
            }
        }
    }
    private func setupRealtimeSubscriptions() {
        realtimeCancellable = dependencies.realtime.publisher().sink { [weak self] event in
            guard let self else { return }
            Task { await self.handle(event: event) }
        }
    }
}

private final class DummyRefreshService: RefreshService {
    func refresh() async throws -> RefreshResponse {
        throw EntityAuthError.refreshFailed
    }
}

private extension RealtimeOrganizationSummary {
    var asDomain: OrganizationSummary {
        OrganizationSummary(
            orgId: orgId,
            name: name,
            slug: slug,
            memberCount: memberCount,
            role: role,
            joinedAt: joinedAt,
            workspaceTenantId: workspaceTenantId
        )
    }
}

private extension RealtimeActiveOrganization {
    var asDomain: ActiveOrganization {
        ActiveOrganization(
            orgId: orgId,
            name: name,
            slug: slug,
            memberCount: memberCount,
            role: role,
            joinedAt: joinedAt,
            workspaceTenantId: workspaceTenantId,
            description: description
        )
    }
}
