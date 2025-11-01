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
    private let _login: @Sendable (_ request: LoginRequest) async throws -> Void
    private let _register: @Sendable (_ request: RegisterRequest) async throws -> Void
    private let _passkeySignIn: @Sendable (_ rpId: String, _ origins: [String]) async throws -> LoginResponse
    private let _passkeySignUp: @Sendable (_ email: String, _ rpId: String, _ origins: [String]) async throws -> LoginResponse
    private let _rpId: @Sendable () -> String?
    private let _origins: @Sendable () -> [String]?
    private let _logout: @Sendable () async throws -> Void
    private let _switchOrg: @Sendable (_ orgId: String) async throws -> Void
    private let _createOrg: @Sendable (_ name: String, _ slug: String, _ ownerId: String) async throws -> Void
    private let _activeOrg: @Sendable () async throws -> ActiveOrganization?

    public init(
        stream: @escaping @Sendable () async -> AsyncStream<Snapshot>,
        current: @escaping @Sendable () async -> Snapshot,
        organizations: @escaping @Sendable () async throws -> Organizations,
        baseURL: @escaping @Sendable () -> URL,
        tenantId: @escaping @Sendable () -> String?,
        ssoCallbackURL: @escaping @Sendable () -> URL?,
        applyTokens: @escaping @Sendable (_ access: String, _ refresh: String?, _ sessionId: String?, _ userId: String?) async throws -> Void,
        login: @escaping @Sendable (_ request: LoginRequest) async throws -> Void,
        register: @escaping @Sendable (_ request: RegisterRequest) async throws -> Void,
        passkeySignIn: @escaping @Sendable (_ rpId: String, _ origins: [String]) async throws -> LoginResponse,
        passkeySignUp: @escaping @Sendable (_ email: String, _ rpId: String, _ origins: [String]) async throws -> LoginResponse,
        rpId: @escaping @Sendable () -> String?,
        origins: @escaping @Sendable () -> [String]?,
        logout: @escaping @Sendable () async throws -> Void,
        switchOrg: @escaping @Sendable (_ orgId: String) async throws -> Void,
        createOrg: @escaping @Sendable (_ name: String, _ slug: String, _ ownerId: String) async throws -> Void,
        activeOrg: @escaping @Sendable () async throws -> ActiveOrganization?
    ) {
        self._stream = stream
        self._current = current
        self._orgs = organizations
        self._baseURL = baseURL
        self._tenantId = tenantId
        self._ssoCallbackURL = ssoCallbackURL
        self._applyTokens = applyTokens
        self._login = login
        self._register = register
        self._passkeySignIn = passkeySignIn
        self._passkeySignUp = passkeySignUp
        self._rpId = rpId
        self._origins = origins
        self._logout = logout
        self._switchOrg = switchOrg
        self._createOrg = createOrg
        self._activeOrg = activeOrg
    }

    public func snapshotStream() async -> AsyncStream<Snapshot> { await _stream() }
    public func currentSnapshot() async -> Snapshot { await _current() }
    public func organizations() async throws -> Organizations { try await _orgs() }
    public func baseURL() -> URL { _baseURL() }
    public func workspaceTenantId() -> String? { _tenantId() }
    public func ssoCallbackURL() -> URL? { _ssoCallbackURL() }
    public func applyTokens(access: String, refresh: String?, sessionId: String?, userId: String?) async throws { try await _applyTokens(access, refresh, sessionId, userId) }
    public func login(request: LoginRequest) async throws { try await _login(request) }
    public func register(request: RegisterRequest) async throws { try await _register(request) }
    public func passkeySignIn(rpId: String, origins: [String]) async throws -> LoginResponse { try await _passkeySignIn(rpId, origins) }
    public func passkeySignUp(email: String, rpId: String, origins: [String]) async throws -> LoginResponse { try await _passkeySignUp(email, rpId, origins) }
    public func rpId() -> String? { _rpId() }
    public func origins() -> [String]? { _origins() }
    public func logout() async throws { try await _logout() }
    public func switchOrganization(id: String) async throws { try await _switchOrg(id) }
    public func createOrganization(name: String, slug: String, ownerId: String) async throws { try await _createOrg(name, slug, ownerId) }
    public func activeOrganization() async throws -> ActiveOrganization? { try await _activeOrg() }
}

public extension AnyEntityAuthProvider {
    static func live(facade: EntityAuthFacade, config: EntityAuthConfig) -> AnyEntityAuthProvider {
        return AnyEntityAuthProvider(
            stream: { await facade.snapshotStream() },
            current: { await facade.currentSnapshot() },
            organizations: { try await facade.organizations() },
            baseURL: { config.baseURL },
            tenantId: { config.workspaceTenantId },
            ssoCallbackURL: { config.ssoCallbackURL },
            applyTokens: { access, refresh, sessionId, userId in
                try await facade.applyTokens(accessToken: access, refreshToken: refresh, sessionId: sessionId, userId: userId)
            },
            login: { request in
                try await facade.login(request: request)
            },
            register: { request in
                try await facade.register(request: request)
            },
            passkeySignIn: { rpId, origins in
                try await facade.passkeySignIn(rpId: rpId, origins: origins)
            },
            passkeySignUp: { email, rpId, origins in
                try await facade.passkeySignUp(email: email, rpId: rpId, origins: origins)
            },
            rpId: { config.rpId },
            origins: { config.origins },
            logout: { try await facade.logout() },
            switchOrg: { orgId in try await facade.switchOrg(orgId: orgId) },
            createOrg: { name, slug, ownerId in try await facade.createOrganization(name: name, slug: slug, ownerId: ownerId) },
            activeOrg: { try await facade.activeOrganization() }
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
            applyTokens: { _, _, _, _ in },
            login: { _ in },
            register: { _ in },
            passkeySignIn: { _, _ in throw NSError(domain: "preview", code: -1) },
            passkeySignUp: { _, _, _ in throw NSError(domain: "preview", code: -1) },
            rpId: { nil },
            origins: { nil },
            logout: { },
            switchOrg: { _ in },
            createOrg: { _, _, _ in },
            activeOrg: { nil }
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


