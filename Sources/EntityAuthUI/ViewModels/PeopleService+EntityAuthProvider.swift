import Foundation
import EntityAuthDomain

/// Adapter that creates PeopleService from EntityAuthProvider
/// This allows views to use PeopleService without direct access to facade dependencies
extension AnyEntityAuthProvider {
    /// Creates a PeopleService instance that wraps this provider's methods
    @MainActor
    func makePeopleService() -> PeopleServiceProtocol {
        // Create an adapter that wraps EntityAuthProvider methods
        return ProviderPeopleServiceAdapter(provider: self)
    }
}

/// Adapter that implements PeopleServiceProtocol by wrapping EntityAuthProvider methods
@MainActor
private final class ProviderPeopleServiceAdapter: PeopleServiceProtocol {
    private let provider: AnyEntityAuthProvider
    
    init(provider: AnyEntityAuthProvider) {
        self.provider = provider
    }
    
    // MARK: - Search
    
    func searchUsers(q: String, limit: Int?) async throws -> [PersonSummary] {
        print("[ProviderPeopleServiceAdapter] 🔍 searchUsers called with q: '\(q)', limit: \(limit?.description ?? "nil")")
        print("[ProviderPeopleServiceAdapter] 🔍 Calling provider.inviteSearchUsers(q: '\(q)')")
        
        do {
            let results = try await provider.inviteSearchUsers(q: q)
            print("[ProviderPeopleServiceAdapter] ✅ provider.inviteSearchUsers returned \(results.count) raw results")
            
            let mapped = results.map { result in
                PersonSummary(
                    id: result.id,
                    email: result.email,
                    username: result.username,
                    alreadyInvited: false, // TODO: Check if already invited
                    alreadyFriends: false  // TODO: Check if already friends
                )
            }
            
            print("[ProviderPeopleServiceAdapter] ✅ Mapped to \(mapped.count) PersonSummary objects")
            return mapped
        } catch {
            print("[ProviderPeopleServiceAdapter] ❌ provider.inviteSearchUsers failed: \(error)")
            print("[ProviderPeopleServiceAdapter] ❌ Error type: \(type(of: error))")
            throw error
        }
    }
    
    // MARK: - Invitations
    
    func startInvitation(orgId: String, inviteeUserId: String, role: String) async throws -> InvitationStartResponse {
        let result = try await provider.inviteStart(orgId: orgId, inviteeUserId: inviteeUserId, role: role)
        // InvitationStartResponse is Codable, so we need to create it properly
        // Since it only has Codable init, we'll encode/decode or use the struct directly
        struct TempResponse: Codable {
            let id: String
            let token: String
            let expiresAt: Double
        }
        let temp = TempResponse(id: result.id, token: result.token, expiresAt: result.expiresAt)
        let data = try JSONEncoder().encode(temp)
        return try JSONDecoder().decode(InvitationStartResponse.self, from: data)
    }
    
    func acceptInvitation(token: String) async throws {
        try await provider.inviteAccept(token: token)
    }
    
    func acceptInvitationById(invitationId: String) async throws {
        try await provider.inviteAcceptById(invitationId: invitationId)
    }
    
    func declineInvitation(invitationId: String) async throws {
        try await provider.inviteDecline(invitationId: invitationId)
    }
    
    func revokeInvitation(invitationId: String) async throws {
        try await provider.inviteRevoke(invitationId: invitationId)
    }
    
    func resendInvitation(invitationId: String) async throws -> InvitationStartResponse {
        let result = try await provider.inviteResend(invitationId: invitationId)
        // Note: resend doesn't return the full invitation, so we use a placeholder ID
        struct TempResponse: Codable {
            let id: String
            let token: String
            let expiresAt: Double
        }
        let temp = TempResponse(id: invitationId, token: result.token, expiresAt: result.expiresAt)
        let data = try JSONEncoder().encode(temp)
        return try JSONDecoder().decode(InvitationStartResponse.self, from: data)
    }
    
    func listSentInvitations(inviterId: String, cursor: String?, limit: Int) async throws -> InvitationListResponse {
        let result = try await provider.invitationsSent(cursor: cursor, limit: limit)
        struct TempResponse: Codable {
            let items: [Invitation]
            let hasMore: Bool
            let nextCursor: String?
        }
        let temp = TempResponse(items: result.items, hasMore: result.hasMore, nextCursor: result.nextCursor)
        let data = try JSONEncoder().encode(temp)
        return try JSONDecoder().decode(InvitationListResponse.self, from: data)
    }
    
    func listReceivedInvitations(userId: String, cursor: String?, limit: Int) async throws -> InvitationListResponse {
        let result = try await provider.invitationsReceived(cursor: cursor, limit: limit)
        struct TempResponse: Codable {
            let items: [Invitation]
            let hasMore: Bool
            let nextCursor: String?
        }
        let temp = TempResponse(items: result.items, hasMore: result.hasMore, nextCursor: result.nextCursor)
        let data = try JSONEncoder().encode(temp)
        return try JSONDecoder().decode(InvitationListResponse.self, from: data)
    }
    
    // MARK: - Friends
    
    func startFriendRequest(targetUserId: String) async throws {
        try await provider.friendStart(targetUserId: targetUserId)
    }
    
    func acceptFriendRequest(requestId: String) async throws {
        try await provider.friendAccept(requestId: requestId)
    }
    
    func declineFriendRequest(requestId: String) async throws {
        try await provider.friendDecline(requestId: requestId)
    }
    
    func cancelFriendRequest(requestId: String) async throws {
        try await provider.friendCancel(requestId: requestId)
    }
    
    func listSentFriendRequests(requesterId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse {
        let result = try await provider.friendRequestsSent(cursor: cursor, limit: limit)
        struct TempResponse: Codable {
            let items: [FriendRequest]
            let hasMore: Bool
            let nextCursor: String?
        }
        let temp = TempResponse(items: result.items, hasMore: result.hasMore, nextCursor: result.nextCursor)
        let data = try JSONEncoder().encode(temp)
        return try JSONDecoder().decode(FriendRequestListResponse.self, from: data)
    }
    
    func listReceivedFriendRequests(targetUserId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse {
        let result = try await provider.friendRequestsReceived(cursor: cursor, limit: limit)
        struct TempResponse: Codable {
            let items: [FriendRequest]
            let hasMore: Bool
            let nextCursor: String?
        }
        let temp = TempResponse(items: result.items, hasMore: result.hasMore, nextCursor: result.nextCursor)
        let data = try JSONEncoder().encode(temp)
        return try JSONDecoder().decode(FriendRequestListResponse.self, from: data)
    }
    
    // MARK: - Friend Connections
    
    func listFriendConnections() async throws -> [FriendConnection] {
        return try await provider.listFriendConnections()
    }
    
    func removeFriendConnection(friendId: String) async throws {
        try await provider.removeFriendConnection(friendId: friendId)
    }
}

