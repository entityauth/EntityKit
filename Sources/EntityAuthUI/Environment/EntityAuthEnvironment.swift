import Foundation
import SwiftUI
import Combine
import EntityAuthDomain

public struct AnyEntityAuthProvider: Sendable {
    public typealias Snapshot = EntityAuthFacade.Snapshot
    public typealias Organizations = [OrganizationSummary]

    private let _stream: @Sendable () async -> AsyncStream<Snapshot>
    private let _current: @Sendable () async -> Snapshot
    private let _orgs: @Sendable () async throws -> Organizations
    private let _baseURL: @Sendable () -> URL
    private let _tenantId: @Sendable () -> String?
    private let _ssoCallbackURL: @Sendable () -> URL?
    private let _applyTokens: @Sendable (_ access: String, _ refresh: String?, _ sessionId: String?, _ userId: String?) async throws -> Void

    public init(
        stream: @escaping @Sendable () async -> AsyncStream<Snapshot>,
        current: @escaping @Sendable () async -> Snapshot,
        organizations: @escaping @Sendable () async throws -> Organizations,
        baseURL: @escaping @Sendable () -> URL,
        tenantId: @escaping @Sendable () -> String?,
        ssoCallbackURL: @escaping @Sendable () -> URL?,
        applyTokens: @escaping @Sendable (_ access: String, _ refresh: String?, _ sessionId: String?, _ userId: String?) async throws -> Void
    ) {
        self._stream = stream
        self._current = current
        self._orgs = organizations
        self._baseURL = baseURL
        self._tenantId = tenantId
        self._ssoCallbackURL = ssoCallbackURL
        self._applyTokens = applyTokens
    }

    public func snapshotStream() async -> AsyncStream<Snapshot> { await _stream() }
    public func currentSnapshot() async -> Snapshot { await _current() }
    public func organizations() async throws -> Organizations { try await _orgs() }
    public func baseURL() -> URL { _baseURL() }
    public func workspaceTenantId() -> String? { _tenantId() }
    public func ssoCallbackURL() -> URL? { _ssoCallbackURL() }
    public func applyTokens(access: String, refresh: String?, sessionId: String?, userId: String?) async throws { try await _applyTokens(access, refresh, sessionId, userId) }
}

public extension AnyEntityAuthProvider {
    static func live(facade: EntityAuthFacade, config: EntityAuthConfig) -> AnyEntityAuthProvider {
        AnyEntityAuthProvider(
            stream: { await facade.snapshotStream() },
            current: { await facade.currentSnapshot() },
            organizations: { try await facade.organizations() },
            baseURL: { config.baseURL },
            tenantId: { config.workspaceTenantId },
            ssoCallbackURL: { config.ssoCallbackURL },
            applyTokens: { access, refresh, sessionId, userId in
                try await facade.applyTokens(accessToken: access, refreshToken: refresh, sessionId: sessionId, userId: userId)
            }
        )
    }

    static func preview(
        name: String = "Entity User",
        email: String = "user@example.com"
    ) -> AnyEntityAuthProvider {
        let snapshot = EntityAuthFacade.Snapshot(
            accessToken: nil,
            refreshToken: nil,
            sessionId: nil,
            userId: "user_123",
            username: name,
            organizations: [],
            activeOrganization: nil
        )
        return AnyEntityAuthProvider(
            stream: { AsyncStream { continuation in continuation.yield(snapshot) } },
            current: { snapshot },
            organizations: { [] },
            baseURL: { URL(string: "https://example.com")! },
            tenantId: { nil },
            ssoCallbackURL: { nil },
            applyTokens: { _, _, _, _ in }
        )
    }
}

private struct EntityAuthProviderKey: EnvironmentKey {
    static let defaultValue: AnyEntityAuthProvider = .preview()
}

public extension EnvironmentValues {
    var entityAuthProvider: AnyEntityAuthProvider {
        get { self[EntityAuthProviderKey.self] }
        set { self[EntityAuthProviderKey.self] = newValue }
    }
}

public extension View {
    func entityAuthProvider(_ provider: AnyEntityAuthProvider) -> some View {
        environment(\.entityAuthProvider, provider)
    }
}


