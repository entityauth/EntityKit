import Foundation

// MARK: - Error Types

public enum AccountTypeError: Error, Sendable {
    case notFound
    case duplicate
    case unauthorized
    case networkError(String)
    case unknown(String)
    
    init?(code: String) {
        switch code {
        case "ACCOUNT_TYPE_NOT_FOUND": self = .notFound
        case "ACCOUNT_TYPE_DUPLICATE": self = .duplicate
        case "UNAUTHORIZED": self = .unauthorized
        default: return nil
        }
    }
}

// MARK: - Data Types

public struct AccountTypeCapabilities: Codable, Sendable, Hashable {
    public let hasFriends: Bool
    public let hasOrgs: Bool
    public let hasTeamInvites: Bool
    
    public init(hasFriends: Bool, hasOrgs: Bool, hasTeamInvites: Bool) {
        self.hasFriends = hasFriends
        self.hasOrgs = hasOrgs
        self.hasTeamInvites = hasTeamInvites
    }
}

public struct AccountTypeConfig: Codable, Sendable, Identifiable, Hashable {
    public let _id: String
    public let key: String
    public let label: String
    public let description: String?
    public let icon: String?
    public let capabilities: AccountTypeCapabilities
    public let isDefault: Bool
    public let sortOrder: Int
    public let status: String
    
    public var id: String { _id }
    
    public init(
        _id: String,
        key: String,
        label: String,
        description: String?,
        icon: String?,
        capabilities: AccountTypeCapabilities,
        isDefault: Bool,
        sortOrder: Int,
        status: String
    ) {
        self._id = _id
        self.key = key
        self.label = label
        self.description = description
        self.icon = icon
        self.capabilities = capabilities
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.status = status
    }
}

public struct UserAccountType: Codable, Sendable {
    public let accountTypeKey: String
    public let config: AccountTypeConfig?
    
    public init(accountTypeKey: String, config: AccountTypeConfig?) {
        self.accountTypeKey = accountTypeKey
        self.config = config
    }
}

// MARK: - Response Types

struct AccountTypeConfigsResponse: Codable {
    let configs: [AccountTypeConfig]
}

struct CapabilityCheckResponse: Codable {
    let capabilities: AccountTypeCapabilities
}

// MARK: - Protocol

public protocol AccountTypesProviding: Sendable {
    func listConfigs() async throws -> [AccountTypeConfig]
    func getUserAccountType() async throws -> UserAccountType
    func setAccountType(key: String) async throws -> UserAccountType
    func hasCapability(_ capability: String) async throws -> Bool
    func getCapabilities() async throws -> AccountTypeCapabilities
}

// MARK: - Service Implementation

public final class AccountTypeService: AccountTypesProviding {
    private let client: APIClientType
    
    public init(client: APIClientType) {
        self.client = client
    }
    
    private func handleError(_ data: Data) throws {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorCode = json["error"] as? String {
            if let error = AccountTypeError(code: errorCode) {
                throw error
            }
            throw AccountTypeError.unknown(errorCode)
        }
    }
    
    public func listConfigs() async throws -> [AccountTypeConfig] {
        let req = APIRequest(method: .get, path: "/api/account-types")
        let responseData = try await client.send(req)
        try handleError(responseData)
        let response = try JSONDecoder().decode(AccountTypeConfigsResponse.self, from: responseData)
        return response.configs
    }
    
    public func getUserAccountType() async throws -> UserAccountType {
        let req = APIRequest(method: .get, path: "/api/account-types/user")
        let responseData = try await client.send(req)
        try handleError(responseData)
        return try JSONDecoder().decode(UserAccountType.self, from: responseData)
    }
    
    public func setAccountType(key: String) async throws -> UserAccountType {
        let body: [String: Any] = ["accountTypeKey": key]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/account-types/user", body: data)
        let responseData = try await client.send(req)
        try handleError(responseData)
        return try JSONDecoder().decode(UserAccountType.self, from: responseData)
    }
    
    public func hasCapability(_ capability: String) async throws -> Bool {
        let queryItems: [URLQueryItem] = [.init(name: "check", value: capability)]
        let req = APIRequest(method: .get, path: "/api/account-types/capability", queryItems: queryItems)
        let responseData = try await client.send(req)
        try handleError(responseData)
        
        // Parse the response to get the specific capability
        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let capabilities = json["capabilities"] as? [String: Bool],
           let hasCapability = capabilities[capability] {
            return hasCapability
        }
        return false
    }
    
    public func getCapabilities() async throws -> AccountTypeCapabilities {
        let queryItems: [URLQueryItem] = [.init(name: "check", value: "hasFriends,hasOrgs,hasTeamInvites")]
        let req = APIRequest(method: .get, path: "/api/account-types/capability", queryItems: queryItems)
        let responseData = try await client.send(req)
        try handleError(responseData)
        let response = try JSONDecoder().decode(CapabilityCheckResponse.self, from: responseData)
        return response.capabilities
    }
}

// MARK: - Convenience Extensions

public extension AccountTypeCapabilities {
    static let none = AccountTypeCapabilities(hasFriends: false, hasOrgs: false, hasTeamInvites: false)
    
    static let personal = AccountTypeCapabilities(hasFriends: true, hasOrgs: false, hasTeamInvites: false)
    
    static let team = AccountTypeCapabilities(hasFriends: false, hasOrgs: true, hasTeamInvites: true)
}
