import Foundation

public struct OrganizationSummary: Identifiable, Hashable, Codable, Sendable {
    public let orgId: String
    public let name: String?
    public let slug: String?
    public let memberCount: Int?
    public let role: String
    public let joinedAt: Double
    public let workspaceTenantId: String?

    public var id: String { orgId }

    public init(
        orgId: String,
        name: String?,
        slug: String?,
        memberCount: Int?,
        role: String,
        joinedAt: Double,
        workspaceTenantId: String?
    ) {
        self.orgId = orgId
        self.name = name
        self.slug = slug
        self.memberCount = memberCount
        self.role = role
        self.joinedAt = joinedAt
        self.workspaceTenantId = workspaceTenantId
    }
}

public struct ActiveOrganization: Identifiable, Hashable, Codable, Sendable {
    public let orgId: String
    public let name: String?
    public let slug: String?
    public let memberCount: Int?
    public let role: String
    public let joinedAt: Double
    public let workspaceTenantId: String?
    public let description: String?

    public var id: String { orgId }

    public init(
        orgId: String,
        name: String?,
        slug: String?,
        memberCount: Int?,
        role: String,
        joinedAt: Double,
        workspaceTenantId: String?,
        description: String?
    ) {
        self.orgId = orgId
        self.name = name
        self.slug = slug
        self.memberCount = memberCount
        self.role = role
        self.joinedAt = joinedAt
        self.workspaceTenantId = workspaceTenantId
        self.description = description
    }
}

extension OrganizationSummaryDTO {
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

extension ActiveOrganizationDTO {
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

// MARK: - Account Management

public enum AccountMode: String, Codable, Sendable {
    case personal
    case team
}

public struct AccountSummary: Identifiable, Hashable, Codable, Sendable {
    public let id: String // accountId: "user:<userId>:tenant:<workspaceTenantId>"
    public let userId: String
    public let email: String?
    public let username: String?
    public let imageUrl: URL?
    public let mode: AccountMode
    public let organizations: [OrganizationSummary]
    public let activeOrganizationId: String?
    public let workspaceTenantId: String?
    public let lastActiveAt: Date
    public let hydratedOnThisDevice: Bool // Do we have tokens locally for this account?

    public init(
        id: String,
        userId: String,
        email: String?,
        username: String?,
        imageUrl: URL?,
        mode: AccountMode,
        organizations: [OrganizationSummary],
        activeOrganizationId: String?,
        workspaceTenantId: String?,
        lastActiveAt: Date,
        hydratedOnThisDevice: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.email = email
        self.username = username
        self.imageUrl = imageUrl
        self.mode = mode
        self.organizations = organizations
        self.activeOrganizationId = activeOrganizationId
        self.workspaceTenantId = workspaceTenantId
        self.lastActiveAt = lastActiveAt
        self.hydratedOnThisDevice = hydratedOnThisDevice
    }
}

// Token bundle stored per-device (never synced across devices)
public struct TokenBundle: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let sessionId: String?
    
    public init(accessToken: String, refreshToken: String?, sessionId: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.sessionId = sessionId
    }
}

public protocol AccountManaging: Sendable {
    // Local operations
    func listAccounts() async throws -> [AccountSummary]
    func activeAccount() async throws -> AccountSummary?
    func syncFromCurrentSession() async throws
    func switchAccount(id: String) async throws
    func logoutAccount(id: String) async throws
    func logoutAll() async throws
    
    // Cloud sync operations
    func syncFromCloud() async throws
    func pushToCloud() async throws
    
    // UI hook (host app decides behavior)
    func addAccount() async throws
}
