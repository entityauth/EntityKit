import Foundation
import EntityAuthCore
import EntityAuthNetworking

public protocol SessionsProviding: Sendable {
    func current() async throws -> UserSession
    func list(includeRevoked: Bool) async throws -> [UserSession]
    func byId(_ id: String) async throws -> UserSession
    func revoke(sessionId: String) async throws
    func revokeByUser(userId: String) async throws
}

public struct UserSession: Sendable, Equatable {
    public let id: String
    public let status: String
    public let createdAt: Date
    public let revokedAt: Date?

    public init(id: String, status: String, createdAt: Date, revokedAt: Date?) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
        self.revokedAt = revokedAt
    }
}

public final class SessionService: SessionsProviding {
    private let client: APIClientType

    public init(client: APIClientType) {
        self.client = client
    }

    public func current() async throws -> UserSession {
        let request = APIRequest(method: .get, path: "/api/session/current")
        let dto = try await client.send(request, decode: SessionSummaryDTO.self)
        return dto.asDomain
    }

    public func list(includeRevoked: Bool) async throws -> [UserSession] {
        let path = includeRevoked ? "/api/session/list?includeRevoked=true" : "/api/session/list"
        let request = APIRequest(method: .get, path: path)
        let response = try await client.send(request, decode: [SessionSummaryDTO].self)
        return response.map { $0.asDomain }
    }

    public func byId(_ id: String) async throws -> UserSession {
        let request = APIRequest(method: .get, path: "/api/session/by-id", queryItems: [URLQueryItem(name: "id", value: id)])
        let dto = try await client.send(request, decode: SessionSummaryDTO.self)
        return dto.asDomain
    }

    public func revoke(sessionId: String) async throws {
        let body = try JSONEncoder().encode(RevokeSessionRequest(sessionId: sessionId))
        let request = APIRequest(method: .post, path: "/api/session/revoke", body: body)
        _ = try await client.send(request)
    }

    public func revokeByUser(userId: String) async throws {
        let body = try JSONEncoder().encode(RevokeSessionsByUserRequest(userId: userId))
        let request = APIRequest(method: .post, path: "/api/session/revoke-by-user", body: body)
        _ = try await client.send(request)
    }
}

private extension SessionSummaryDTO {
    var asDomain: UserSession {
        UserSession(
            id: id,
            status: status,
            createdAt: Date(timeIntervalSince1970: createdAt / 1000),
            revokedAt: revokedAt.flatMap { Date(timeIntervalSince1970: $0 / 1000) }
        )
    }
}
