import Combine
import ConvexMobile
import EntityAuthCore
import Foundation

public struct RealtimeOrganizationSummary: Sendable, Equatable {
    public let orgId: String
    public let name: String?
    public let slug: String?
    public let memberCount: Int?
    public let role: String
    public let joinedAt: Double
    public let workspaceTenantId: String?

    public init(
        orgId: String,
        name: String?,
        slug: String?,
        memberCount: Int?,
        role: String,
        joinedAt: Double,
        workspaceTenantId: String?
    ) {
        self.orgId = orgId
        self.name = name
        self.slug = slug
        self.memberCount = memberCount
        self.role = role
        self.joinedAt = joinedAt
        self.workspaceTenantId = workspaceTenantId
    }
}

public struct RealtimeActiveOrganization: Sendable, Equatable {
    public let orgId: String
    public let name: String?
    public let slug: String?
    public let memberCount: Int?
    public let role: String
    public let joinedAt: Double
    public let workspaceTenantId: String?
    public let description: String?

    public init(
        orgId: String,
        name: String?,
        slug: String?,
        memberCount: Int?,
        role: String,
        joinedAt: Double,
        workspaceTenantId: String?,
        description: String?
    ) {
        self.orgId = orgId
        self.name = name
        self.slug = slug
        self.memberCount = memberCount
        self.role = role
        self.joinedAt = joinedAt
        self.workspaceTenantId = workspaceTenantId
        self.description = description
    }
}

public enum RealtimeEvent: Sendable, Equatable {
    case username(String?)
    case organizations([RealtimeOrganizationSummary])
    case activeOrganization(RealtimeActiveOrganization?)
    case sessionInvalid
}

public protocol RealtimeSubscriptionHandling: Sendable {
    func start(userId: String, sessionId: String?) async
    func stop() async
    func update(baseURL: URL)
    func publisher() -> AnyPublisher<RealtimeEvent, Never>
}

public protocol ConvexSubscribing {
    func subscribe<T: Decodable & Sendable>(to: String, with: [String: Any], yielding: T.Type) -> AnyPublisher<T, Error>
}

public struct ConvexClientAdapter: ConvexSubscribing {
    public let client: ConvexClient
    public init(client: ConvexClient) { self.client = client }
    public func subscribe<T: Decodable & Sendable>(to: String, with: [String: Any], yielding: T.Type) -> AnyPublisher<T, Error> {
        let params: [String: (any ConvexEncodable)?] = with.mapValues { value in
            value as? (any ConvexEncodable)
        }
        return client
            .subscribe(to: to, with: params, yielding: T.self)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
}

public final class RealtimeCoordinator: RealtimeSubscriptionHandling, @unchecked Sendable {
    private var baseURL: URL
    private let fetchConvexURL: @Sendable (URL) async throws -> String
    private var convexClient: ConvexSubscribing?
    private let clientFactory: (String) -> ConvexSubscribing

    private let events = PassthroughSubject<RealtimeEvent, Never>()

    private var usernameCancellable: AnyCancellable?
    private var organizationsCancellable: AnyCancellable?
    private var sessionCancellable: AnyCancellable?

    public init(baseURL: URL, fetchConvexURL: @escaping @Sendable (URL) async throws -> String, clientFactory: @escaping (String) -> ConvexSubscribing = { url in
        ConvexClientAdapter(client: ConvexClient(deploymentUrl: url))
    }) {
        self.baseURL = baseURL
        self.fetchConvexURL = fetchConvexURL
        self.clientFactory = clientFactory
    }

    public func publisher() -> AnyPublisher<RealtimeEvent, Never> {
        events.eraseToAnyPublisher()
    }

    public func update(baseURL: URL) {
        if baseURL != self.baseURL {
            convexClient = nil
        }
        self.baseURL = baseURL
    }

    public func start(userId: String, sessionId: String?) async {
        guard let client = try? await ensureClient() else { return }
        usernameCancellable?.cancel()
        organizationsCancellable?.cancel()
        sessionCancellable?.cancel()

        usernameCancellable = client.subscribe(
            to: "auth/users.js:getById",
            with: ["id": userId],
            yielding: UserRecord?.self
        )
        .map { $0?.properties?.username }
        .replaceError(with: nil)
        .receive(on: DispatchQueue.main)
        .sink { [weak events] username in
            events?.send(.username(username))
        }

        organizationsCancellable = client.subscribe(
            to: "memberships.js:getOrganizationsForUser",
            with: ["userId": userId],
            yielding: [OrganizationRecord]?.self
        )
        .map { items -> [RealtimeOrganizationSummary] in
            let data = items ?? []
            return data.compactMap { item -> RealtimeOrganizationSummary? in
                guard let doc = item.organization, let id = doc._id else { return nil }
                let props = doc.properties ?? OrganizationRecord.Organization.Properties(name: nil, slug: nil, memberCount: nil, description: nil)
                return RealtimeOrganizationSummary(
                    orgId: id,
                    name: props.name,
                    slug: props.slug,
                    memberCount: props.memberCount,
                    role: item.role ?? "member",
                    joinedAt: item.joinedAt ?? 0,
                    workspaceTenantId: doc.workspaceTenantId
                )
            }
        }
        .replaceError(with: [])
        .receive(on: DispatchQueue.main)
        .sink { [weak events] organizations in
            events?.send(.organizations(organizations))
            events?.send(.activeOrganization(organizations.first.map { summary in
                RealtimeActiveOrganization(
                    orgId: summary.orgId,
                    name: summary.name,
                    slug: summary.slug,
                    memberCount: summary.memberCount,
                    role: summary.role,
                    joinedAt: summary.joinedAt,
                    workspaceTenantId: summary.workspaceTenantId,
                    description: nil
                )
            }))
        }

        if let sessionId {
            sessionCancellable = client.subscribe(
                to: "auth/sessions.js:getById",
                with: ["id": sessionId],
                yielding: SessionRecord?.self
            )
            .map { $0?.status }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak events] status in
                if status != "active" {
                    events?.send(.sessionInvalid)
                }
            }
        }
    }

    public func stop() async {
        usernameCancellable?.cancel()
        organizationsCancellable?.cancel()
        sessionCancellable?.cancel()
        usernameCancellable = nil
        organizationsCancellable = nil
        sessionCancellable = nil
        convexClient = nil
    }

    private func ensureClient() async throws -> ConvexSubscribing {
        if let convexClient { return convexClient }
        let convexURL = try await fetchConvexURL(baseURL)
        let client = clientFactory(convexURL)
        convexClient = client
        return client
    }
}

struct UserRecord: Decodable, Sendable {
    struct Properties: Decodable, Sendable { let username: String? }
    let properties: Properties?
}

struct OrganizationRecord: Decodable, Sendable {
    struct Organization: Decodable, Sendable {
        struct Properties: Decodable, Sendable {
            let name: String?
            let slug: String?
            let memberCount: Int?
            let description: String?
        }
        let _id: String?
        let properties: Properties?
        let workspaceTenantId: String?
    }
    let organization: Organization?
    let role: String?
    let joinedAt: Double?
}

struct SessionRecord: Decodable, Sendable {
    let status: String?
}
 