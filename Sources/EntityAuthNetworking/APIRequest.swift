import Foundation

public struct APIRequest: Sendable {
    public enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }

    public var method: Method
    public var path: String
    public var headers: [String: String]
    public var queryItems: [URLQueryItem]
    public var body: Data?
    public var requiresAuthentication: Bool

    public init(
        method: Method,
        path: String,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        requiresAuthentication: Bool = true
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.requiresAuthentication = requiresAuthentication
    }
}
