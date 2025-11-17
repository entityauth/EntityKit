import Foundation
import SwiftUI
import EntityAuthDomain

/// Unified store for People experience (invites, friends, search)
/// Manages state, cancellation, and deduplication for all people-related operations
@MainActor
public final class PeopleStore: ObservableObject {
    // MARK: - Published State
    
    @Published public private(set) var searchQuery: String = ""
    @Published public private(set) var searchResults: [PersonSummary] = []
    @Published public private(set) var isSearching: Bool = false
    @Published public private(set) var searchError: PeopleError?
    
    @Published public private(set) var sentInvitations: [Invitation] = []
    @Published public private(set) var receivedInvitations: [Invitation] = []
    @Published public private(set) var invitationsLoading: Bool = false
    @Published public private(set) var invitationsError: PeopleError?
    @Published public private(set) var invitationsSentCursor: String?
    @Published public private(set) var invitationsReceivedCursor: String?
    @Published public private(set) var invitationsSentHasMore: Bool = false
    @Published public private(set) var invitationsReceivedHasMore: Bool = false
    
    @Published public private(set) var sentFriendRequests: [FriendRequest] = []
    @Published public private(set) var receivedFriendRequests: [FriendRequest] = []
    @Published public private(set) var friendsLoading: Bool = false
    @Published public private(set) var friendsError: PeopleError?
    @Published public private(set) var friendsSentCursor: String?
    @Published public private(set) var friendsReceivedCursor: String?
    @Published public private(set) var friendsSentHasMore: Bool = false
    @Published public private(set) var friendsReceivedHasMore: Bool = false
    
    @Published public private(set) var friendConnections: [FriendConnection] = []
    @Published public private(set) var connectionsLoading: Bool = false
    @Published public private(set) var connectionsError: PeopleError?
    
    // MARK: - Private State
    
    private let peopleService: PeopleServiceProtocol
    private let userId: String
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private let debounceDelay: TimeInterval = 0.25
    
    // MARK: - Initialization
    
    public init(
        peopleService: PeopleServiceProtocol,
        userId: String
    ) {
        self.peopleService = peopleService
        self.userId = userId
    }
    
    deinit {
        searchTask?.cancel()
        debounceTask?.cancel()
    }
    
    // MARK: - Search
    
    /// Update search query with debouncing
    public func updateSearchQuery(_ query: String) {
        searchQuery = query
        searchError = nil
        
        // Cancel previous debounce task
        debounceTask?.cancel()
        
        // Cancel in-flight search
        searchTask?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty query clears results immediately
        if trimmed.isEmpty {
            searchResults = []
            isSearching = false
            return
        }
        
        // Single character without @ requires 2 chars
        if trimmed.count == 1 && !trimmed.contains("@") {
            searchResults = []
            isSearching = false
            return
        }
        
        // Debounce search
        debounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.debounceDelay * 1_000_000_000))
            if !Task.isCancelled {
                await self.performSearch(query: trimmed)
            }
        }
    }
    
    /// Perform search immediately (e.g., on Enter key)
    public func performSearchImmediately() {
        debounceTask?.cancel()
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            Task {
                await performSearch(query: trimmed)
            }
        }
    }
    
    private func performSearch(query: String) async {
        // Cancel previous search
        searchTask?.cancel()
        
        isSearching = true
        searchError = nil
        
        // Log search start
        print("[PeopleStore] 🔍 Starting search with query: '\(query)'")
        
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                print("[PeopleStore] 🔍 Calling peopleService.searchUsers(q: '\(query)', limit: 10)")
                let results = try await self.peopleService.searchUsers(q: query, limit: 10)
                print("[PeopleStore] ✅ Search completed successfully. Results count: \(results.count)")
                if results.count > 0 {
                    print("[PeopleStore] 📋 Results:")
                    for (index, result) in results.enumerated() {
                        print("[PeopleStore]   [\(index + 1)] id: \(result.id), username: \(result.username ?? "nil"), email: \(result.email ?? "nil")")
                    }
                } else {
                    print("[PeopleStore] ⚠️ No results found for query: '\(query)'")
                }
                
                if !Task.isCancelled {
                    await MainActor.run {
                        self.searchResults = results
                        self.isSearching = false
                        print("[PeopleStore] ✅ Updated UI with \(results.count) results")
                    }
                } else {
                    print("[PeopleStore] ⚠️ Search was cancelled, ignoring results")
                }
            } catch {
                print("[PeopleStore] ❌ Search failed with error: \(error)")
                print("[PeopleStore] ❌ Error type: \(type(of: error))")
                print("[PeopleStore] ❌ Error description: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("[PeopleStore] ❌ NSError domain: \(nsError.domain), code: \(nsError.code)")
                    print("[PeopleStore] ❌ NSError userInfo: \(nsError.userInfo)")
                }
                
                if !Task.isCancelled {
                    await MainActor.run {
                        if let peopleError = error as? PeopleError {
                            self.searchError = peopleError
                        } else {
                            self.searchError = .networkError(error.localizedDescription)
                        }
                        self.isSearching = false
                        print("[PeopleStore] ✅ Updated UI with error state")
                    }
                } else {
                    print("[PeopleStore] ⚠️ Search was cancelled, ignoring error")
                }
            }
        }
        
        await searchTask?.value
    }
    
    // MARK: - Invitations
    
    /// Load all invitations (sent and received)
    public func loadInvitations() async {
        invitationsLoading = true
        invitationsError = nil
        
        async let sentTask = loadSentInvitations()
        async let receivedTask = loadReceivedInvitations()
        
        _ = await (sentTask, receivedTask)
        
        await MainActor.run {
            invitationsLoading = false
        }
    }
    
    private func loadSentInvitations() async {
        do {
            let response = try await peopleService.listSentInvitations(
                inviterId: userId,
                cursor: nil,
                limit: 20
            )
            await MainActor.run {
                self.sentInvitations = response.items
                self.invitationsSentCursor = response.nextCursor
                self.invitationsSentHasMore = response.hasMore
            }
        } catch {
            await MainActor.run {
                if let peopleError = error as? PeopleError {
                    self.invitationsError = peopleError
                } else {
                    self.invitationsError = .networkError(error.localizedDescription)
                }
            }
        }
    }
    
    private func loadReceivedInvitations() async {
        do {
            let response = try await peopleService.listReceivedInvitations(
                userId: userId,
                cursor: nil,
                limit: 20
            )
            await MainActor.run {
                self.receivedInvitations = response.items
                self.invitationsReceivedCursor = response.nextCursor
                self.invitationsReceivedHasMore = response.hasMore
            }
        } catch {
            await MainActor.run {
                if let peopleError = error as? PeopleError {
                    self.invitationsError = peopleError
                } else {
                    self.invitationsError = .networkError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Load more sent invitations
    public func loadMoreSentInvitations() async {
        guard let cursor = invitationsSentCursor, invitationsSentHasMore else { return }
        
        do {
            let response = try await peopleService.listSentInvitations(
                inviterId: userId,
                cursor: cursor,
                limit: 20
            )
            await MainActor.run {
                self.sentInvitations.append(contentsOf: response.items)
                self.invitationsSentCursor = response.nextCursor
                self.invitationsSentHasMore = response.hasMore
            }
        } catch {
            await MainActor.run {
                if let peopleError = error as? PeopleError {
                    self.invitationsError = peopleError
                } else {
                    self.invitationsError = .networkError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Load more received invitations
    public func loadMoreReceivedInvitations() async {
        guard let cursor = invitationsReceivedCursor, invitationsReceivedHasMore else { return }
        
        do {
            let response = try await peopleService.listReceivedInvitations(
                userId: userId,
                cursor: cursor,
                limit: 20
            )
            await MainActor.run {
                self.receivedInvitations.append(contentsOf: response.items)
                self.invitationsReceivedCursor = response.nextCursor
                self.invitationsReceivedHasMore = response.hasMore
            }
        } catch {
            await MainActor.run {
                if let peopleError = error as? PeopleError {
                    self.invitationsError = peopleError
                } else {
                    self.invitationsError = .networkError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Start an invitation
    public func startInvitation(orgId: String, inviteeUserId: String, role: String) async throws {
        _ = try await peopleService.startInvitation(
            orgId: orgId,
            inviteeUserId: inviteeUserId,
            role: role
        )
        // Reload sent invitations
        await loadSentInvitations()
    }
    
    /// Accept an invitation
    public func acceptInvitation(invitationId: String) async throws {
        try await peopleService.acceptInvitationById(invitationId: invitationId)
        // Reload received invitations
        await loadReceivedInvitations()
    }
    
    /// Decline an invitation
    public func declineInvitation(invitationId: String) async throws {
        try await peopleService.declineInvitation(invitationId: invitationId)
        // Reload received invitations
        await loadReceivedInvitations()
    }
    
    /// Revoke an invitation
    public func revokeInvitation(invitationId: String) async throws {
        try await peopleService.revokeInvitation(invitationId: invitationId)
        // Reload sent invitations
        await loadSentInvitations()
    }
    
    /// Resend an invitation
    public func resendInvitation(invitationId: String) async throws {
        _ = try await peopleService.resendInvitation(invitationId: invitationId)
        // Reload sent invitations
        await loadSentInvitations()
    }
    
    // MARK: - Friends
    
    /// Load all friend requests (sent and received)
    public func loadFriendRequests() async {
        friendsLoading = true
        friendsError = nil
        
        async let sentTask = loadSentFriendRequests()
        async let receivedTask = loadReceivedFriendRequests()
        
        _ = await (sentTask, receivedTask)
        
        await MainActor.run {
            friendsLoading = false
        }
    }
    
    private func loadSentFriendRequests() async {
        do {
            let response = try await peopleService.listSentFriendRequests(
                requesterId: userId,
                cursor: nil,
                limit: 20
            )
            await MainActor.run {
                self.sentFriendRequests = response.items
                self.friendsSentCursor = response.nextCursor
                self.friendsSentHasMore = response.hasMore
            }
        } catch {
            await MainActor.run {
                if let peopleError = error as? PeopleError {
                    self.friendsError = peopleError
                } else {
                    self.friendsError = .networkError(error.localizedDescription)
                }
            }
        }
    }
    
    private func loadReceivedFriendRequests() async {
        do {
            let response = try await peopleService.listReceivedFriendRequests(
                targetUserId: userId,
                cursor: nil,
                limit: 20
            )
            await MainActor.run {
                self.receivedFriendRequests = response.items
                self.friendsReceivedCursor = response.nextCursor
                self.friendsReceivedHasMore = response.hasMore
            }
        } catch {
            await MainActor.run {
                if let peopleError = error as? PeopleError {
                    self.friendsError = peopleError
                } else {
                    self.friendsError = .networkError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Load more sent friend requests
    public func loadMoreSentFriendRequests() async {
        guard let cursor = friendsSentCursor, friendsSentHasMore else { return }
        
        do {
            let response = try await peopleService.listSentFriendRequests(
                requesterId: userId,
                cursor: cursor,
                limit: 20
            )
            await MainActor.run {
                self.sentFriendRequests.append(contentsOf: response.items)
                self.friendsSentCursor = response.nextCursor
                self.friendsSentHasMore = response.hasMore
            }
        } catch {
            await MainActor.run {
                if let peopleError = error as? PeopleError {
                    self.friendsError = peopleError
                } else {
                    self.friendsError = .networkError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Load more received friend requests
    public func loadMoreReceivedFriendRequests() async {
        guard let cursor = friendsReceivedCursor, friendsReceivedHasMore else { return }
        
        do {
            let response = try await peopleService.listReceivedFriendRequests(
                targetUserId: userId,
                cursor: cursor,
                limit: 20
            )
            await MainActor.run {
                self.receivedFriendRequests.append(contentsOf: response.items)
                self.friendsReceivedCursor = response.nextCursor
                self.friendsReceivedHasMore = response.hasMore
            }
        } catch {
            await MainActor.run {
                if let peopleError = error as? PeopleError {
                    self.friendsError = peopleError
                } else {
                    self.friendsError = .networkError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Start a friend request
    public func startFriendRequest(targetUserId: String) async throws {
        do {
            try await peopleService.startFriendRequest(targetUserId: targetUserId)
        } catch {
            // Treat duplicate friend requests as a soft-success:
            // we still reload the sent list so UI can show "Request sent"
            if case PeopleError.friend(let friendError) = error,
               case .duplicate = friendError {
                // fall through to reload
            } else {
                throw error
            }
        }
        // Reload sent friend requests
        await loadSentFriendRequests()
    }
    
    /// Accept a friend request
    public func acceptFriendRequest(requestId: String) async throws {
        try await peopleService.acceptFriendRequest(requestId: requestId)
        // Reload received friend requests and connections
        async let reloadReceived = loadReceivedFriendRequests()
        async let reloadConnections = loadFriendConnections()
        _ = await (reloadReceived, reloadConnections)
    }
    
    /// Decline a friend request
    public func declineFriendRequest(requestId: String) async throws {
        try await peopleService.declineFriendRequest(requestId: requestId)
        // Reload received friend requests
        await loadReceivedFriendRequests()
    }
    
    /// Cancel a friend request
    public func cancelFriendRequest(requestId: String) async throws {
        try await peopleService.cancelFriendRequest(requestId: requestId)
        // Reload sent friend requests
        await loadSentFriendRequests()
    }
    
    // MARK: - Friend Connections
    
    /// Load friend connections (confirmed friendships)
    public func loadFriendConnections() async {
        connectionsLoading = true
        connectionsError = nil
        
        do {
            let connections = try await peopleService.listFriendConnections()
            await MainActor.run {
                self.friendConnections = connections
                self.connectionsLoading = false
            }
        } catch {
            await MainActor.run {
                if let peopleError = error as? PeopleError {
                    self.connectionsError = peopleError
                } else {
                    self.connectionsError = .networkError(error.localizedDescription)
                }
                self.connectionsLoading = false
            }
        }
    }
    
    /// Remove a friend connection
    public func removeFriendConnection(friendId: String) async throws {
        try await peopleService.removeFriendConnection(friendId: friendId)
        // Reload connections
        await loadFriendConnections()
    }
    
    // MARK: - Refresh All
    
    /// Refresh all data (invitations, friends, connections)
    public func refreshAll() async {
        async let invitationsTask = loadInvitations()
        async let friendsTask = loadFriendRequests()
        async let connectionsTask = loadFriendConnections()
        
        _ = await (invitationsTask, friendsTask, connectionsTask)
    }
    
    // MARK: - Computed Properties
    
    /// Unread count for received invitations
    public var unreadInvitationsCount: Int {
        receivedInvitations.filter { $0.status == "pending" }.count
    }
    
    /// Pending count for sent invitations
    public var pendingSentInvitationsCount: Int {
        sentInvitations.filter { $0.status == "pending" }.count
    }
    
    /// Unread count for received friend requests
    public var unreadFriendRequestsCount: Int {
        receivedFriendRequests.filter { $0.status == "pending" }.count
    }
    
    /// Pending count for sent friend requests
    public var pendingSentFriendRequestsCount: Int {
        sentFriendRequests.filter { $0.status == "pending" }.count
    }
    
    /// Total unread count (invitations + friend requests)
    public var totalUnreadCount: Int {
        unreadInvitationsCount + unreadFriendRequestsCount
    }

    /// Set of user IDs for whom there is a pending friend request
    /// (either sent by the current user or received from others).
    public var pendingFriendTargets: Set<String> {
        var ids = Set<String>()
        for req in sentFriendRequests where req.status == "pending" {
            ids.insert(req.targetUserId)
        }
        for req in receivedFriendRequests where req.status == "pending" {
            ids.insert(req.requesterId)
        }
        return ids
    }
}

