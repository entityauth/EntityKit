import Foundation
import Combine
import EntityAuthCore

public protocol APIClientType: Sendable {
    func send<T: Decodable>(_ request: APIRequest, decode type: T.Type) async throws -> T
    func send(_ request: APIRequest) async throws -> Data
    func updateConfiguration(_ update: (inout EntityAuthConfig) -> Void)
    var currentConfig: EntityAuthConfig { get }
    var workspaceTenantId: String? { get }
}

public final class APIClient: APIClientType {
    private var config: EntityAuthConfig
    private let authState: AuthState
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let refreshHandler: TokenRefreshHandling
    private let delegateQueue = DispatchQueue(label: "com.entityauth.APIClient", attributes: .concurrent)

    public init(
        config: EntityAuthConfig,
        authState: AuthState,
        urlSession: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        refreshHandler: TokenRefreshHandling
    ) {
        self.config = config
        self.authState = authState
        self.urlSession = urlSession
        self.decoder = decoder
        self.encoder = encoder
        self.refreshHandler = refreshHandler
    }

    public func send<T: Decodable>(_ request: APIRequest, decode type: T.Type) async throws -> T {
        let data = try await send(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw EntityAuthError.decoding(error)
        } catch {
            throw EntityAuthError.decoding(.typeMismatch(T.self, .init(codingPath: [], debugDescription: error.localizedDescription)))
        }
    }

    public func send(_ request: APIRequest) async throws -> Data {
        return try await perform(request: request, retryingOn401: true)
    }

    public func updateConfiguration(_ update: (inout EntityAuthConfig) -> Void) {
        update(&config)
    }

    public var currentConfig: EntityAuthConfig {
        config
    }

    public var workspaceTenantId: String? {
        config.workspaceTenantId
    }

    private func perform(request: APIRequest, retryingOn401: Bool) async throws -> Data {
        let urlRequest = try makeURLRequest(for: request)
        do {
            let (data, response) = try await urlSession.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EntityAuthError.invalidResponse
            }
            switch httpResponse.statusCode {
            case 200..<300:
                return data
            case 401:
                if retryingOn401 {
                    return try await refreshHandler.retryAfterRefreshing { [weak self] in
                        guard let self else { throw EntityAuthError.refreshFailed }
                        return try await self.perform(request: request, retryingOn401: false)
                    }
                }
                throw EntityAuthError.unauthorized
            default:
                let message = String(data: data, encoding: .utf8)
                throw EntityAuthError.network(statusCode: httpResponse.statusCode, message: message)
            }
        } catch let error as EntityAuthError {
            throw error
        } catch {
            throw EntityAuthError.transport(error)
        }
    }

    private func makeURLRequest(for request: APIRequest) throws -> URLRequest {
        guard var components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false) else {
            throw EntityAuthError.configurationMissingBaseURL
        }
        components.path = request.path.hasPrefix("/") ? request.path : "/" + request.path
        components.queryItems = request.queryItems.isEmpty ? nil : request.queryItems
        guard let url = components.url else {
            throw EntityAuthError.configurationMissingBaseURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        let bearerHeader = request.requiresAuthentication ? bearerAuthHeader() : ["content-type": "application/json"]
        for (key, value) in bearerHeader.merging(request.headers, uniquingKeysWith: { _, rhs in rhs }) {
            urlRequest.addValue(value, forHTTPHeaderField: key)
        }
        return urlRequest
    }

    private func bearerAuthHeader() -> [String: String] {
        let accessToken = authState.currentTokens.accessToken
        var header = ["content-type": "application/json"]
        if let accessToken {
            header["authorization"] = "Bearer \(accessToken)"
        }
        header["x-client"] = config.clientIdentifier
        if let workspaceTenantId = config.workspaceTenantId {
            header["x-workspace-tenant-id"] = workspaceTenantId
        }
        return header
    }
}

public protocol TokenRefreshHandling: Sendable {
    func retryAfterRefreshing(operation: @Sendable @escaping () async throws -> Data) async throws -> Data
}
