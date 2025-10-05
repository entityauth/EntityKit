import Foundation
import EntityAuthNetworking

public protocol EntitiesProviding: Sendable {
    func get(id: String) async throws -> EntityDTO?
    func list(workspaceTenantId: String, kind: String, filter: ListEntitiesFilter?, limit: Int?) async throws -> [EntityDTO]
    func upsert(workspaceTenantId: String, kind: String, properties: [String: Any], metadata: [String: Any]?) async throws -> EntityDTO
    func createEnforced(workspaceTenantId: String, kind: String, properties: [String: Any], metadata: [String: Any]?, actorId: String) async throws -> EntityDTO
    func updateEnforced(id: String, patch: [String: Any], actorId: String) async throws -> EntityDTO
    func deleteEnforced(id: String, actorId: String) async throws
}

public final class EntitiesService: EntitiesProviding {
    private let client: APIClientType

    public init(client: APIClientType) {
        self.client = client
    }

    public func get(id: String) async throws -> EntityDTO? {
        let items = [URLQueryItem(name: "id", value: id)]
        let req = APIRequest(method: .get, path: "/api/entities", queryItems: items)
        return try await client.send(req, decode: EntityDTO?.self)
    }

    public func list(workspaceTenantId: String, kind: String, filter: ListEntitiesFilter?, limit: Int?) async throws -> [EntityDTO] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "workspaceTenantId", value: workspaceTenantId),
            URLQueryItem(name: "kind", value: kind)
        ]
        if let filter {
            if let status = filter.status { items.append(URLQueryItem(name: "status", value: status)) }
            if let email = filter.email { items.append(URLQueryItem(name: "email", value: email)) }
            if let slug = filter.slug { items.append(URLQueryItem(name: "slug", value: slug)) }
        }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        let req = APIRequest(method: .get, path: "/api/entities", queryItems: items)
        return try await client.send(req, decode: [EntityDTO].self)
    }

    public func upsert(workspaceTenantId: String, kind: String, properties: [String: Any], metadata: [String: Any]?) async throws -> EntityDTO {
        var payload: [String: Any] = [
            "op": "upsert",
            "workspaceTenantId": workspaceTenantId,
            "kind": kind,
            "properties": properties
        ]
        if let metadata { payload["metadata"] = metadata }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = APIRequest(method: .post, path: "/api/entities", body: body)
        return try await client.send(req, decode: EntityDTO.self)
    }

    public func createEnforced(workspaceTenantId: String, kind: String, properties: [String: Any], metadata: [String: Any]?, actorId: String) async throws -> EntityDTO {
        var payload: [String: Any] = [
            "op": "createEnforced",
            "workspaceTenantId": workspaceTenantId,
            "kind": kind,
            "properties": properties,
            "actorId": actorId
        ]
        if let metadata { payload["metadata"] = metadata }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = APIRequest(method: .post, path: "/api/entities", body: body)
        return try await client.send(req, decode: EntityDTO.self)
    }

    public func updateEnforced(id: String, patch: [String: Any], actorId: String) async throws -> EntityDTO {
        let payload: [String: Any] = [
            "op": "updateEnforced",
            "id": id,
            "patch": patch,
            "actorId": actorId
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = APIRequest(method: .post, path: "/api/entities", body: body)
        return try await client.send(req, decode: EntityDTO.self)
    }

    public func deleteEnforced(id: String, actorId: String) async throws {
        let payload: [String: Any] = [
            "op": "deleteEnforced",
            "id": id,
            "actorId": actorId
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = APIRequest(method: .post, path: "/api/entities", body: body)
        _ = try await client.send(req)
    }
}


