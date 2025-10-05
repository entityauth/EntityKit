import Foundation

public enum EntityAuthEnvironment: Sendable, Equatable {
    case production
    case staging
    case custom(URL)

    public var defaultBaseURL: URL {
        switch self {
        case .production:
            return URL(string: "https://entity-auth.com")!
        case .staging:
            return URL(string: "https://staging.entity-auth.com")!
        case let .custom(url):
            return url
        }
    }
}

public struct EntityAuthConfig: Sendable, Equatable {
    public var environment: EntityAuthEnvironment
    public var baseURL: URL
    public var workspaceTenantId: String?
    public var clientIdentifier: String
    public var userDefaultsSuiteName: String?

    public init(
        environment: EntityAuthEnvironment = .production,
        baseURL: URL? = nil,
        workspaceTenantId: String? = nil,
        clientIdentifier: String = "native",
        userDefaultsSuiteName: String? = nil
    ) {
        self.environment = environment
        self.baseURL = baseURL ?? environment.defaultBaseURL
        self.workspaceTenantId = workspaceTenantId
        self.clientIdentifier = clientIdentifier
        self.userDefaultsSuiteName = userDefaultsSuiteName
    }
}

public protocol BaseURLPersisting: Sendable {
    func loadBaseURL() -> URL?
    func save(baseURL: URL)
}

public struct UserDefaultsBaseURLStore: BaseURLPersisting, @unchecked Sendable {
    private let key = "com.entityauth.baseURL"
    private let defaults: UserDefaults

    public init(suiteName: String?) {
        if let suiteName {
            defaults = UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            defaults = .standard
        }
    }

    public func loadBaseURL() -> URL? {
        guard let stringValue = defaults.string(forKey: key) else { return nil }
        return URL(string: stringValue)
    }

    public func save(baseURL: URL) {
        defaults.set(baseURL.absoluteString, forKey: key)
    }
}
