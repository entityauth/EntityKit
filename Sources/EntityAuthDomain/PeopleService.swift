import Foundation

/// Unified error type for people-related operations (invites, friends, search)
public enum PeopleError: Error, Sendable {
    case invitation(InvitationError)
    case friend(FriendRequestError)
    case search(SearchError)
    case networkError(String)
    case unauthorized
    case unknown(String)
    
    public init?(from errorCode: String) {
        if let invitationError = InvitationError(from: errorCode) {
            self = .invitation(invitationError)
            return
        }
        if let friendError = FriendRequestError(code: errorCode) {
            self = .friend(friendError)
            return
        }
        if let searchError = SearchError(from: errorCode) {
            self = .search(searchError)
            return
        }
        switch errorCode {
        case "UNAUTHORIZED":
            self = .unauthorized
        default:
            return nil
        }
    }
}

/// Search-specific error codes
public enum SearchError: Error, Sendable {
    case missingQuery
    case queryTooShort
    case validationError
    case searchError(String)
    
    init?(from errorCode: String) {
        switch errorCode {
        case "SEARCH_MISSING_QUERY":
            self = .missingQuery
        case "SEARCH_QUERY_TOO_SHORT":
            self = .queryTooShort
        case "SEARCH_VALIDATION_ERROR":
            self = .validationError
        case "SEARCH_ERROR":
            self = .searchError(errorCode)
        default:
            return nil
        }
    }
}

/// Summary of a person/user for search results
public struct PersonSummary: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let email: String?
    public let username: String?
    public let alreadyInvited: Bool
    public let alreadyFriends: Bool
    
    public init(id: String, email: String?, username: String?, alreadyInvited: Bool = false, alreadyFriends: Bool = false) {
        self.id = id
        self.email = email
        self.username = username
        self.alreadyInvited = alreadyInvited
        self.alreadyFriends = alreadyFriends
    }
}

/// Summary of an invitation (sent or received)
public struct InviteSummary: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let orgId: String
    public let inviteeUserId: String
    public let role: String
    public let status: String
    public let expiresAt: Double
    public let createdAt: Double
    public let respondedAt: Double?
    public let createdBy: String?
    
    public init(from invitation: Invitation) {
        self.id = invitation.id
        self.orgId = invitation.orgId
        self.inviteeUserId = invitation.inviteeUserId
        self.role = invitation.role
        self.status = invitation.status
        self.expiresAt = invitation.expiresAt
        self.createdAt = invitation.createdAt
        self.respondedAt = invitation.respondedAt
        self.createdBy = invitation.createdBy
    }
}

/// Confirmed friend connection
public struct FriendConnection: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let email: String?
    public let username: String?
    public let since: Double
    public let createdAt: Double
    
    public init(id: String, email: String?, username: String?, since: Double, createdAt: Double) {
        self.id = id
        self.email = email
        self.username = username
        self.since = since
        self.createdAt = createdAt
    }
}

/// Search response matching backend API format
public struct SearchUsersResponse: Codable, Sendable {
    public let users: [PersonSummary]
    
    public init(users: [PersonSummary]) {
        self.users = users
    }
}

/// Friends connections response matching backend API format
public struct FriendsConnectionsResponse: Codable, Sendable {
    public let friends: [FriendConnection]
    
    public init(friends: [FriendConnection]) {
        self.friends = friends
    }
}

/// Unified protocol bundling invites, friends, and search operations
/// This provides a single service boundary for the "People" experience
@MainActor
public protocol PeopleServiceProtocol: Sendable {
    // Search
    func searchUsers(q: String, limit: Int?) async throws -> [PersonSummary]
    
    // Invitations
    func startInvitation(orgId: String, inviteeUserId: String, role: String) async throws -> InvitationStartResponse
    func acceptInvitation(token: String) async throws
    func acceptInvitationById(invitationId: String) async throws
    func declineInvitation(invitationId: String) async throws
    func revokeInvitation(invitationId: String) async throws
    func resendInvitation(invitationId: String) async throws -> InvitationStartResponse
    func listSentInvitations(inviterId: String, cursor: String?, limit: Int) async throws -> InvitationListResponse
    func listReceivedInvitations(userId: String, cursor: String?, limit: Int) async throws -> InvitationListResponse
    
    // Friends
    func startFriendRequest(targetUserId: String) async throws
    func acceptFriendRequest(requestId: String) async throws
    func declineFriendRequest(requestId: String) async throws
    func cancelFriendRequest(requestId: String) async throws
    func listSentFriendRequests(requesterId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse
    func listReceivedFriendRequests(targetUserId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse
    
    // Friend connections (confirmed friendships)
    func listFriendConnections() async throws -> [FriendConnection]
    func removeFriendConnection(friendId: String) async throws
}

/// Default implementation of PeopleServiceProtocol
/// Delegates to InvitationService and FriendService while providing unified error handling
@MainActor
public final class PeopleService: PeopleServiceProtocol {
    private let invitationService: InvitationsProviding
    private let friendService: FriendsProviding
    private let client: APIClientType
    
    public init(
        invitationService: InvitationsProviding,
        friendService: FriendsProviding,
        client: APIClientType
    ) {
        self.invitationService = invitationService
        self.friendService = friendService
        self.client = client
    }
    
    // MARK: - Search
    
    public func searchUsers(q: String, limit: Int? = nil) async throws -> [PersonSummary] {
        guard !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Single character requires @ for email
        if trimmed.count == 1 && !trimmed.contains("@") {
            return []
        }
        
        var body: [String: Any] = ["q": trimmed]
        if let limit = limit {
            body["limit"] = limit
        }
        
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/users/search", body: data)
        
        do {
            let response = try await client.send(req, decode: SearchUsersResponse.self)
            return response.users
        } catch let error as EntityAuthError {
            // Extract error code from network error message if available
            if case .network(let statusCode, let message) = error,
               let message = message,
               let jsonData = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let errorCode = json["error"] as? String {
                if let peopleError = PeopleError(from: errorCode) {
                    throw peopleError
                }
            }
            throw PeopleError.networkError(error.localizedDescription)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Invitations
    
    public func startInvitation(orgId: String, inviteeUserId: String, role: String) async throws -> InvitationStartResponse {
        do {
            return try await invitationService.start(orgId: orgId, inviteeUserId: inviteeUserId, role: role)
        } catch let error as InvitationError {
            throw PeopleError.invitation(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func acceptInvitation(token: String) async throws {
        do {
            try await invitationService.accept(token: token)
        } catch let error as InvitationError {
            throw PeopleError.invitation(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func acceptInvitationById(invitationId: String) async throws {
        do {
            try await invitationService.acceptById(invitationId: invitationId)
        } catch let error as InvitationError {
            throw PeopleError.invitation(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func declineInvitation(invitationId: String) async throws {
        do {
            try await invitationService.decline(invitationId: invitationId)
        } catch let error as InvitationError {
            throw PeopleError.invitation(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func revokeInvitation(invitationId: String) async throws {
        do {
            try await invitationService.revoke(invitationId: invitationId)
        } catch let error as InvitationError {
            throw PeopleError.invitation(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func resendInvitation(invitationId: String) async throws -> InvitationStartResponse {
        do {
            return try await invitationService.resend(invitationId: invitationId)
        } catch let error as InvitationError {
            throw PeopleError.invitation(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func listSentInvitations(inviterId: String, cursor: String?, limit: Int) async throws -> InvitationListResponse {
        do {
            return try await invitationService.listSent(inviterId: inviterId, cursor: cursor, limit: limit)
        } catch let error as InvitationError {
            throw PeopleError.invitation(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func listReceivedInvitations(userId: String, cursor: String?, limit: Int) async throws -> InvitationListResponse {
        do {
            return try await invitationService.listReceived(userId: userId, cursor: cursor, limit: limit)
        } catch let error as InvitationError {
            throw PeopleError.invitation(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Friends
    
    public func startFriendRequest(targetUserId: String) async throws {
        do {
            try await friendService.start(targetUserId: targetUserId)
        } catch let error as FriendRequestError {
            throw PeopleError.friend(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func acceptFriendRequest(requestId: String) async throws {
        do {
            try await friendService.accept(requestId: requestId)
        } catch let error as FriendRequestError {
            throw PeopleError.friend(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func declineFriendRequest(requestId: String) async throws {
        do {
            try await friendService.decline(requestId: requestId)
        } catch let error as FriendRequestError {
            throw PeopleError.friend(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func cancelFriendRequest(requestId: String) async throws {
        do {
            try await friendService.cancel(requestId: requestId)
        } catch let error as FriendRequestError {
            throw PeopleError.friend(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func listSentFriendRequests(requesterId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse {
        do {
            return try await friendService.listSent(requesterId: requesterId, cursor: cursor, limit: limit)
        } catch let error as FriendRequestError {
            throw PeopleError.friend(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func listReceivedFriendRequests(targetUserId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse {
        do {
            return try await friendService.listReceived(targetUserId: targetUserId, cursor: cursor, limit: limit)
        } catch let error as FriendRequestError {
            throw PeopleError.friend(error)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Friend Connections
    
    public func listFriendConnections() async throws -> [FriendConnection] {
        let req = APIRequest(method: .get, path: "/api/friends/connections")
        
        do {
            let response = try await client.send(req, decode: FriendsConnectionsResponse.self)
            return response.friends
        } catch let error as EntityAuthError {
            // Extract error code from network error message if available
            if case .network(let statusCode, let message) = error,
               let message = message,
               let jsonData = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let errorCode = json["error"] as? String {
                if let peopleError = PeopleError(from: errorCode) {
                    throw peopleError
                }
            }
            throw PeopleError.networkError(error.localizedDescription)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
    
    public func removeFriendConnection(friendId: String) async throws {
        var queryItems: [URLQueryItem] = [
            .init(name: "friendId", value: friendId)
        ]
        let req = APIRequest(method: .delete, path: "/api/friends/connections", queryItems: queryItems)
        
        do {
            _ = try await client.send(req)
        } catch let error as EntityAuthError {
            // Extract error code from network error message if available
            if case .network(let statusCode, let message) = error,
               let message = message,
               let jsonData = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let errorCode = json["error"] as? String {
                if let peopleError = PeopleError(from: errorCode) {
                    throw peopleError
                }
            }
            throw PeopleError.networkError(error.localizedDescription)
        } catch {
            throw PeopleError.networkError(error.localizedDescription)
        }
    }
}

