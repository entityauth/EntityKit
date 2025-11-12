import XCTest
import Combine
@testable import EntityAuthDomain
@testable import EntityAuthNetworking
@testable import EntityAuthCore
@testable import EntityAuthRealtime

final class FacadeFatalErrorTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    final class MockAuthService: AuthProviding, RefreshService, @unchecked Sendable {
        enum RefreshBehavior {
            case success(RefreshResponse)
            case failure(Error)
        }
        let refreshBehavior: RefreshBehavior
        private(set) var refreshCallCount = 0
        
        init(refreshBehavior: RefreshBehavior) {
            self.refreshBehavior = refreshBehavior
        }
        
        func refresh() async throws -> RefreshResponse {
            refreshCallCount += 1
            switch refreshBehavior {
            case .success(let response):
                return response
            case .failure(let error):
                throw error
            }
        }
        
        func register(request: RegisterRequest) async throws {}
        func login(request: LoginRequest) async throws -> LoginResponse {
            throw EntityAuthError.configurationMissingBaseURL
        }
        func logout(sessionId: String?, refreshToken: String?) async throws {}
        func beginRegistration(workspaceTenantId: String, userId: String, rpId: String, origins: [String]) async throws -> BeginRegistrationResponse {
            throw EntityAuthError.configurationMissingBaseURL
        }
        func beginRegistrationWithEmail(workspaceTenantId: String, email: String, rpId: String, origins: [String]) async throws -> BeginRegistrationResponse {
            throw EntityAuthError.configurationMissingBaseURL
        }
        func finishRegistration(workspaceTenantId: String, challengeId: String, userId: String, credential: WebAuthnRegistrationCredential) async throws -> FinishRegistrationResponse {
            throw EntityAuthError.configurationMissingBaseURL
        }
        func finishRegistrationWithEmail(workspaceTenantId: String, challengeId: String, email: String, credential: WebAuthnRegistrationCredential) async throws -> LoginResponse {
            throw EntityAuthError.configurationMissingBaseURL
        }
        func beginAuthentication(workspaceTenantId: String, userId: String?, rpId: String, origins: [String]) async throws -> BeginAuthenticationResponse {
            throw EntityAuthError.configurationMissingBaseURL
        }
        func finishAuthentication(workspaceTenantId: String, challengeId: String, credential: WebAuthnAuthenticationCredential, userId: String?) async throws -> LoginResponse {
            throw EntityAuthError.configurationMissingBaseURL
        }
    }
    
    final class MockOrganizationService: OrganizationsProviding, @unchecked Sendable {
        enum BootstrapBehavior {
            case success(BootstrapResponse)
            case failure(Error)
        }
        let bootstrapBehavior: BootstrapBehavior
        private(set) var bootstrapCallCount = 0
        
        init(bootstrapBehavior: BootstrapBehavior) {
            self.bootstrapBehavior = bootstrapBehavior
        }
        
        func bootstrap() async throws -> BootstrapResponse {
            bootstrapCallCount += 1
            switch bootstrapBehavior {
            case .success(let response):
                return response
            case .failure(let error):
                throw error
            }
        }
        
        func create(name: String, slug: String, ownerId: String) async throws {}
        func create(workspaceTenantId: String, name: String, slug: String, ownerId: String) async throws {}
        func addMember(orgId: String, userId: String, role: String) async throws {}
        func listMembers(orgId: String) async throws -> [OrgMemberDTO] { [] }
        func removeMember(orgId: String, userId: String) async throws {}
        func switchActive(orgId: String) async throws -> String { throw EntityAuthError.configurationMissingBaseURL }
        func switchOrg(orgId: String) async throws -> String { throw EntityAuthError.configurationMissingBaseURL }
        func switchActive(workspaceTenantId: String, orgId: String) async throws -> String { throw EntityAuthError.configurationMissingBaseURL }
        func listWorkspaceMembers(workspaceTenantId: String) async throws -> [WorkspaceMemberDTO] { [] }
        func list() async throws -> [OrganizationSummaryDTO] { [] }
        func list(userId: String?) async throws -> [OrganizationSummaryDTO] { [] }
        func active() async throws -> ActiveOrganizationDTO? { nil }
        func setActiveOrgName(_ name: String) async throws {}
        func setActiveOrgSlug(_ slug: String) async throws {}
        func setActiveOrgImageUrl(_ imageUrl: String) async throws {}
    }
    
    final class MockRealtime: RealtimeSubscriptionHandling, @unchecked Sendable {
        private(set) var stopCallCount = 0
        
        func start(userId: String, sessionId: String?) async {
            // no-op
        }
        
        func stop() async {
            stopCallCount += 1
        }
        
        func update(baseURL: URL) {
            // no-op
        }
        
        func publisher() -> AnyPublisher<RealtimeEvent, Never> {
            Empty().eraseToAnyPublisher()
        }
    }
    
    struct MockAPIClient: APIClientType {
        var currentConfig: EntityAuthConfig {
            EntityAuthConfig(environment: .custom(URL(string: "https://api.test")!), workspaceTenantId: "w1", clientIdentifier: "ios")
        }
        var workspaceTenantId: String? { "w1" }
        func updateConfiguration(_ update: (inout EntityAuthConfig) -> Void) {}
        func send(_ request: APIRequest) async throws -> Data { Data() }
        func send<T>(_ request: APIRequest, decode: T.Type) async throws -> T where T : Decodable {
            throw EntityAuthError.configurationMissingBaseURL
        }
    }
    
    final class MockEntitiesService: EntitiesProviding, @unchecked Sendable {
        func get(id: String) async throws -> EntityDTO? { nil }
        func list(workspaceTenantId: String, kind: String, filter: ListEntitiesFilter?, limit: Int?) async throws -> [EntityDTO] { [] }
        func upsert(workspaceTenantId: String, kind: String, properties: [String: Any], metadata: [String: Any]?) async throws -> EntityDTO {
            throw EntityAuthError.configurationMissingBaseURL
        }
        func createEnforced(workspaceTenantId: String, kind: String, properties: [String: Any], metadata: [String: Any]?, actorId: String) async throws -> EntityDTO {
            throw EntityAuthError.configurationMissingBaseURL
        }
        func updateEnforced(id: String, patch: [String: Any], actorId: String) async throws -> EntityDTO {
            throw EntityAuthError.configurationMissingBaseURL
        }
        func deleteEnforced(id: String, actorId: String) async throws {}
    }
    
    final class MockInvitationService: InvitationsProviding, @unchecked Sendable {
        func start(orgId: String, inviteeUserId: String, role: String) async throws -> InvitationStartResponse {
            InvitationStartResponse(id: "", token: "", expiresAt: 0)
        }
        func accept(token: String) async throws {}
        func acceptById(invitationId: String) async throws {}
        func decline(invitationId: String) async throws {}
        func revoke(invitationId: String) async throws {}
        func resend(invitationId: String) async throws -> InvitationStartResponse {
            InvitationStartResponse(id: "", token: "", expiresAt: 0)
        }
        func listSent(inviterId: String, cursor: String?, limit: Int = 20) async throws -> InvitationListResponse {
            InvitationListResponse(items: [], hasMore: false, nextCursor: nil)
        }
        func listReceived(userId: String, cursor: String?, limit: Int = 20) async throws -> InvitationListResponse {
            InvitationListResponse(items: [], hasMore: false, nextCursor: nil)
        }
        func searchUsers(q: String) async throws -> [(id: String, email: String?, username: String?)] { [] }
    }
    
    func makeDependencies(
        authService: MockAuthService,
        organizationService: MockOrganizationService,
        authState: AuthState,
        realtime: MockRealtime = MockRealtime()
    ) -> EntityAuthFacade.Dependencies {
        let config = EntityAuthConfig(environment: .custom(URL(string: "https://api.test")!), workspaceTenantId: "w1", clientIdentifier: "ios")
        let baseURLStore = UserDefaultsBaseURLStore(suiteName: nil)
        let refresher = TokenRefresher(authState: authState, refreshService: authService)
        let apiClient = MockAPIClient()
        let entitiesService = MockEntitiesService()
        let invitationService = MockInvitationService()
        
        return EntityAuthFacade.Dependencies(
            config: config,
            baseURLStore: baseURLStore,
            authState: authState,
            authService: authService,
            organizationService: organizationService,
            entitiesService: entitiesService,
            invitationService: invitationService,
            refreshHandler: refresher,
            apiClient: apiClient,
            realtime: realtime
        )
    }
    
    // MARK: - Tests
    
    func testInitializeAsyncClearsStateWhenRefreshFailsWithUnauthorized() async throws {
        // Setup: Facade with tokens
        // Flow: Step 1 skips refresh (token not expiring), Step 2 bootstrap fails with unauthorized,
        // retry refresh also fails with unauthorized, triggering state clear
        let tokenStore = InMemoryTokenStore()
        try tokenStore.save(accessToken: "old-token")
        try tokenStore.save(refreshToken: "old-refresh")
        let authState = AuthState(tokenStore: tokenStore)
        
        // Both bootstrap and refresh will fail with unauthorized
        let authService = MockAuthService(refreshBehavior: .failure(EntityAuthError.unauthorized))
        let orgService = MockOrganizationService(bootstrapBehavior: .failure(EntityAuthError.unauthorized))
        let realtime = MockRealtime()
        
        let deps = makeDependencies(authService: authService, organizationService: orgService, authState: authState, realtime: realtime)
        
        let initialSnapshot = EntityAuthFacade.Snapshot(
            accessToken: "old-token",
            refreshToken: "old-refresh",
            sessionId: nil,
            userId: nil,
            username: nil,
            email: nil,
            imageUrl: nil,
            organizations: [],
            activeOrganization: nil
        )
        
        let facade = EntityAuthFacade(dependencies: deps, state: initialSnapshot)
        
        // Wait for snapshot to be cleared (poll until cleared or timeout)
        let timeout = Date().addingTimeInterval(2.0)
        var snapshot = await facade.currentSnapshot()
        while (snapshot.accessToken != nil || snapshot.refreshToken != nil) && Date() < timeout {
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            snapshot = await facade.currentSnapshot()
        }
        
        // Verify: State should be cleared
        XCTAssertNil(snapshot.accessToken, "Access token should be cleared")
        XCTAssertNil(snapshot.refreshToken, "Refresh token should be cleared")
        XCTAssertNil(snapshot.userId, "User ID should be cleared")
        XCTAssertTrue(snapshot.organizations.isEmpty, "Organizations should be empty")
        
        // Verify: Realtime should be stopped
        XCTAssertGreaterThanOrEqual(realtime.stopCallCount, 1, "Realtime should be stopped at least once")
        
        // Verify: AuthState should be cleared
        let clearedTokens = await authState.currentTokens
        XCTAssertNil(clearedTokens.accessToken, "AuthState access token should be cleared")
        XCTAssertNil(clearedTokens.refreshToken, "AuthState refresh token should be cleared")
    }
    
    func testInitializeAsyncClearsStateWhenBootstrapReturns404() async throws {
        // Setup: Facade with tokens but bootstrap will return 404 (user deleted)
        // Note: Token won't be expiring soon (invalid JWT), so Step 1 skips refresh
        // Step 2 bootstrap returns 404, which should clear state
        let tokenStore = InMemoryTokenStore()
        try tokenStore.save(accessToken: "valid-token")
        try tokenStore.save(refreshToken: "valid-refresh")
        let authState = AuthState(tokenStore: tokenStore)
        
        // Refresh won't be called (token not expiring), so behavior doesn't matter
        let refreshResponse = RefreshResponse(accessToken: "new-token", refreshToken: "new-refresh")
        let authService = MockAuthService(refreshBehavior: .success(refreshResponse))
        // Bootstrap returns 404 - user deleted
        let orgService = MockOrganizationService(bootstrapBehavior: .failure(EntityAuthError.network(statusCode: 404, message: "Not found")))
        let realtime = MockRealtime()
        
        let deps = makeDependencies(authService: authService, organizationService: orgService, authState: authState, realtime: realtime)
        
        let initialSnapshot = EntityAuthFacade.Snapshot(
            accessToken: "valid-token",
            refreshToken: "valid-refresh",
            sessionId: nil,
            userId: nil,
            username: nil,
            email: nil,
            imageUrl: nil,
            organizations: [],
            activeOrganization: nil
        )
        
        let facade = EntityAuthFacade(dependencies: deps, state: initialSnapshot)
        
        // Wait for snapshot to be cleared (poll until cleared or timeout)
        let timeout = Date().addingTimeInterval(2.0)
        var snapshot = await facade.currentSnapshot()
        while (snapshot.accessToken != nil || snapshot.refreshToken != nil) && Date() < timeout {
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            snapshot = await facade.currentSnapshot()
        }
        
        // Verify: State should be cleared
        XCTAssertNil(snapshot.accessToken, "Access token should be cleared after 404")
        XCTAssertNil(snapshot.refreshToken, "Refresh token should be cleared after 404")
        XCTAssertNil(snapshot.userId, "User ID should be cleared after 404")
        
        // Verify: Realtime should be stopped
        XCTAssertGreaterThanOrEqual(realtime.stopCallCount, 1, "Realtime should be stopped at least once")
    }
    
    func testRefreshTokensClearsStateWhenRefreshFailsWithUnauthorized() async throws {
        // Setup: Facade with valid tokens, but refresh will fail
        let tokenStore = InMemoryTokenStore()
        try tokenStore.save(accessToken: "token")
        try tokenStore.save(refreshToken: "refresh")
        let authState = AuthState(tokenStore: tokenStore)
        
        let authService = MockAuthService(refreshBehavior: .failure(EntityAuthError.unauthorized))
        let orgService = MockOrganizationService(bootstrapBehavior: .failure(EntityAuthError.unauthorized))
        let realtime = MockRealtime()
        
        let deps = makeDependencies(authService: authService, organizationService: orgService, authState: authState, realtime: realtime)
        
        let initialSnapshot = EntityAuthFacade.Snapshot(
            accessToken: "token",
            refreshToken: "refresh",
            sessionId: "s1",
            userId: "u1",
            username: "test",
            email: "test@example.com",
            imageUrl: nil,
            organizations: [],
            activeOrganization: nil
        )
        
        let facade = await Task { @MainActor in
            EntityAuthFacade(dependencies: deps, state: initialSnapshot)
        }.value
        
        // Attempt to refresh tokens (should fail and clear state)
        do {
            try await facade.refreshTokens()
            XCTFail("refreshTokens should throw when refresh fails")
        } catch {
            // Expected to throw
        }
        
        // Wait a bit for state clearing to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify: State should be cleared
        let snapshot = await facade.currentSnapshot()
        XCTAssertNil(snapshot.accessToken, "Access token should be cleared after refresh failure")
        XCTAssertNil(snapshot.refreshToken, "Refresh token should be cleared after refresh failure")
        
        // Verify: Realtime should be stopped
        XCTAssertGreaterThanOrEqual(realtime.stopCallCount, 1, "Realtime should be stopped at least once")
    }
    
    func testOnAuthenticationInvalidatedCallbackInvoked() async throws {
        // Setup: Track callback invocations
        actor CallbackTracker {
            var reason: String?
            func set(_ r: String) { reason = r }
            func get() -> String? { reason }
        }
        let tracker = CallbackTracker()
        let expectation = expectation(description: "onAuthenticationInvalidated called")
        
        let tokenStore = InMemoryTokenStore()
        try tokenStore.save(accessToken: "token")
        try tokenStore.save(refreshToken: "refresh")
        let authState = AuthState(tokenStore: tokenStore)
        
        let authService = MockAuthService(refreshBehavior: .failure(EntityAuthError.unauthorized))
        let orgService = MockOrganizationService(bootstrapBehavior: .failure(EntityAuthError.unauthorized))
        let realtime = MockRealtime()
        
        let deps = makeDependencies(authService: authService, organizationService: orgService, authState: authState, realtime: realtime)
        
        let initialSnapshot = EntityAuthFacade.Snapshot(
            accessToken: "token",
            refreshToken: "refresh",
            sessionId: nil,
            userId: nil,
            username: nil,
            email: nil,
            imageUrl: nil,
            organizations: [],
            activeOrganization: nil
        )
        
        let facade = await Task { @MainActor in
            EntityAuthFacade(dependencies: deps, state: initialSnapshot)
        }.value
        
        // Set callback
        await facade.setOnAuthenticationInvalidated { reason in
            Task {
                await tracker.set(reason)
                expectation.fulfill()
            }
        }
        
        // Wait for initialization to complete
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Verify: Callback was invoked with reason
        let reason = await tracker.get()
        XCTAssertNotNil(reason, "onAuthenticationInvalidated should be called")
        XCTAssertTrue(reason?.contains("unauthorized") == true || reason?.contains("refresh failed") == true, "Reason should mention the error")
    }
    
    func testSnapshotEmitsExactlyOnceWhenStateCleared() async throws {
        // Setup: Track snapshot emissions using actor for thread safety
        actor SnapshotTracker {
            var emissions: [EntityAuthFacade.Snapshot] = []
            func append(_ snapshot: EntityAuthFacade.Snapshot) { emissions.append(snapshot) }
            func getClearedCount() -> Int { emissions.filter { $0.accessToken == nil && $0.refreshToken == nil }.count }
            func getLast() -> EntityAuthFacade.Snapshot? { emissions.last }
        }
        let tracker = SnapshotTracker()
        let expectation = expectation(description: "snapshot emitted")
        expectation.expectedFulfillmentCount = 1 // Should emit exactly once
        
        let tokenStore = InMemoryTokenStore()
        try tokenStore.save(accessToken: "token")
        try tokenStore.save(refreshToken: "refresh")
        let authState = AuthState(tokenStore: tokenStore)
        
        let authService = MockAuthService(refreshBehavior: .failure(EntityAuthError.unauthorized))
        let orgService = MockOrganizationService(bootstrapBehavior: .failure(EntityAuthError.unauthorized))
        let realtime = MockRealtime()
        
        let deps = makeDependencies(authService: authService, organizationService: orgService, authState: authState, realtime: realtime)
        
        let initialSnapshot = EntityAuthFacade.Snapshot(
            accessToken: "token",
            refreshToken: "refresh",
            sessionId: nil,
            userId: nil,
            username: nil,
            email: nil,
            imageUrl: nil,
            organizations: [],
            activeOrganization: nil
        )
        
        let facade = await Task { @MainActor in
            EntityAuthFacade(dependencies: deps, state: initialSnapshot)
        }.value
        
        // Subscribe to snapshot stream
        let task = Task { @Sendable in
            let stream = await facade.snapshotStream()
            for await snapshot in stream {
                await tracker.append(snapshot)
                if snapshot.accessToken == nil && snapshot.refreshToken == nil {
                    expectation.fulfill()
                }
            }
        }
        
        // Wait for cleared snapshot to be emitted
        await fulfillment(of: [expectation], timeout: 1.0)
        task.cancel()
        
        // Verify: Should have at least one emission with cleared state
        let clearedCount = await tracker.getClearedCount()
        XCTAssertGreaterThanOrEqual(clearedCount, 1, "Should emit at least one cleared snapshot")
        
        // Verify: Last emission should be cleared
        if let last = await tracker.getLast() {
            XCTAssertNil(last.accessToken, "Last snapshot should have nil access token")
            XCTAssertNil(last.refreshToken, "Last snapshot should have nil refresh token")
        }
    }
}

