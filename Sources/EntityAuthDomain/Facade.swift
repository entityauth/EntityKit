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
        let response = try await dependencies.authService.refresh()
        try authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
        snapshot.accessToken = response.accessToken
        snapshot.refreshToken = response.refreshToken
        emit()
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
                let newToken = try? await dependencies.organizationService.switchOrg(orgId: firstOrg)
                if let newToken { try? dependencies.authState.update(accessToken: newToken); snapshot.accessToken = newToken; try? await refreshUserData() }
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
        print("[EntityAuth][refreshUserData] begin")
        let organizations = try await dependencies.organizationService.list().map { $0.asDomain }
        snapshot.organizations = organizations
        // Derive active org from token `oid` claim
        let tokenOid = currentActiveOrgIdFromAccessToken()
        if let oid = tokenOid, let matched = organizations.first(where: { $0.orgId == oid }) {
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
            snapshot.activeOrganization = nil
        }
        // Also hydrate identity (email, username, image) to ensure snapshot is complete post-SSO/login
        do {
            let req = APIRequest(method: .get, path: "/api/user/me")
            let me = try await dependencies.apiClient.send(req, decode: UserResponse.self)
            snapshot.userId = me.id
            snapshot.username = me.username
            snapshot.email = me.email
            snapshot.imageUrl = me.imageUrl
        } catch {
            // Non-fatal; keep prior identity fields if request fails
        }
        print("[EntityAuth][refreshUserData] end orgs=\(organizations.count) active=\(snapshot.activeOrganization?.orgId ?? "nil") (from token oid=\(tokenOid ?? "nil"))")
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
        if let oid = json["oid"] as? String { return oid }
        if let oid = json["orgId"] as? String { return oid }
        return nil
    }
    private func initializeAsync() async {
        await dependencies.refreshHandler.replaceRefreshService(with: dependencies.authService)
        setupRealtimeSubscriptions()
        // Prefill last-known userId immediately for seamless UI
        if snapshot.userId == nil, let last = lastUserStore.load() {
            snapshot.userId = last
            emit()
        }
        // Eagerly hydrate userId on cold start if tokens are present
        if dependencies.authState.currentTokens.accessToken != nil || dependencies.authState.currentTokens.refreshToken != nil {
            try? await coalesced {
                do {
                    let access = dependencies.authState.currentTokens.accessToken
                    if let access, isAccessTokenExpiringSoon(access) {
                        let refreshed = try await dependencies.authService.refresh()
                        try? dependencies.authState.update(accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken)
                        snapshot.accessToken = refreshed.accessToken
                        snapshot.refreshToken = refreshed.refreshToken ?? snapshot.refreshToken
                    }
                    let req = APIRequest(method: .get, path: "/api/user/me")
                    let me = try await dependencies.apiClient.send(req, decode: UserResponse.self)
                    snapshot.userId = me.id
                    snapshot.username = me.username
                    snapshot.email = me.email
                    snapshot.imageUrl = me.imageUrl
                } catch {
                    _ = (error as? EntityAuthError)?.errorDescription ?? error.localizedDescription
                    // If failure indicates expired/invalid access token, attempt one refresh then retry hydration
                    if shouldAttemptRefresh(after: error) {
                        do {
                            let refreshed = try await dependencies.authService.refresh()
                            try? dependencies.authState.update(accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken)
                            snapshot.accessToken = refreshed.accessToken
                            snapshot.refreshToken = refreshed.refreshToken ?? snapshot.refreshToken
                            let req = APIRequest(method: .get, path: "/api/user/me")
                            let me = try await dependencies.apiClient.send(req, decode: UserResponse.self)
                            snapshot.userId = me.id
                            snapshot.username = me.username
                            snapshot.email = me.email
                            snapshot.imageUrl = me.imageUrl
                        } catch {
                            _ = (error as? EntityAuthError)?.errorDescription ?? error.localizedDescription
                        }
                    }
                }
                // Ensure org is ready before first emission on cold start
                try? await refreshUserData()
                try? await ensureOrganizationAndActivateIfMissing()
                try? await refreshUserData()
                // Backfill email from token if /me returned none
                if (snapshot.email == nil || snapshot.email?.isEmpty == true), let claimEmail = currentEmailFromAccessToken() {
                    try? await setEmail(claimEmail)
                }
                // If still no active org but memberships exist, select the first one
                if snapshot.activeOrganization == nil, let firstOrg = snapshot.organizations.first?.orgId {
                    if let newToken = try? await dependencies.organizationService.switchOrg(orgId: firstOrg) {
                        try? dependencies.authState.update(accessToken: newToken)
                        snapshot.accessToken = newToken
                        try? await refreshUserData()
                    }
                }
                emit()
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
