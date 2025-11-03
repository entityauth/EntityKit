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
        public var email: String?
        public var imageUrl: String?
        public var organizations: [OrganizationSummary]
        public var activeOrganization: ActiveOrganization?

        public init(
            accessToken: String?,
            refreshToken: String?,
            sessionId: String?,
            userId: String?,
            username: String?,
            email: String? = nil,
            imageUrl: String? = nil,
            organizations: [OrganizationSummary],
            activeOrganization: ActiveOrganization?
        ) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.sessionId = sessionId
            self.userId = userId
            self.username = username
            self.email = email
            self.imageUrl = imageUrl
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
    // Coalescing support to avoid emitting half-hydrated snapshots
    private var emitSuppressionCount: Int = 0
    private var hasPendingEmission: Bool = false

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
            email: nil,
            imageUrl: nil,
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
    
    // MARK: - Emission control
    private func emit() {
        if emitSuppressionCount == 0 {
            subject.send(snapshot)
        } else {
            hasPendingEmission = true
        }
    }
    
    private func coalesced<T>(_ work: () async throws -> T) async rethrows -> T {
        emitSuppressionCount += 1
        defer {
            emitSuppressionCount -= 1
            if emitSuppressionCount == 0, hasPendingEmission {
                subject.send(snapshot)
                hasPendingEmission = false
            }
        }
        return try await work()
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
        try await coalesced {
            let req = request
            let response = try await dependencies.authService.login(request: req)
            try authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
            snapshot.accessToken = response.accessToken
            snapshot.refreshToken = response.refreshToken
            snapshot.sessionId = response.sessionId
            snapshot.userId = response.userId
            lastUserStore.save(id: response.userId)
            if let userId = snapshot.userId {
                await dependencies.realtime.start(userId: userId, sessionId: snapshot.sessionId)
            }
            try await refreshUserData()
            
            // If login token has no oid but user has orgs, switch to first org
            // This handles the case where server issues token without oid claim initially
            if snapshot.activeOrganization == nil, let firstOrg = snapshot.organizations.first?.orgId {
                print("[EntityAuth][login] Token has no oid but user has orgs - switching to first org: \(firstOrg)")
                do {
                    let newToken = try await dependencies.organizationService.switchOrg(orgId: firstOrg)
                    try dependencies.authState.update(accessToken: newToken)
                    snapshot.accessToken = newToken
                    print("[EntityAuth][login] Got new token with oid=\(currentActiveOrgIdFromAccessToken() ?? "nil")")
                    try await refreshUserData()
                    print("[EntityAuth][login] Org switch complete - activeOrg=\(snapshot.activeOrganization?.orgId ?? "nil")")
                } catch {
                    print("[EntityAuth][login] WARNING: Failed to switch to first org: \(error) - continuing with existing token")
                }
            }
            
            emit()
        }
    }

    public func logout() async throws {
        try await dependencies.authService.logout(sessionId: snapshot.sessionId, refreshToken: snapshot.refreshToken)
        try authState.clear()
        snapshot = Snapshot(accessToken: nil, refreshToken: nil, sessionId: nil, userId: nil, username: nil, email: nil, imageUrl: nil, organizations: [], activeOrganization: nil)
        emit()
        await dependencies.realtime.stop()
        lastUserStore.clear()
    }

    /// Hard reset local auth state without contacting the server.
    /// Useful in development to clear Keychain tokens and local snapshot if state becomes inconsistent.
    public func hardResetLocalAuth() async {
        try? authState.clear()
        snapshot = Snapshot(accessToken: nil, refreshToken: nil, sessionId: nil, userId: nil, username: nil, email: nil, imageUrl: nil, organizations: [], activeOrganization: nil)
        emit()
        await dependencies.realtime.stop()
        lastUserStore.clear()
    }

    public func refreshTokens() async throws {
        // Use coalesced to ensure token refresh + org state refresh happen atomically
        // This prevents emitting incomplete snapshots (tokens updated but org state stale)
        try await coalesced {
            print("[EntityAuth][refreshTokens] BEGIN - current orgId=\(snapshot.activeOrganization?.orgId ?? "nil")")
            let oldTokenOid = currentActiveOrgIdFromAccessToken()
            print("[EntityAuth][refreshTokens] OLD token oid=\(oldTokenOid ?? "nil")")
            
            // Step 1: Refresh tokens
            let response = try await dependencies.authService.refresh()
            try authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
            snapshot.accessToken = response.accessToken
            snapshot.refreshToken = response.refreshToken
            
            let newTokenOid = currentActiveOrgIdFromAccessToken()
            print("[EntityAuth][refreshTokens] NEW token oid=\(newTokenOid ?? "nil")")
            
            // Step 2: Refresh org state to match new token's oid claim
            // This ensures snapshot.activeOrganization stays in sync with the token
            print("[EntityAuth][refreshTokens] Refreshing org state to match new token...")
            do {
                try await refreshUserData()
                print("[EntityAuth][refreshTokens] Org state refreshed successfully - new orgId=\(snapshot.activeOrganization?.orgId ?? "nil")")
            } catch {
                print("[EntityAuth][refreshTokens] WARNING: Token refreshed but org state refresh failed: \(error)")
                print("[EntityAuth][refreshTokens] Org state may be stale, but tokens are valid")
                // Continue - tokens are valid even if org fetch fails
                // refreshUserData() would have emitted, but since it failed, we emit here
                emit()
            }
            print("[EntityAuth][refreshTokens] END")
        }
    }

    // MARK: - Passkeys
    
    /// Sign in with passkey
    public func passkeySignIn(rpId: String, origins: [String]) async throws -> LoginResponse {
        let passkeyService = PasskeyAuthService(
            authService: dependencies.authService,
            workspaceTenantId: dependencies.config.workspaceTenantId
        )
        let response = try await passkeyService.signIn(userId: nil, rpId: rpId, origins: origins)
        try await coalesced {
            try authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
            snapshot.accessToken = response.accessToken
            snapshot.refreshToken = response.refreshToken
            snapshot.sessionId = response.sessionId
            snapshot.userId = response.userId
            lastUserStore.save(id: response.userId)
            if let userId = snapshot.userId {
                await dependencies.realtime.start(userId: userId, sessionId: snapshot.sessionId)
            }
            try await refreshUserData()
            
            // If passkey token has no oid but user has orgs, switch to first org
            if snapshot.activeOrganization == nil, let firstOrg = snapshot.organizations.first?.orgId {
                print("[EntityAuth][passkeySignIn] Token has no oid but user has orgs - switching to first org: \(firstOrg)")
                do {
                    let newToken = try await dependencies.organizationService.switchOrg(orgId: firstOrg)
                    try dependencies.authState.update(accessToken: newToken)
                    snapshot.accessToken = newToken
                    try await refreshUserData()
                } catch {
                    print("[EntityAuth][passkeySignIn] WARNING: Failed to switch to first org: \(error)")
                }
            }
            
            emit()
        }
        return response
    }
    
    /// Sign up with passkey
    public func passkeySignUp(email: String, rpId: String, origins: [String]) async throws -> LoginResponse {
        let passkeyService = PasskeyAuthService(
            authService: dependencies.authService,
            workspaceTenantId: dependencies.config.workspaceTenantId
        )
        let response = try await passkeyService.signUp(email: email, rpId: rpId, origins: origins)
        try await coalesced {
            try authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
            snapshot.accessToken = response.accessToken
            snapshot.refreshToken = response.refreshToken
            snapshot.sessionId = response.sessionId
            snapshot.userId = response.userId
            lastUserStore.save(id: response.userId)
            if let userId = snapshot.userId {
                await dependencies.realtime.start(userId: userId, sessionId: snapshot.sessionId)
            }
            try await refreshUserData()
            try await ensureOrganizationAndActivateIfMissing()
            try await refreshUserData()
            
            // If still no active org but memberships exist (e.g., token has no oid), select the first one
            if snapshot.activeOrganization == nil, let firstOrg = snapshot.organizations.first?.orgId {
                print("[EntityAuth][passkeySignUp] Token has no oid but user has orgs - switching to first org: \(firstOrg)")
                do {
                    let newToken = try await dependencies.organizationService.switchOrg(orgId: firstOrg)
                    try dependencies.authState.update(accessToken: newToken)
                    snapshot.accessToken = newToken
                    try await refreshUserData()
                } catch {
                    print("[EntityAuth][passkeySignUp] WARNING: Failed to switch to first org: \(error)")
                }
            }
            
            emit()
        }
        return response
    }

    // MARK: - Convenience helpers for SSO/Passkeys

    /// Apply externally obtained tokens (e.g., from SSO exchange) and hydrate state
    public func applyTokens(accessToken: String, refreshToken: String?, sessionId: String?, userId: String?) async throws {
        try await coalesced {
            try dependencies.authState.update(accessToken: accessToken, refreshToken: refreshToken)
            snapshot.accessToken = accessToken
            snapshot.refreshToken = refreshToken ?? snapshot.refreshToken
            snapshot.sessionId = sessionId
            snapshot.userId = userId
            if let userId = snapshot.userId {
                await dependencies.realtime.start(userId: userId, sessionId: snapshot.sessionId)
            }
            // Hydrate and ensure org before first emission
            try await refreshUserData()
            try await ensureOrganizationAndActivateIfMissing()
            try await refreshUserData()
            if snapshot.activeOrganization == nil, let firstOrg = snapshot.organizations.first?.orgId {
                do {
                    let newToken = try await dependencies.organizationService.switchOrg(orgId: firstOrg)
                    try dependencies.authState.update(accessToken: newToken)
                    snapshot.accessToken = newToken
                    try await refreshUserData()
                } catch {
                    print("[EntityAuth][applyTokens] WARNING: Failed to switch to first org: \(error)")
                }
            }
            emit()
        }
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
                snapshot.username = me.username
                snapshot.email = me.email
                snapshot.imageUrl = me.imageUrl
                emit()
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
        // First-class mobile bootstrap: if user has no organizations yet, create one and switch
        try await ensureOrganizationAndActivateIfMissing()
    }

    public func organizations() async throws -> [OrganizationSummary] {
        try await dependencies.organizationService.list().map { $0.asDomain }
    }

    public func createOrganization(name: String, slug: String, ownerId: String) async throws {
        try await dependencies.organizationService.create(name: name, slug: slug, ownerId: ownerId)
        try await refreshUserData()
    }

    // MARK: - Organization updates (active org)
    public func setOrganizationName(_ name: String) async throws {
        try await dependencies.organizationService.setActiveOrgName(name)
        try? await refreshUserData()
    }

    public func setOrganizationSlug(_ slug: String) async throws {
        try await dependencies.organizationService.setActiveOrgSlug(slug)
        try? await refreshUserData()
    }

    public func setOrganizationImageUrl(_ imageUrl: String) async throws {
        try await dependencies.organizationService.setActiveOrgImageUrl(imageUrl)
        try? await refreshUserData()
    }

    public func addMember(orgId: String, userId: String, role: String) async throws {
        try await dependencies.organizationService.addMember(orgId: orgId, userId: userId, role: role)
        try await refreshUserData()
    }

    public func switchOrg(orgId: String) async throws {
        print("[EntityAuth][switchOrg] begin orgId=\(orgId)")
        try await coalesced {
            let newAccessToken = try await dependencies.organizationService.switchOrg(orgId: orgId)
            print("[EntityAuth][switchOrg] received new access token (len=\(newAccessToken.count))")
            try dependencies.authState.update(accessToken: newAccessToken)
            snapshot.accessToken = newAccessToken
            print("[EntityAuth][switchOrg] refreshing user data...")
            try await refreshUserData()
            print("[EntityAuth][switchOrg] refresh complete orgs=\(snapshot.organizations.count) active=\(snapshot.activeOrganization?.orgId ?? "nil")")
            emit()
        }
    }

    public func activeOrganization() async throws -> ActiveOrganization? {
        // Source of truth is the access token's `oid` (or `orgId`) claim
        guard let oid = currentActiveOrgIdFromAccessToken() else { return nil }
        if let matched = snapshot.organizations.first(where: { $0.orgId == oid }) {
            return ActiveOrganization(
                orgId: matched.orgId,
                name: matched.name,
                slug: matched.slug,
                memberCount: matched.memberCount,
                role: matched.role,
                joinedAt: matched.joinedAt,
                workspaceTenantId: matched.workspaceTenantId,
                description: nil
            )
        }
        return ActiveOrganization(
            orgId: oid,
            name: nil,
            slug: nil,
            memberCount: nil,
            role: "",
            joinedAt: 0,
            workspaceTenantId: nil,
            description: nil
        )
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
        emit()
    }

    public func setEmail(_ email: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EntityAuthError.invalidResponse }
        guard let userId = snapshot.userId else { throw EntityAuthError.unauthorized }
        let _ = try await dependencies.entitiesService.updateEnforced(
            id: userId,
            patch: [
                "properties": ["email": trimmed]
            ],
            actorId: userId
        )
        snapshot.email = trimmed
        emit()
    }

    public func setImageUrl(_ imageUrl: String) async throws {
        let trimmed = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EntityAuthError.invalidResponse }
        guard let userId = snapshot.userId else { throw EntityAuthError.unauthorized }
        let _ = try await dependencies.entitiesService.updateEnforced(
            id: userId,
            patch: [
                "properties": ["imageUrl": trimmed]
            ],
            actorId: userId
        )
        snapshot.imageUrl = trimmed
        emit()
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
        print("[EntityAuth][refreshUserData] BEGIN")
        print("[EntityAuth][refreshUserData] About to fetch organizations...")
        
        do {
            let organizations = try await dependencies.organizationService.list().map { $0.asDomain }
            print("[EntityAuth][refreshUserData] Successfully fetched \(organizations.count) organizations: \(organizations.map { "\($0.orgId):\($0.name ?? "unnamed")" }.joined(separator: ", "))")
            snapshot.organizations = organizations
            
            // Derive active org from token `oid` claim
            let tokenOid = currentActiveOrgIdFromAccessToken()
            print("[EntityAuth][refreshUserData] Token oid=\(tokenOid ?? "nil")")
            
            if let oid = tokenOid, let matched = organizations.first(where: { $0.orgId == oid }) {
                print("[EntityAuth][refreshUserData] Matched token oid to org: \(matched.orgId)")
                snapshot.activeOrganization = ActiveOrganization(
                    orgId: matched.orgId,
                    name: matched.name,
                    slug: matched.slug,
                    memberCount: matched.memberCount,
                    role: matched.role,
                    joinedAt: matched.joinedAt,
                    workspaceTenantId: matched.workspaceTenantId,
                    description: nil
                )
            } else if let oid = tokenOid {
                print("[EntityAuth][refreshUserData] Token has oid=\(oid) but NO matching org in list - creating minimal ActiveOrganization")
                snapshot.activeOrganization = ActiveOrganization(
                    orgId: oid,
                    name: nil,
                    slug: nil,
                    memberCount: nil,
                    role: "",
                    joinedAt: 0,
                    workspaceTenantId: nil,
                    description: nil
                )
            } else {
                print("[EntityAuth][refreshUserData] WARNING: Token has NO oid claim and \(organizations.count) org(s) exist - setting activeOrganization=nil")
                snapshot.activeOrganization = nil
            }
        } catch {
            print("[EntityAuth][refreshUserData] ERROR: Failed to fetch organizations: \(error)")
            print("[EntityAuth][refreshUserData] Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("[EntityAuth][refreshUserData] NSError domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)")
            }
            
            // If 404, user was deleted - clear all auth state
            if case let EntityAuthError.network(status, _) = error, status == 404 {
                print("[EntityAuth][refreshUserData] User not found (404) - clearing tokens")
                try? authState.clear()
                snapshot = Snapshot(accessToken: nil, refreshToken: nil, sessionId: nil, userId: nil, username: nil, email: nil, imageUrl: nil, organizations: [], activeOrganization: nil)
                emit()
                await dependencies.realtime.stop()
                lastUserStore.clear()
                print("[EntityAuth][refreshUserData] Auth cleared due to deleted user")
                return // Exit early
            }
            
            throw error // Re-throw so caller knows it failed
        }
        
        // Also hydrate identity (email, username, image) to ensure snapshot is complete post-SSO/login
        do {
            let req = APIRequest(method: .get, path: "/api/user/me")
            let me = try await dependencies.apiClient.send(req, decode: UserResponse.self)
            snapshot.userId = me.id
            snapshot.username = me.username
            snapshot.email = me.email
            snapshot.imageUrl = me.imageUrl
            print("[EntityAuth][refreshUserData] Updated identity: userId=\(me.id) email=\(me.email ?? "nil")")
        } catch {
            print("[EntityAuth][refreshUserData] WARNING: Failed to fetch /api/user/me: \(error) - keeping prior identity")
            
            // If 404, user was deleted - clear all auth state
            if case let EntityAuthError.network(status, _) = error, status == 404 {
                print("[EntityAuth][refreshUserData] User not found (404) in /api/user/me - clearing tokens")
                try? authState.clear()
                snapshot = Snapshot(accessToken: nil, refreshToken: nil, sessionId: nil, userId: nil, username: nil, email: nil, imageUrl: nil, organizations: [], activeOrganization: nil)
                emit()
                await dependencies.realtime.stop()
                lastUserStore.clear()
                print("[EntityAuth][refreshUserData] Auth cleared due to deleted user")
                return // Exit early
            }
            // Non-fatal for other errors; keep prior identity fields if request fails
        }
        
        print("[EntityAuth][refreshUserData] END orgs=\(snapshot.organizations.count) active=\(snapshot.activeOrganization?.orgId ?? "nil")")
        emit()
    }

    // MARK: - Org bootstrap (parity with web)
    private func ensureOrganizationAndActivateIfMissing() async throws {
        if !(snapshot.organizations.isEmpty) { return }
        guard let userId = snapshot.userId else { return }
        // Derive a base from username or email local-part
        let identity = try await fetchCurrentUserIdentity()
        let base: String = {
            let username = (snapshot.username ?? identity.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !username.isEmpty { return username }
            if let email = identity.email, let local = email.split(separator: "@").first, !local.isEmpty { return String(local) }
            return "account"
        }()
        let orgDisplayName: String = makePossessive(base) + " Org"
        let baseSlug = makeSlug(base)
        // Try to create with incrementing slug suffix until success
        var createdOrgId: String? = nil
        for attempt in 0..<10 {
            let candidateSlug = attempt == 0 ? baseSlug : "\(baseSlug)-\(attempt+1)"
            do {
                try await createOrganization(name: orgDisplayName, slug: candidateSlug, ownerId: userId)
                // Refresh and capture id
                let refreshed = try await dependencies.organizationService.list().map { $0.asDomain }
                snapshot.organizations = refreshed
                emit()
                createdOrgId = (refreshed.first { ($0.slug ?? "") == candidateSlug }?.orgId) ?? refreshed.first?.orgId
                break
            } catch {
                // If duplicate constraint, continue; else rethrow
                let text = (error as NSError).localizedDescription.lowercased()
                if text.contains("slug") || text.contains("unique") || text.contains("duplicate") {
                    continue
                } else {
                    throw error
                }
            }
        }
        if let oid = createdOrgId {
            try await switchOrg(orgId: oid)
        }
    }

    private func makeSlug(_ input: String) -> String {
        let lowered = input.lowercased()
        let replaced = lowered
            .replacingOccurrences(of: "'s", with: "")
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: " ", with: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let filtered = replaced.unicodeScalars.filter { allowed.contains($0) }
        var result = String(String.UnicodeScalarView(filtered))
        while result.contains("--") { result = result.replacingOccurrences(of: "--", with: "-") }
        if result.hasPrefix("-") { result.removeFirst() }
        if result.hasSuffix("-") { result.removeLast() }
        return result.isEmpty ? "org" : result
    }

    private func makePossessive(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return "My" }
        if last == "s" || last == "S" { return trimmed + "'" }
        return trimmed + "'s"
    }

    private func fetchCurrentUserIdentity() async throws -> (email: String?, username: String?) {
        let req = APIRequest(method: .get, path: "/api/user/me")
        let me = try await dependencies.apiClient.send(req, decode: UserResponse.self)
        return (email: me.email, username: me.username)
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
        emit()
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

    // Decode current access token and extract email claim if present
    private func currentEmailFromAccessToken() -> String? {
        guard let jwt = snapshot.accessToken else { return nil }
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payloadPart = String(parts[1])
        func base64urlToData(_ s: String) -> Data? {
            var str = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let padding = (4 - (str.count % 4)) % 4
            if padding > 0 { str.append(String(repeating: "=", count: padding)) }
            return Data(base64Encoded: str)
        }
        guard let data = base64urlToData(payloadPart),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let email = json["email"] as? String { return email }
        if let emails = json["emails"] as? [String], let first = emails.first { return first }
        return nil
    }

    // Decode current access token and extract organization id claim
    fileprivate func currentActiveOrgIdFromAccessToken() -> String? {
        guard let jwt = snapshot.accessToken else {
            print("[EntityAuth][currentActiveOrgIdFromAccessToken] No access token in snapshot")
            return nil
        }
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else {
            print("[EntityAuth][currentActiveOrgIdFromAccessToken] Invalid JWT format (parts=\(parts.count))")
            return nil
        }
        let payloadPart = String(parts[1])
        func base64urlToData(_ s: String) -> Data? {
            var str = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let padding = (4 - (str.count % 4)) % 4
            if padding > 0 { str.append(String(repeating: "=", count: padding)) }
            return Data(base64Encoded: str)
        }
        guard let data = base64urlToData(payloadPart),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            print("[EntityAuth][currentActiveOrgIdFromAccessToken] Failed to decode JWT payload")
            return nil
        }
        
        // Log entire token payload for diagnosis
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[EntityAuth][currentActiveOrgIdFromAccessToken] Token payload: \(jsonString)")
        }
        
        if let oid = json["oid"] as? String {
            print("[EntityAuth][currentActiveOrgIdFromAccessToken] Found oid claim: \(oid)")
            return oid
        }
        if let oid = json["orgId"] as? String {
            print("[EntityAuth][currentActiveOrgIdFromAccessToken] Found orgId claim: \(oid)")
            return oid
        }
        print("[EntityAuth][currentActiveOrgIdFromAccessToken] WARNING: Token has NO oid/orgId claim! Available keys: \(json.keys.joined(separator: ", "))")
        return nil
    }
    private func initializeAsync() async {
        print("[EntityAuth][initializeAsync] BEGIN")
        await dependencies.refreshHandler.replaceRefreshService(with: dependencies.authService)
        setupRealtimeSubscriptions()
        // Prefill last-known userId immediately for seamless UI
        if snapshot.userId == nil, let last = lastUserStore.load() {
            print("[EntityAuth][initializeAsync] Prefilling userId from lastUserStore: \(last)")
            snapshot.userId = last
            emit()
        }
        // Eagerly hydrate userId on cold start if tokens are present
        if dependencies.authState.currentTokens.accessToken != nil || dependencies.authState.currentTokens.refreshToken != nil {
            print("[EntityAuth][initializeAsync] Tokens present - starting hydration sequence")
            do {
                try await coalesced {
                    do {
                        print("[EntityAuth][initializeAsync] Step 1: Check if token expiring soon...")
                        let access = dependencies.authState.currentTokens.accessToken
                        if let access, isAccessTokenExpiringSoon(access) {
                            print("[EntityAuth][initializeAsync] Token expiring soon - refreshing...")
                            let refreshed = try await dependencies.authService.refresh()
                            print("[EntityAuth][initializeAsync] Refresh succeeded, updating authState...")
                            do {
                                try dependencies.authState.update(accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken)
                                snapshot.accessToken = refreshed.accessToken
                                snapshot.refreshToken = refreshed.refreshToken ?? snapshot.refreshToken
                                print("[EntityAuth][initializeAsync] AuthState updated successfully - new oid=\(currentActiveOrgIdFromAccessToken() ?? "nil")")
                            } catch {
                                print("[EntityAuth][initializeAsync] CRITICAL ERROR: Failed to update authState after successful refresh: \(error)")
                                throw error // Propagate the error instead of silently continuing with stale tokens
                            }
                        } else {
                            print("[EntityAuth][initializeAsync] Token not expiring soon, using existing")
                        }
                        
                        print("[EntityAuth][initializeAsync] Step 2: Fetching userId from /api/user/me...")
                        let req = APIRequest(method: .get, path: "/api/user/me")
                        let me = try await dependencies.apiClient.send(req, decode: UserResponse.self)
                        snapshot.userId = me.id
                        snapshot.username = me.username
                        snapshot.email = me.email
                        snapshot.imageUrl = me.imageUrl
                        print("[EntityAuth][initializeAsync] Step 2: Got userId=\(me.id) email=\(me.email ?? "nil")")
                    } catch {
                        print("[EntityAuth][initializeAsync] Step 2 ERROR: \(error)")
                        print("[EntityAuth][initializeAsync] Error type: \(type(of: error))")
                        
                        // If 404, user was deleted - clear all auth state and bail out
                        if case let EntityAuthError.network(status, _) = error, status == 404 {
                            print("[EntityAuth][initializeAsync] User not found (404) - user may have been deleted. Clearing tokens.")
                            try? authState.clear()
                            snapshot = Snapshot(accessToken: nil, refreshToken: nil, sessionId: nil, userId: nil, username: nil, email: nil, imageUrl: nil, organizations: [], activeOrganization: nil)
                            emit()
                            await dependencies.realtime.stop()
                            lastUserStore.clear()
                            print("[EntityAuth][initializeAsync] Auth cleared due to deleted user")
                            return // Exit early - don't continue hydration
                        }
                        
                        // If failure indicates expired/invalid access token, attempt one refresh then retry hydration
                        if shouldAttemptRefresh(after: error) {
                            print("[EntityAuth][initializeAsync] Attempting token refresh due to error...")
                            do {
                                let refreshed = try await dependencies.authService.refresh()
                                print("[EntityAuth][initializeAsync] Retry refresh succeeded, updating authState...")
                                try dependencies.authState.update(accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken)
                                snapshot.accessToken = refreshed.accessToken
                                snapshot.refreshToken = refreshed.refreshToken ?? snapshot.refreshToken
                                print("[EntityAuth][initializeAsync] Retry authState updated - new oid=\(currentActiveOrgIdFromAccessToken() ?? "nil")")
                                let req = APIRequest(method: .get, path: "/api/user/me")
                                let me = try await dependencies.apiClient.send(req, decode: UserResponse.self)
                                snapshot.userId = me.id
                                snapshot.username = me.username
                                snapshot.email = me.email
                                snapshot.imageUrl = me.imageUrl
                                print("[EntityAuth][initializeAsync] Retry successful: userId=\(me.id)")
                            } catch {
                                print("[EntityAuth][initializeAsync] Retry FAILED: \(error) - Error type: \(type(of: error))")
                            }
                        }
                    }
                    
                    // Ensure org is ready before first emission on cold start
                    print("[EntityAuth][initializeAsync] Step 3: Calling refreshUserData()...")
                    do {
                        try await refreshUserData()
                        print("[EntityAuth][initializeAsync] Step 3: refreshUserData() SUCCESS")
                    } catch {
                        print("[EntityAuth][initializeAsync] Step 3 ERROR: refreshUserData() FAILED: \(error)")
                        print("[EntityAuth][initializeAsync] Error type: \(type(of: error))")
                        if let nsError = error as NSError? {
                            print("[EntityAuth][initializeAsync] NSError domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)")
                        }
                        // Don't throw - we'll continue but org state might be incomplete
                    }
                    
                    print("[EntityAuth][initializeAsync] Step 4: Calling ensureOrganizationAndActivateIfMissing()...")
                    do {
                        try await ensureOrganizationAndActivateIfMissing()
                        print("[EntityAuth][initializeAsync] Step 4: ensureOrganizationAndActivateIfMissing() completed")
                    } catch {
                        print("[EntityAuth][initializeAsync] Step 4 ERROR: ensureOrganizationAndActivateIfMissing() FAILED: \(error)")
                    }
                    
                    print("[EntityAuth][initializeAsync] Step 5: Calling refreshUserData() again...")
                    do {
                        try await refreshUserData()
                        print("[EntityAuth][initializeAsync] Step 5: refreshUserData() SUCCESS")
                    } catch {
                        print("[EntityAuth][initializeAsync] Step 5 ERROR: refreshUserData() FAILED: \(error)")
                    }
                    
                    // Backfill email from token if /me returned none
                    if (snapshot.email == nil || snapshot.email?.isEmpty == true), let claimEmail = currentEmailFromAccessToken() {
                        print("[EntityAuth][initializeAsync] Step 6: Backfilling email from token: \(claimEmail)")
                        do {
                            try await setEmail(claimEmail)
                        } catch {
                            print("[EntityAuth][initializeAsync] Step 6 ERROR: setEmail() FAILED: \(error)")
                        }
                    }
                    
                    // If still no active org but memberships exist, select the first one
                    print("[EntityAuth][initializeAsync] Step 7: Checking if need to switch to first org...")
                    print("[EntityAuth][initializeAsync] Step 7: activeOrganization=\(snapshot.activeOrganization?.orgId ?? "nil") organizations.count=\(snapshot.organizations.count)")
                    if snapshot.activeOrganization == nil, let firstOrg = snapshot.organizations.first?.orgId {
                        print("[EntityAuth][initializeAsync] Step 7: Switching to first org: \(firstOrg)")
                        do {
                            let newToken = try await dependencies.organizationService.switchOrg(orgId: firstOrg)
                            print("[EntityAuth][initializeAsync] Step 7: Got new token, updating authState...")
                            try dependencies.authState.update(accessToken: newToken)
                            snapshot.accessToken = newToken
                            print("[EntityAuth][initializeAsync] Step 7: AuthState updated - new oid=\(currentActiveOrgIdFromAccessToken() ?? "nil")")
                            try await refreshUserData()
                            print("[EntityAuth][initializeAsync] Step 7: refreshUserData() after switch SUCCESS")
                        } catch {
                            print("[EntityAuth][initializeAsync] Step 7 ERROR: switchOrg/refreshUserData FAILED: \(error) - Error type: \(type(of: error))")
                        }
                    }
                    
                    print("[EntityAuth][initializeAsync] Step 8: Final state - userId=\(snapshot.userId ?? "nil") activeOrg=\(snapshot.activeOrganization?.orgId ?? "nil") orgs.count=\(snapshot.organizations.count)")
                    print("[EntityAuth][initializeAsync] Emitting final snapshot...")
                    emit()
                }
            } catch {
                print("[EntityAuth][initializeAsync] FATAL ERROR in coalesced block: \(error)")
                print("[EntityAuth][initializeAsync] Error type: \(type(of: error))")
            }
        } else {
            print("[EntityAuth][initializeAsync] No tokens present - skipping hydration")
        }
        print("[EntityAuth][initializeAsync] END")
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
