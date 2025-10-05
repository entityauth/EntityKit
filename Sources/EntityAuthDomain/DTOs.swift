import Foundation

public struct LoginRequest: Encodable, Sendable {
    public let email: String
    public let password: String
    public let workspaceTenantId: String

    public init(email: String, password: String, workspaceTenantId: String) {
        self.email = email
        self.password = password
        self.workspaceTenantId = workspaceTenantId
    }
}

public struct LoginResponse: Decodable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let sessionId: String
    public let userId: String
}

public struct RegisterRequest: Encodable, Sendable {
    public let email: String
    public let password: String
    public let workspaceTenantId: String

    public init(email: String, password: String, workspaceTenantId: String) {
        self.email = email
        self.password = password
        self.workspaceTenantId = workspaceTenantId
    }
}

public struct RegisterResponse: Decodable, Sendable {
    public let success: Bool
}

public struct OrganizationSummaryDTO: Decodable, Sendable {
    public let orgId: String
    public let name: String?
    public let slug: String?
    public let memberCount: Int?
    public let role: String
    public let joinedAt: Double
    public let workspaceTenantId: String?
}

public struct ActiveOrganizationDTO: Decodable, Sendable {
    public let orgId: String
    public let name: String?
    public let slug: String?
    public let memberCount: Int?
    public let role: String
    public let joinedAt: Double
    public let workspaceTenantId: String?
    public let description: String?
}

public struct UsernameCheckResponse: Decodable, Sendable {
    public let valid: Bool
    public let available: Bool
}

public struct UsernameSetRequest: Encodable {
    public let username: String
}

public struct SessionSummaryDTO: Decodable, Sendable {
    public let id: String
    public let status: String
    public let createdAt: Double
    public let revokedAt: Double?
}

public struct SessionListResponse: Decodable, Sendable {
    public let sessions: [SessionSummaryDTO]
}

public struct RevokeSessionRequest: Encodable {
    public let sessionId: String
}

public struct RevokeSessionsByUserRequest: Encodable {
    public let userId: String
}

public struct UserResponse: Decodable, Sendable {
    public let id: String
    public let email: String?
    public let username: String?
    public let workspaceTenantId: String?
}

public struct EntityDTO: Decodable, Sendable {
    public let id: String
    public let kind: String?
    public let workspaceTenantId: String?
    public let properties: [String: AnyCodable]?
    public let metadata: [String: AnyCodable]?
    public let status: String?
    public let createdAt: Double?
    public let updatedAt: Double?
}

public struct ListEntitiesFilter: Encodable, Sendable {
    public var status: String?
    public var email: String?
    public var slug: String?

    public init(status: String? = nil, email: String? = nil, slug: String? = nil) {
        self.status = status
        self.email = email
        self.slug = slug
    }
}

public struct UserByEmailRequest: Encodable {
    public let email: String
}

public struct GraphQLRequest: Encodable {
    public let query: String
    public let variables: [String: AnyCodable]
}

public struct GraphQLWrapper<T: Decodable>: Decodable {
    public let data: T?
}
