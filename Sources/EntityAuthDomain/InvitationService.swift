import Foundation

// Standardized invitation error codes matching backend
public enum InvitationError: Error, Sendable {
    case notFound
    case expired
    case alreadyAccepted
    case alreadyDeclined
    case alreadyRevoked
    case duplicate
    case alreadyMember
    case unauthorized
    case invalidToken
    case rateLimited
    case networkError(String)
    case unknown(String)
    
    init?(from errorCode: String) {
        switch errorCode {
        case "INVITATION_NOT_FOUND": self = .notFound
        case "INVITATION_EXPIRED": self = .expired
        case "INVITATION_ALREADY_ACCEPTED": self = .alreadyAccepted
        case "INVITATION_ALREADY_DECLINED": self = .alreadyDeclined
        case "INVITATION_ALREADY_REVOKED": self = .alreadyRevoked
        case "INVITATION_DUPLICATE": self = .duplicate
        case "USER_ALREADY_MEMBER": self = .alreadyMember
        case "UNAUTHORIZED": self = .unauthorized
        case "INVALID_TOKEN": self = .invalidToken
        case "RATE_LIMITED": self = .rateLimited
        default: return nil
        }
    }
}

public struct Invitation: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let orgId: String
    public let inviteeUserId: String
    public let role: String
    public let status: String
    public let expiresAt: Double
    public let createdAt: Double
    public let respondedAt: Double?
    public let createdBy: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case orgId
        case inviteeUserId
        case role
        case status
        case expiresAt
        case createdAt
        case respondedAt
        case createdBy
    }
}

public struct InvitationListResponse: Codable, Sendable {
    public let items: [Invitation]
    public let hasMore: Bool
    public let nextCursor: String?
}

public struct InvitationStartResponse: Codable, Sendable {
    public let id: String
    public let token: String // Only returned on creation
    public let expiresAt: Double
}

public protocol InvitationsProviding: Sendable {
    func start(orgId: String, inviteeUserId: String, role: String) async throws -> InvitationStartResponse
    func accept(token: String) async throws
    func acceptById(invitationId: String) async throws
    func decline(invitationId: String) async throws
    func revoke(invitationId: String) async throws
    func resend(invitationId: String) async throws -> InvitationStartResponse
    func listSent(inviterId: String, cursor: String?, limit: Int) async throws -> InvitationListResponse
    func listReceived(userId: String, cursor: String?, limit: Int) async throws -> InvitationListResponse
    func searchUsers(q: String) async throws -> [(id: String, email: String?, username: String?)]
}

public final class InvitationService: InvitationsProviding {
    private let client: APIClientType
    
    public init(client: APIClientType) {
        self.client = client
    }
    
    private func handleError(_ data: Data) throws {
        // Try to parse error code from response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorCode = json["error"] as? String {
            if let invitationError = InvitationError(from: errorCode) {
                throw invitationError
            }
            throw InvitationError.unknown(errorCode)
        }
    }
    
    public func start(orgId: String, inviteeUserId: String, role: String) async throws -> InvitationStartResponse {
        let body: [String: Any] = [
            "op": "start",
            "orgId": orgId,
            "inviteeUserId": inviteeUserId,
            "role": role
        ]
        
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/invitations", body: data)
        let responseData = try await client.send(req)
        try handleError(responseData)
        return try JSONDecoder().decode(InvitationStartResponse.self, from: responseData)
    }
    
    public func accept(token: String) async throws {
        let body: [String: Any] = [
            "op": "accept",
            "token": token
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/invitations", body: data)
        let responseData = try await client.send(req)
        try handleError(responseData)
    }
    
    public func acceptById(invitationId: String) async throws {
        let body: [String: Any] = [
            "op": "accept",
            "invitationId": invitationId
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/invitations", body: data)
        let responseData = try await client.send(req)
        try handleError(responseData)
    }
    
    public func decline(invitationId: String) async throws {
        let body: [String: Any] = [
            "op": "decline",
            "invitationId": invitationId
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/invitations", body: data)
        let responseData = try await client.send(req)
        try handleError(responseData)
    }
    
    public func revoke(invitationId: String) async throws {
        let body: [String: Any] = [
            "op": "revoke",
            "invitationId": invitationId
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/invitations", body: data)
        let responseData = try await client.send(req)
        try handleError(responseData)
    }
    
    public func resend(invitationId: String) async throws -> InvitationStartResponse {
        let body: [String: Any] = [
            "op": "resend",
            "invitationId": invitationId
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/invitations", body: data)
        let responseData = try await client.send(req)
        try handleError(responseData)
        return try JSONDecoder().decode(InvitationStartResponse.self, from: responseData)
    }
    
    public func listSent(inviterId: String, cursor: String?, limit: Int = 20) async throws -> InvitationListResponse {
        var queryItems: [URLQueryItem] = [
            .init(name: "inviterId", value: inviterId)
        ]
        if let cursor = cursor {
            queryItems.append(.init(name: "cursor", value: cursor))
        }
        queryItems.append(.init(name: "limit", value: String(limit)))
        
        let req = APIRequest(method: .get, path: "/api/invitations", queryItems: queryItems)
        let responseData = try await client.send(req)
        try handleError(responseData)
        return try JSONDecoder().decode(InvitationListResponse.self, from: responseData)
    }
    
    public func listReceived(userId: String, cursor: String?, limit: Int = 20) async throws -> InvitationListResponse {
        var queryItems: [URLQueryItem] = [
            .init(name: "userId", value: userId)
        ]
        if let cursor = cursor {
            queryItems.append(.init(name: "cursor", value: cursor))
        }
        queryItems.append(.init(name: "limit", value: String(limit)))
        
        let req = APIRequest(method: .get, path: "/api/invitations", queryItems: queryItems)
        let responseData = try await client.send(req)
        try handleError(responseData)
        return try JSONDecoder().decode(InvitationListResponse.self, from: responseData)
    }
    
    public func searchUsers(q: String) async throws -> [(id: String, email: String?, username: String?)] {
        guard q.count >= 2 else {
            return []
        }
        
        let body: [String: Any] = ["q": q]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/users/search", body: data)
        struct Raw: Decodable {
            let _id: String?
            let properties: Props?
            struct Props: Decodable {
                let email: String?
                let username: String?
            }
        }
        let rows = try await client.send(req, decode: [Raw].self)
        return rows.compactMap { r in
            guard let id = r._id else { return nil }
            return (id, r.properties?.email, r.properties?.username)
        }
    }
}
