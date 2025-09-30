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
