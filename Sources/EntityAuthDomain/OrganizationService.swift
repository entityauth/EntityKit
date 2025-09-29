import Foundation
import EntityAuthCore
import EntityAuthNetworking

public protocol OrganizationsProviding: Sendable {
    func create(name: String, slug: String, ownerId: String) async throws
    func create(workspaceTenantId: String, name: String, slug: String, ownerId: String) async throws
    func addMember(orgId: String, userId: String, role: String) async throws
    func switchActive(orgId: String) async throws
    func switchOrg(orgId: String) async throws
    func switchActive(workspaceTenantId: String, orgId: String) async throws
    func list() async throws -> [OrganizationSummaryDTO]
    func active() async throws -> ActiveOrganizationDTO?
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
        let payload = [
            "workspaceTenantId": workspaceTenantId,
            "name": name,
            "slug": slug,
            "ownerId": ownerId
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = APIRequest(method: .post, path: "/api/org/create", body: body)
        _ = try await client.send(request)
    }

    public func addMember(orgId: String, userId: String, role: String) async throws {
        let payload = [
            "orgId": orgId,
            "userId": userId,
            "role": role
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = APIRequest(method: .post, path: "/api/org/add-member", body: body)
        _ = try await client.send(request)
    }

    public func switchOrg(orgId: String) async throws {
        if let workspaceTenantId = client.workspaceTenantId {
            try await switchActive(workspaceTenantId: workspaceTenantId, orgId: orgId)
        } else {
            throw EntityAuthError.configurationMissingWorkspaceTenantId
        }
    }

    public func switchActive(orgId: String) async throws {
        if let workspaceTenantId = client.workspaceTenantId {
            try await switchActive(workspaceTenantId: workspaceTenantId, orgId: orgId)
        } else {
            throw EntityAuthError.configurationMissingWorkspaceTenantId
        }
    }

    public func switchActive(workspaceTenantId: String, orgId: String) async throws {
        let payload = ["workspaceTenantId": workspaceTenantId, "orgId": orgId]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = APIRequest(method: .post, path: "/api/org/switch", body: body)
        _ = try await client.send(request)
    }

    public func list() async throws -> [OrganizationSummaryDTO] {
        let request = APIRequest(method: .get, path: "/api/org/list")
        struct Response: Decodable { let organizations: [OrganizationSummaryDTO] }
        let response = try await client.send(request, decode: Response.self)
        return response.organizations
    }

    public func active() async throws -> ActiveOrganizationDTO? {
        let request = APIRequest(method: .get, path: "/api/org/active")
        struct Response: Decodable { let organization: ActiveOrganizationDTO? }
        let response = try await client.send(request, decode: Response.self)
        return response.organization
    }
}
