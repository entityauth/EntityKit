import XCTest
@testable import EntityAuthDomain
@testable import EntityAuthUI

final class PeopleStoreTests: XCTestCase {
    var mockService: MockPeopleService!
    var store: PeopleStore!
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    @MainActor
    private func setupStore() {
        mockService = MockPeopleService()
        store = PeopleStore(peopleService: mockService, userId: "user_123")
    }
    
    // MARK: - Search Debounce Tests
    
    @MainActor
    func testSearchDebounce() async {
        setupStore()
        let expectation = XCTestExpectation(description: "Search debounced")
        expectation.expectedFulfillmentCount = 1
        
        mockService.searchHandler = { query in
            XCTAssertEqual(query, "test")
            expectation.fulfill()
            return []
        }
        
        // Rapid updates should only trigger one search
        store.updateSearchQuery("t")
        store.updateSearchQuery("te")
        store.updateSearchQuery("tes")
        store.updateSearchQuery("test")
        
        // Wait for debounce delay (250ms) + small buffer
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertEqual(mockService.searchCallCount, 1)
    }
    
    @MainActor
    func testSearchCancellation() async {
        setupStore()
        var firstSearchCalled = false
        var secondSearchCalled = false
        
        mockService.searchHandler = { query in
            if query == "test" {
                firstSearchCalled = true
            } else if query == "new" {
                secondSearchCalled = true
            }
            return []
        }
        
        store.updateSearchQuery("test")
        
        // Cancel before debounce completes
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        store.updateSearchQuery("new")
        
        // Wait for second search to complete
        try? await Task.sleep(nanoseconds: 300_000_000) // Wait for debounce
        
        // First search should be cancelled, second should execute
        XCTAssertFalse(firstSearchCalled, "First search should be cancelled")
        XCTAssertTrue(secondSearchCalled, "Second search should execute")
        XCTAssertEqual(mockService.searchCallCount, 1, "Only one search should execute")
    }
    
    @MainActor
    func testEmptyQueryClearsResults() {
        setupStore()
        mockService.searchHandler = { _ in
            XCTFail("Should not search with empty query")
            return []
        }
        
        store.updateSearchQuery("test")
        store.updateSearchQuery("")
        
        XCTAssertTrue(store.searchResults.isEmpty)
        XCTAssertFalse(store.isSearching)
    }
    
    @MainActor
    func testSingleCharacterRequiresAtSymbol() {
        setupStore()
        mockService.searchHandler = { _ in
            XCTFail("Should not search single char without @")
            return []
        }
        
        store.updateSearchQuery("a")
        
        XCTAssertTrue(store.searchResults.isEmpty)
        XCTAssertFalse(store.isSearching)
        
        // With @ should work
        mockService.searchHandler = { query in
            XCTAssertEqual(query, "a@")
            return []
        }
        
        store.updateSearchQuery("a@")
    }
    
    @MainActor
    func testPerformSearchImmediately() async {
        setupStore()
        let expectation = XCTestExpectation(description: "Search performed immediately")
        
        mockService.searchHandler = { query in
            XCTAssertEqual(query, "immediate")
            expectation.fulfill()
            return []
        }
        
        store.updateSearchQuery("immediate")
        store.performSearchImmediately()
        
        await fulfillment(of: [expectation], timeout: 0.3)
    }
    
    // MARK: - Error Translation Tests
    
    @MainActor
    func testSearchErrorTranslation() async {
        setupStore()
        mockService.searchHandler = { _ in
            throw PeopleError.search(.queryTooShort)
        }
        
        store.updateSearchQuery("test")
        
        // Wait for search to complete
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        XCTAssertNotNil(store.searchError)
        if case .search(.queryTooShort) = store.searchError {
            // Correct error type
        } else {
            XCTFail("Expected search error")
        }
    }
    
    @MainActor
    func testNetworkErrorTranslation() async {
        setupStore()
        struct TestError: Error {
            let localizedDescription = "Network failure"
        }
        
        mockService.searchHandler = { _ in
            throw TestError()
        }
        
        store.updateSearchQuery("test")
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        XCTAssertNotNil(store.searchError)
        if case .networkError(let message) = store.searchError {
            XCTAssertTrue(message.contains("Network failure") || message.contains("TestError"))
        } else {
            XCTFail("Expected network error, got: \(String(describing: store.searchError))")
        }
    }
    
    @MainActor
    func testInvitationErrorTranslation() async {
        setupStore()
        mockService.invitationError = PeopleError.invitation(.duplicate)
        
        // startInvitation throws but doesn't set invitationsError directly
        // The error is caught and stored when loadSentInvitations is called
        do {
            try await store.startInvitation(orgId: "org_1", inviteeUserId: "user_2", role: "member")
            XCTFail("Should have thrown error")
        } catch {
            // Error is thrown, which is expected
            XCTAssertTrue(error is PeopleError)
        }
    }
    
    @MainActor
    func testFriendErrorTranslation() async {
        setupStore()
        mockService.friendError = PeopleError.friend(.duplicate)
        
        // startFriendRequest throws but doesn't set friendsError directly
        // The error is caught and stored when loadSentFriendRequests is called
        do {
            try await store.startFriendRequest(targetUserId: "user_2")
            XCTFail("Should have thrown error")
        } catch {
            // Error is thrown, which is expected
            XCTAssertTrue(error is PeopleError)
        }
    }
    
    // MARK: - Loading State Tests
    
    @MainActor
    func testSearchLoadingState() async {
        setupStore()
        let expectation = XCTestExpectation(description: "Search loading state")
        
        mockService.searchHandler = { _ in
            XCTAssertTrue(self.store.isSearching)
            expectation.fulfill()
            return []
        }
        
        store.updateSearchQuery("test")
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertFalse(store.isSearching)
    }
    
    @MainActor
    func testInvitationsLoadingState() async {
        setupStore()
        mockService.invitationsResponse = InvitationListResponse(
            items: [],
            hasMore: false,
            nextCursor: nil as String?
        )
        
        await store.loadInvitations()
        
        XCTAssertFalse(store.invitationsLoading)
    }
    
    @MainActor
    func testFriendsLoadingState() async {
        setupStore()
        mockService.friendRequestsResponse = FriendRequestListResponse(
            items: [],
            hasMore: false,
            nextCursor: nil as String?
        )
        
        await store.loadFriendRequests()
        
        XCTAssertFalse(store.friendsLoading)
    }
    
    // MARK: - Unread Count Tests
    
    @MainActor
    func testUnreadInvitationsCount() async {
        setupStore()
        let pendingInvitation = Invitation(
            id: "inv_1",
            orgId: "org_1",
            inviteeUserId: "user_123",
            role: "member",
            status: "pending",
            expiresAt: Date().timeIntervalSince1970 * 1000 + 86400,
            createdAt: Date().timeIntervalSince1970 * 1000,
            respondedAt: nil,
            createdBy: "user_456"
        )
        
        let acceptedInvitation = Invitation(
            id: "inv_2",
            orgId: "org_1",
            inviteeUserId: "user_123",
            role: "member",
            status: "accepted",
            expiresAt: Date().timeIntervalSince1970 * 1000 + 86400,
            createdAt: Date().timeIntervalSince1970 * 1000,
            respondedAt: Date().timeIntervalSince1970 * 1000,
            createdBy: "user_456"
        )
        
        mockService.invitationsResponse = InvitationListResponse(
            items: [pendingInvitation, acceptedInvitation],
            hasMore: false,
            nextCursor: nil as String?
        )
        
        await store.loadInvitations()
        
        XCTAssertEqual(store.unreadInvitationsCount, 1)
    }
    
    @MainActor
    func testUnreadFriendRequestsCount() async {
        setupStore()
        let pendingRequest = FriendRequest(
            id: "req_1",
            requesterId: "user_456",
            targetUserId: "user_123",
            status: "pending",
            createdAt: Date().timeIntervalSince1970 * 1000,
            respondedAt: nil
        )
        
        let acceptedRequest = FriendRequest(
            id: "req_2",
            requesterId: "user_789",
            targetUserId: "user_123",
            status: "accepted",
            createdAt: Date().timeIntervalSince1970 * 1000,
            respondedAt: Date().timeIntervalSince1970 * 1000
        )
        
        mockService.friendRequestsResponse = FriendRequestListResponse(
            items: [pendingRequest, acceptedRequest],
            hasMore: false,
            nextCursor: nil as String?
        )
        
        await store.loadFriendRequests()
        
        XCTAssertEqual(store.unreadFriendRequestsCount, 1)
    }
    
    @MainActor
    func testTotalUnreadCount() async {
        setupStore()
        let pendingInvitation = Invitation(
            id: "inv_1",
            orgId: "org_1",
            inviteeUserId: "user_123",
            role: "member",
            status: "pending",
            expiresAt: Date().timeIntervalSince1970 * 1000 + 86400,
            createdAt: Date().timeIntervalSince1970 * 1000,
            respondedAt: nil,
            createdBy: "user_456"
        )
        
        let pendingRequest = FriendRequest(
            id: "req_1",
            requesterId: "user_456",
            targetUserId: "user_123",
            status: "pending",
            createdAt: Date().timeIntervalSince1970 * 1000,
            respondedAt: nil
        )
        
        mockService.invitationsResponse = InvitationListResponse(
            items: [pendingInvitation],
            hasMore: false,
            nextCursor: nil as String?
        )
        
        mockService.friendRequestsResponse = FriendRequestListResponse(
            items: [pendingRequest],
            hasMore: false,
            nextCursor: nil as String?
        )
        
        await store.refreshAll()
        
        XCTAssertEqual(store.totalUnreadCount, 2)
    }
}

// MARK: - Mock PeopleService

@MainActor
final class MockPeopleService: PeopleServiceProtocol {
    var searchHandler: ((String) async throws -> [PersonSummary])?
    var searchCallCount = 0
    var invitationsResponse: InvitationListResponse?
    var friendRequestsResponse: FriendRequestListResponse?
    var connectionsResponse: [FriendConnection] = []
    var invitationError: Error?
    var friendError: Error?
    
    func searchUsers(q: String, limit: Int?) async throws -> [PersonSummary] {
        searchCallCount += 1
        if let handler = searchHandler {
            return try await handler(q)
        }
        return []
    }
    
    func startInvitation(orgId: String, inviteeUserId: String, role: String) async throws -> InvitationStartResponse {
        if let error = invitationError {
            throw error
        }
        return InvitationStartResponse(id: "inv_1", token: "token_1", expiresAt: Date().timeIntervalSince1970 * 1000 + 86400)
    }
    
    func acceptInvitation(token: String) async throws {
        if let error = invitationError {
            throw error
        }
    }
    
    func acceptInvitationById(invitationId: String) async throws {
        if let error = invitationError {
            throw error
        }
    }
    
    func declineInvitation(invitationId: String) async throws {
        if let error = invitationError {
            throw error
        }
    }
    
    func revokeInvitation(invitationId: String) async throws {
        if let error = invitationError {
            throw error
        }
    }
    
    func resendInvitation(invitationId: String) async throws -> InvitationStartResponse {
        if let error = invitationError {
            throw error
        }
        return InvitationStartResponse(id: invitationId, token: "new_token", expiresAt: Date().timeIntervalSince1970 * 1000 + 86400)
    }
    
    func listSentInvitations(inviterId: String, cursor: String?, limit: Int) async throws -> InvitationListResponse {
        if let error = invitationError {
            throw error
        }
        return invitationsResponse ?? InvitationListResponse(items: [], hasMore: false, nextCursor: nil)
    }
    
    func listReceivedInvitations(userId: String, cursor: String?, limit: Int) async throws -> InvitationListResponse {
        if let error = invitationError {
            throw error
        }
        return invitationsResponse ?? InvitationListResponse(items: [], hasMore: false, nextCursor: nil)
    }
    
    func startFriendRequest(targetUserId: String) async throws {
        if let error = friendError {
            throw error
        }
    }
    
    func acceptFriendRequest(requestId: String) async throws {
        if let error = friendError {
            throw error
        }
    }
    
    func declineFriendRequest(requestId: String) async throws {
        if let error = friendError {
            throw error
        }
    }
    
    func cancelFriendRequest(requestId: String) async throws {
        if let error = friendError {
            throw error
        }
    }
    
    func listSentFriendRequests(requesterId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse {
        if let error = friendError {
            throw error
        }
        return friendRequestsResponse ?? FriendRequestListResponse(items: [], hasMore: false, nextCursor: nil)
    }
    
    func listReceivedFriendRequests(targetUserId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse {
        if let error = friendError {
            throw error
        }
        return friendRequestsResponse ?? FriendRequestListResponse(items: [], hasMore: false, nextCursor: nil)
    }
    
    func listFriendConnections() async throws -> [FriendConnection] {
        return connectionsResponse
    }
    
    func removeFriendConnection(friendId: String) async throws {
        if let error = friendError {
            throw error
        }
    }
}

