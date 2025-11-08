import Foundation

public struct Invitation: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let orgId: String
    public let inviteeId: String
    public let inviterId: String
    public let role: String
    public let state: String
    public let respondedAt: Double?
}

public protocol InvitationsProviding: Sendable {
    func listReceived(for userId: String) async throws -> [Invitation]
    func listSent(by inviterId: String) async throws -> [Invitation]
    func send(orgId: String, inviteeId: String, role: String) async throws
    func accept(invitationId: String) async throws
    func decline(invitationId: String) async throws
    func revoke(invitationId: String) async throws
    func findUser(email: String?, username: String?) async throws -> (id: String, email: String?, username: String?)?
    func findUsers(q: String) async throws -> [(id: String, email: String?, username: String?)]
}

public final class InvitationService: InvitationsProviding {
    private let client: APIClientType
    
    public init(client: APIClientType) {
        self.client = client
    }

    public func findUser(email: String?, username: String?) async throws -> (id: String, email: String?, username: String?)? {
        var payload: [String: Any] = [:]
        if let e = email, !e.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["email"] = e
        }
        if let u = username, !u.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["username"] = u
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let req = APIRequest(method: .post, path: "/api/users/search", body: data)
        struct Raw: Decodable { let _id: String?; let properties: Props?; struct Props: Decodable { let email: String?; let username: String? } }
        let result = try await client.send(req, decode: Raw?.self)
        guard let id = result?._id else { return nil }
        return (id, result?.properties?.email, result?.properties?.username)
    }
  
  public func findUsers(q: String) async throws -> [(id: String, email: String?, username: String?)] {
    let body: [String: Any] = ["q": q]
    let data = try JSONSerialization.data(withJSONObject: body)
    let req = APIRequest(method: .post, path: "/api/users/search", body: data)
    struct Raw: Decodable { let _id: String?; let properties: Props?; struct Props: Decodable { let email: String?; let username: String? } }
    let rows = try await client.send(req, decode: [Raw].self)
    return rows.compactMap { r in
      guard let id = r._id else { return nil }
      return (id, r.properties?.email, r.properties?.username)
    }
  }
    
    public func listReceived(for userId: String) async throws -> [Invitation] {
        let req = APIRequest(
            method: .get,
            path: "/api/invitations",
            queryItems: [.init(name: "userId", value: userId)]
        )
        struct Raw: Decodable {
            let _id: String
            let properties: Properties
            struct Properties: Decodable {
                let orgId: String
                let inviteeId: String
                let inviterId: String
                let role: String?
                let state: String?
                let respondedAt: Double?
            }
        }
        let rows = try await client.send(req, decode: [Raw].self)
        return rows.map {
            Invitation(
                id: $0._id,
                orgId: $0.properties.orgId,
                inviteeId: $0.properties.inviteeId,
                inviterId: $0.properties.inviterId,
                role: $0.properties.role ?? "member",
                state: $0.properties.state ?? "pending",
                respondedAt: $0.properties.respondedAt
            )
        }
    }
    
    public func listSent(by inviterId: String) async throws -> [Invitation] {
        let req = APIRequest(
            method: .get,
            path: "/api/invitations",
            queryItems: [.init(name: "inviterId", value: inviterId)]
        )
        struct Raw: Decodable {
            let _id: String
            let properties: Properties
            struct Properties: Decodable {
                let orgId: String
                let inviteeId: String
                let inviterId: String
                let role: String?
                let state: String?
                let respondedAt: Double?
            }
        }
        let rows = try await client.send(req, decode: [Raw].self)
        return rows.map {
            Invitation(
                id: $0._id,
                orgId: $0.properties.orgId,
                inviteeId: $0.properties.inviteeId,
                inviterId: $0.properties.inviterId,
                role: $0.properties.role ?? "member",
                state: $0.properties.state ?? "pending",
                respondedAt: $0.properties.respondedAt
            )
        }
    }
    
    public func send(orgId: String, inviteeId: String, role: String) async throws {
        let body: [String: Any] = [
            "op": "send",
            "orgId": orgId,
            "inviteeId": inviteeId,
            "role": role
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/invitations", body: data)
        _ = try await client.send(req)
    }
    
    public func accept(invitationId: String) async throws {
        try await post(op: "accept", invitationId: invitationId)
    }
    
    public func decline(invitationId: String) async throws {
        try await post(op: "decline", invitationId: invitationId)
    }
    
    public func revoke(invitationId: String) async throws {
        try await post(op: "revoke", invitationId: invitationId)
    }
    
    private func post(op: String, invitationId: String) async throws {
        let body: [String: Any] = [
            "op": op,
            "invitationId": invitationId
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let req = APIRequest(method: .post, path: "/api/invitations", body: data)
        _ = try await client.send(req)
    }
}


