import Foundation

public enum FriendRequestError: Error, Sendable {
    case notFound
    case duplicate
    case selfRequest
    case alreadyFriends
    case unauthorized
    case rateLimited
    case networkError(String)
    case unknown(String)
    
    init?(code: String) {
        switch code {
        case "FRIEND_REQUEST_NOT_FOUND": self = .notFound
        case "FRIEND_REQUEST_DUPLICATE": self = .duplicate
        case "FRIEND_REQUEST_SELF": self = .selfRequest
        case "FRIEND_REQUEST_ALREADY_FRIENDS": self = .alreadyFriends
        case "UNAUTHORIZED": self = .unauthorized
        case "RATE_LIMITED": self = .rateLimited
        default: return nil
        }
    }
}

public struct FriendRequest: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let requesterId: String
    public let targetUserId: String
    public let status: String
    public let createdAt: Double
    public let respondedAt: Double?
}

public struct FriendRequestListResponse: Codable, Sendable {
    public let items: [FriendRequest]
    public let hasMore: Bool
    public let nextCursor: String?
}

public protocol FriendsProviding: Sendable {
    func start(targetUserId: String) async throws
    func accept(requestId: String) async throws
    func decline(requestId: String) async throws
    func cancel(requestId: String) async throws
    func listSent(requesterId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse
    func listReceived(targetUserId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse
}

public final class FriendService: FriendsProviding {
    private let client: APIClientType
    
    public init(client: APIClientType) {
        self.client = client
    }
    
    private func handleError(_ data: Data) throws {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorCode = json["error"] as? String {
            if let error = FriendRequestError(code: errorCode) {
                throw error
            }
            throw FriendRequestError.unknown(errorCode)
        }
    }
    
    public func start(targetUserId: String) async throws {
        let body: [String: Any] = ["op": "start", "targetUserId": targetUserId]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/friends", body: data)
        let responseData = try await client.send(req)
        try handleError(responseData)
    }
    
    public func accept(requestId: String) async throws {
        let body: [String: Any] = ["op": "accept", "requestId": requestId]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/friends", body: data)
        let responseData = try await client.send(req)
        try handleError(responseData)
    }
    
    public func decline(requestId: String) async throws {
        let body: [String: Any] = ["op": "decline", "requestId": requestId]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/friends", body: data)
        let responseData = try await client.send(req)
        try handleError(responseData)
    }
    
    public func cancel(requestId: String) async throws {
        let body: [String: Any] = ["op": "cancel", "requestId": requestId]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/friends", body: data)
        let responseData = try await client.send(req)
        try handleError(responseData)
    }
    
    public func listSent(requesterId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse {
        var queryItems: [URLQueryItem] = [.init(name: "requesterId", value: requesterId)]
        if let cursor { queryItems.append(.init(name: "cursor", value: cursor)) }
        queryItems.append(.init(name: "limit", value: String(limit)))
        let req = APIRequest(method: .get, path: "/api/friends", queryItems: queryItems)
        let responseData = try await client.send(req)
        try handleError(responseData)
        return try JSONDecoder().decode(FriendRequestListResponse.self, from: responseData)
    }
    
    public func listReceived(targetUserId: String, cursor: String?, limit: Int) async throws -> FriendRequestListResponse {
        var queryItems: [URLQueryItem] = [.init(name: "targetUserId", value: targetUserId)]
        if let cursor { queryItems.append(.init(name: "cursor", value: cursor)) }
        queryItems.append(.init(name: "limit", value: String(limit)))
        let req = APIRequest(method: .get, path: "/api/friends", queryItems: queryItems)
        let responseData = try await client.send(req)
        try handleError(responseData)
        return try JSONDecoder().decode(FriendRequestListResponse.self, from: responseData)
    }
}

