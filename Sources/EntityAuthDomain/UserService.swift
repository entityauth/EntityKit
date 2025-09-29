import Foundation
import EntityAuthCore
import EntityAuthNetworking

public protocol UsersProviding: Sendable {
    func me() async throws -> UserResponse
    func byUsername(_ username: String) async throws -> UserResponse?
    func byEmail(_ email: String) async throws -> UserResponse?
    func setUsername(_ username: String) async throws
    func checkUsername(_ value: String) async throws -> UsernameCheckResponse
}

public final class UserService: UsersProviding {
    private let client: APIClientType

    public init(client: APIClientType) {
        self.client = client
    }

    public func me() async throws -> UserResponse {
        let request = APIRequest(method: .get, path: "/api/user/me")
        return try await client.send(request, decode: UserResponse.self)
    }

    public func byUsername(_ username: String) async throws -> UserResponse? {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let request = APIRequest(method: .get, path: "/api/user/by-username", queryItems: [URLQueryItem(name: "username", value: encoded)])
        return try await client.send(request, decode: UserResponse?.self)
    }

    public func byEmail(_ email: String) async throws -> UserResponse? {
        let body = try JSONEncoder().encode(UserByEmailRequest(email: email))
        let request = APIRequest(method: .post, path: "/api/user/by-email", body: body)
        return try await client.send(request, decode: UserResponse?.self)
    }

    public func setUsername(_ username: String) async throws {
        let body = try JSONEncoder().encode(UsernameSetRequest(username: username))
        let request = APIRequest(method: .post, path: "/api/user/username/set", body: body)
        struct Response: Decodable { let ok: Bool }
        let response = try await client.send(request, decode: Response.self)
        guard response.ok else {
            throw EntityAuthError.network(statusCode: 400, message: "Failed to set username")
        }
    }

    public func checkUsername(_ value: String) async throws -> UsernameCheckResponse {
        let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        let request = APIRequest(method: .get, path: "/api/user/username/check", queryItems: [URLQueryItem(name: "value", value: encoded)])
        return try await client.send(request, decode: UsernameCheckResponse.self)
    }
}
