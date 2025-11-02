import Foundation
import EntityAuthCore
import EntityAuthNetworking

public protocol OrganizationsProviding: Sendable {
    func create(name: String, slug: String, ownerId: String) async throws
    func create(workspaceTenantId: String, name: String, slug: String, ownerId: String) async throws
    func addMember(orgId: String, userId: String, role: String) async throws
    func switchActive(orgId: String) async throws -> String
    func switchOrg(orgId: String) async throws -> String
    func switchActive(workspaceTenantId: String, orgId: String) async throws -> String
    func list() async throws -> [OrganizationSummaryDTO]
    func active() async throws -> ActiveOrganizationDTO?
    // Updates for active organization (derived from access token org context)
    func setActiveOrgName(_ name: String) async throws
    func setActiveOrgSlug(_ slug: String) async throws
    func setActiveOrgImageUrl(_ imageUrl: String) async throws
}

public final class OrganizationService: OrganizationsProviding {
    private let client: APIClientType

    public init(client: APIClientType) {
        self.client = client
    }

    public func create(name: String, slug: String, ownerId: String) async throws {
        if let workspaceTenantId = client.workspaceTenantId {
            try await create(workspaceTenantId: workspaceTenantId, name: name, slug: slug, ownerId: ownerId)
        } else {
            throw EntityAuthError.configurationMissingWorkspaceTenantId
        }
    }

    public func create(workspaceTenantId: String, name: String, slug: String, ownerId: String) async throws {
        // Create org entity
        let payload: [String: Any] = [
            "op": "createEnforced",
            "workspaceTenantId": workspaceTenantId,
            "kind": "org",
            "properties": [
                "name": name,
                "slug": slug,
                "ownerId": ownerId
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = APIRequest(method: .post, path: "/api/entities", body: body)
        struct CreateResponse: Decodable { let id: String }
        let created: CreateResponse = try await client.send(request, decode: CreateResponse.self)
        // Bootstrap membership: link owner
        try await addMember(orgId: created.id, userId: ownerId, role: "owner")
    }

    public func addMember(orgId: String, userId: String, role: String) async throws {
        // Generic relation link: (user)-member_of->(org)
        guard let workspaceTenantId = client.workspaceTenantId else {
            throw EntityAuthError.configurationMissingWorkspaceTenantId
        }
        let payload: [String: Any] = [
            "op": "link",
            "workspaceTenantId": workspaceTenantId,
            "srcId": userId,
            "relation": "member_of",
            "dstId": orgId,
            "attrs": [
                "role": role,
                "joinedAt": Date().timeIntervalSince1970 * 1000
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = APIRequest(method: .post, path: "/api/relations", body: body)
        _ = try await client.send(request)
    }

    public func switchOrg(orgId: String) async throws -> String {
        if let workspaceTenantId = client.workspaceTenantId {
            return try await switchActive(workspaceTenantId: workspaceTenantId, orgId: orgId)
        } else {
            throw EntityAuthError.configurationMissingWorkspaceTenantId
        }
    }

    public func switchActive(orgId: String) async throws -> String {
        if let workspaceTenantId = client.workspaceTenantId {
            return try await switchActive(workspaceTenantId: workspaceTenantId, orgId: orgId)
        } else {
            throw EntityAuthError.configurationMissingWorkspaceTenantId
        }
    }

    public func switchActive(workspaceTenantId: String, orgId: String) async throws -> String {
        // Call EA endpoint to re-issue access token with new oid
        struct SwitchResponse: Decodable { let accessToken: String; let organizationId: String }
        let payload: [String: Any] = ["organizationId": orgId]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = APIRequest(method: .post, path: "/api/auth/switch-organization", headers: ["content-type": "application/json"], body: body)
        let response: SwitchResponse = try await client.send(request, decode: SwitchResponse.self)
        return response.accessToken
    }

    public func list() async throws -> [OrganizationSummaryDTO] {
        // Resolve current user id via /api/user/me
        let meReq = APIRequest(method: .get, path: "/api/user/me")
        let me = try await client.send(meReq, decode: UserResponse.self)
        // Query memberships via generic relations
        var orgs: [OrganizationSummaryDTO] = []
        let params = [
            URLQueryItem(name: "srcId", value: me.id),
            URLQueryItem(name: "relation", value: "member_of")
        ]
        let relReq = APIRequest(method: .get, path: "/api/relations", queryItems: params)
        struct RelationDTO: Decodable { let srcId: String; let relation: String; let dstId: String; let attrs: [String: AnyCodable]? }
        let relations = try await client.send(relReq, decode: [RelationDTO].self)
        for rel in relations {
            // Fetch org entity
            let entReq = APIRequest(method: .get, path: "/api/entities", queryItems: [
                URLQueryItem(name: "id", value: rel.dstId)
            ])
            struct EntityDTO: Decodable { let id: String; let properties: [String: AnyCodable]?; let workspaceTenantId: String? }
            if let entity = try await client.send(entReq, decode: EntityDTO?.self) {
                let props = entity.properties ?? [:]
                let role = (rel.attrs?["role"]?.stringValue) ?? "member"
                let joinedAt = (rel.attrs?["joinedAt"]?.doubleValue) ?? Date().timeIntervalSince1970 * 1000
                let summary = OrganizationSummaryDTO(
                    orgId: entity.id,
                    name: props["name"]?.stringValue,
                    slug: props["slug"]?.stringValue,
                    memberCount: nil,
                    role: role,
                    joinedAt: joinedAt,
                    workspaceTenantId: entity.workspaceTenantId
                )
                orgs.append(summary)
            }
        }
        return orgs
    }

    public func active() async throws -> ActiveOrganizationDTO? {
        // Not supported via generic HTTP; active org is derived from realtime
        return nil
    }

    // MARK: - Updates
    public func setActiveOrgName(_ name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EntityAuthError.invalidResponse }
        let payload = try JSONSerialization.data(withJSONObject: ["name": trimmed])
        let req = APIRequest(method: .post, path: "/api/org/name", headers: ["content-type": "application/json"], body: payload)
        _ = try await client.send(req)
    }

    public func setActiveOrgSlug(_ slug: String) async throws {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EntityAuthError.invalidResponse }
        let payload = try JSONSerialization.data(withJSONObject: ["slug": trimmed])
        let req = APIRequest(method: .post, path: "/api/org/slug", headers: ["content-type": "application/json"], body: payload)
        _ = try await client.send(req)
    }

    public func setActiveOrgImageUrl(_ imageUrl: String) async throws {
        let trimmed = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EntityAuthError.invalidResponse }
        let payload = try JSONSerialization.data(withJSONObject: ["imageUrl": trimmed])
        let req = APIRequest(method: .post, path: "/api/org/image", headers: ["content-type": "application/json"], body: payload)
        _ = try await client.send(req)
    }
}
