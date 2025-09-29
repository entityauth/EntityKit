import Foundation
import EntityAuthCore
import EntityAuthNetworking

public protocol AuthProviding: Sendable {
    func register(request: RegisterRequest) async throws
    func login(request: LoginRequest) async throws -> LoginResponse
    func refresh() async throws -> RefreshResponse
    func logout(sessionId: String?, refreshToken: String?) async throws
}

public final class AuthService: AuthProviding, RefreshService {
    private let client: APIClientType

    public init(client: APIClientType) {
        self.client = client
    }

    public func register(request: RegisterRequest) async throws {
        let body = try JSONEncoder().encode(request)
        let apiRequest = APIRequest(method: .post, path: "/api/auth/register", headers: ["content-type": "application/json"], body: body, requiresAuthentication: false)
        _ = try await client.send(apiRequest)
    }

    public func login(request: LoginRequest) async throws -> LoginResponse {
        let body = try JSONEncoder().encode(request)
        let apiRequest = APIRequest(method: .post, path: "/api/auth/login", headers: ["content-type": "application/json"], body: body, requiresAuthentication: false)
        return try await client.send(apiRequest, decode: LoginResponse.self)
    }

    public func refresh() async throws -> RefreshResponse {
        let apiRequest = APIRequest(method: .post, path: "/api/auth/refresh", headers: ["content-type": "application/json"], requiresAuthentication: false)
        return try await client.send(apiRequest, decode: RefreshResponse.self)
    }

    public func logout(sessionId: String?, refreshToken: String?) async throws {
        var headers: [String: String] = ["content-type": "application/json"]
        if let refreshToken {
            headers["x-refresh-token"] = refreshToken
        }
        let payload: [String: String?] = [
            "sessionId": sessionId
        ]
        let body = try JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 })
        let apiRequest = APIRequest(method: .post, path: "/api/auth/logout", headers: headers, body: body, requiresAuthentication: false)
        _ = try await client.send(apiRequest)
    }
}
