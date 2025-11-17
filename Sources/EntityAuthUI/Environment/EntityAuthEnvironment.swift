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
    private let _setUsername: @Sendable (_ username: String) async throws -> Void
    private let _setEmail: @Sendable (_ email: String) async throws -> Void
    private let _setImageUrl: @Sendable (_ imageUrl: String) async throws -> Void
    private let _setOrgName: @Sendable (_ name: String) async throws -> Void
    private let _setOrgSlug: @Sendable (_ slug: String) async throws -> Void
    private let _setOrgImageUrl: @Sendable (_ imageUrl: String) async throws -> Void
    // Members
    private let _listMembers: @Sendable (_ orgId: String) async throws -> [OrgMemberDTO]
    private let _removeMember: @Sendable (_ orgId: String, _ userId: String) async throws -> Void
    private let _listWorkspaceMembers: @Sendable (_ workspaceTenantId: String) async throws -> [WorkspaceMemberDTO]
    // Invitations (New System)
    private let _inviteSearchUsers: @Sendable (_ q: String) async throws -> [(id: String, email: String?, username: String?)]
    private let _inviteStart: @Sendable (_ orgId: String, _ inviteeUserId: String, _ role: String) async throws -> (id: String, token: String, expiresAt: Double)
    private let _inviteAccept: @Sendable (_ token: String) async throws -> Void
    private let _inviteAcceptById: @Sendable (_ invitationId: String) async throws -> Void
    private let _inviteDecline: @Sendable (_ invitationId: String) async throws -> Void
    private let _inviteRevoke: @Sendable (_ invitationId: String) async throws -> Void
    private let _inviteResend: @Sendable (_ invitationId: String) async throws -> (token: String, expiresAt: Double)
    private let _invitationsReceived: @Sendable (_ cursor: String?, _ limit: Int) async throws -> (items: [Invitation], hasMore: Bool, nextCursor: String?)
    private let _invitationsSent: @Sendable (_ cursor: String?, _ limit: Int) async throws -> (items: [Invitation], hasMore: Bool, nextCursor: String?)
    private let _friendStart: @Sendable (_ targetUserId: String) async throws -> Void
    private let _friendAccept: @Sendable (_ requestId: String) async throws -> Void
    private let _friendDecline: @Sendable (_ requestId: String) async throws -> Void
    private let _friendCancel: @Sendable (_ requestId: String) async throws -> Void
    private let _friendsReceived: @Sendable (_ cursor: String?, _ limit: Int) async throws -> (items: [FriendRequest], hasMore: Bool, nextCursor: String?)
    private let _friendsSent: @Sendable (_ cursor: String?, _ limit: Int) async throws -> (items: [FriendRequest], hasMore: Bool, nextCursor: String?)
    private let _friendConnections: @Sendable () async throws -> [FriendConnection]
    private let _removeFriendConnection: @Sendable (_ friendId: String) async throws -> Void
    private let _deleteAccount: @Sendable () async throws -> Void

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
        activeOrg: @escaping @Sendable () async throws -> ActiveOrganization?,
        setUsername: @escaping @Sendable (_ username: String) async throws -> Void,
        setEmail: @escaping @Sendable (_ email: String) async throws -> Void,
        setImageUrl: @escaping @Sendable (_ imageUrl: String) async throws -> Void,
        setOrgName: @escaping @Sendable (_ name: String) async throws -> Void,
        setOrgSlug: @escaping @Sendable (_ slug: String) async throws -> Void,
        setOrgImageUrl: @escaping @Sendable (_ imageUrl: String) async throws -> Void,
        listMembers: @escaping @Sendable (_ orgId: String) async throws -> [OrgMemberDTO],
        removeMember: @escaping @Sendable (_ orgId: String, _ userId: String) async throws -> Void,
        listWorkspaceMembers: @escaping @Sendable (_ workspaceTenantId: String) async throws -> [WorkspaceMemberDTO],
        inviteSearchUsers: @escaping @Sendable (_ q: String) async throws -> [(id: String, email: String?, username: String?)],
        inviteStart: @escaping @Sendable (_ orgId: String, _ inviteeUserId: String, _ role: String) async throws -> (id: String, token: String, expiresAt: Double),
        inviteAccept: @escaping @Sendable (_ token: String) async throws -> Void,
        inviteAcceptById: @escaping @Sendable (_ invitationId: String) async throws -> Void,
        inviteDecline: @escaping @Sendable (_ invitationId: String) async throws -> Void,
        inviteRevoke: @escaping @Sendable (_ invitationId: String) async throws -> Void,
        inviteResend: @escaping @Sendable (_ invitationId: String) async throws -> (token: String, expiresAt: Double),
        invitationsReceived: @escaping @Sendable (_ cursor: String?, _ limit: Int) async throws -> (items: [Invitation], hasMore: Bool, nextCursor: String?),
        invitationsSent: @escaping @Sendable (_ cursor: String?, _ limit: Int) async throws -> (items: [Invitation], hasMore: Bool, nextCursor: String?),
        friendStart: @escaping @Sendable (_ targetUserId: String) async throws -> Void,
        friendAccept: @escaping @Sendable (_ requestId: String) async throws -> Void,
        friendDecline: @escaping @Sendable (_ requestId: String) async throws -> Void,
        friendCancel: @escaping @Sendable (_ requestId: String) async throws -> Void,
        friendsReceived: @escaping @Sendable (_ cursor: String?, _ limit: Int) async throws -> (items: [FriendRequest], hasMore: Bool, nextCursor: String?),
        friendsSent: @escaping @Sendable (_ cursor: String?, _ limit: Int) async throws -> (items: [FriendRequest], hasMore: Bool, nextCursor: String?),
        friendConnections: @escaping @Sendable () async throws -> [FriendConnection],
        removeFriendConnection: @escaping @Sendable (_ friendId: String) async throws -> Void,
        deleteAccount: @escaping @Sendable () async throws -> Void
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
        self._setUsername = setUsername
        self._setEmail = setEmail
        self._setImageUrl = setImageUrl
        self._setOrgName = setOrgName
        self._setOrgSlug = setOrgSlug
        self._setOrgImageUrl = setOrgImageUrl
        self._listMembers = listMembers
        self._removeMember = removeMember
        self._listWorkspaceMembers = listWorkspaceMembers
        self._inviteSearchUsers = inviteSearchUsers
        self._inviteStart = inviteStart
        self._inviteAccept = inviteAccept
        self._inviteAcceptById = inviteAcceptById
        self._inviteDecline = inviteDecline
        self._inviteRevoke = inviteRevoke
        self._inviteResend = inviteResend
        self._invitationsReceived = invitationsReceived
        self._invitationsSent = invitationsSent
        self._friendStart = friendStart
        self._friendAccept = friendAccept
        self._friendDecline = friendDecline
        self._friendCancel = friendCancel
        self._friendsReceived = friendsReceived
        self._friendsSent = friendsSent
        self._friendConnections = friendConnections
        self._removeFriendConnection = removeFriendConnection
        self._deleteAccount = deleteAccount
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
    public func setUsername(_ username: String) async throws { try await _setUsername(username) }
    public func setEmail(_ email: String) async throws { try await _setEmail(email) }
    public func setImageUrl(_ imageUrl: String) async throws { try await _setImageUrl(imageUrl) }
    public func setOrganizationName(_ name: String) async throws { try await _setOrgName(name) }
    public func setOrganizationSlug(_ slug: String) async throws { try await _setOrgSlug(slug) }
    public func setOrganizationImageUrl(_ imageUrl: String) async throws { try await _setOrgImageUrl(imageUrl) }
    public func listMembers(orgId: String) async throws -> [OrgMemberDTO] { try await _listMembers(orgId) }
    public func removeMember(orgId: String, userId: String) async throws { try await _removeMember(orgId, userId) }
    public func listWorkspaceMembers(workspaceTenantId: String) async throws -> [WorkspaceMemberDTO] { try await _listWorkspaceMembers(workspaceTenantId) }
    public func inviteSearchUsers(q: String) async throws -> [(id: String, email: String?, username: String?)] { try await _inviteSearchUsers(q) }
    public func inviteStart(orgId: String, inviteeUserId: String, role: String) async throws -> (id: String, token: String, expiresAt: Double) { try await _inviteStart(orgId, inviteeUserId, role) }
    public func inviteAccept(token: String) async throws { try await _inviteAccept(token) }
    public func inviteAcceptById(invitationId: String) async throws { try await _inviteAcceptById(invitationId) }
    public func inviteDecline(invitationId: String) async throws { try await _inviteDecline(invitationId) }
    public func inviteRevoke(invitationId: String) async throws { try await _inviteRevoke(invitationId) }
    public func inviteResend(invitationId: String) async throws -> (token: String, expiresAt: Double) { try await _inviteResend(invitationId) }
    public func invitationsReceived(cursor: String?, limit: Int) async throws -> (items: [Invitation], hasMore: Bool, nextCursor: String?) { try await _invitationsReceived(cursor, limit) }
    public func invitationsSent(cursor: String?, limit: Int) async throws -> (items: [Invitation], hasMore: Bool, nextCursor: String?) { try await _invitationsSent(cursor, limit) }
    public func friendStart(targetUserId: String) async throws { try await _friendStart(targetUserId) }
    public func friendAccept(requestId: String) async throws { try await _friendAccept(requestId) }
    public func friendDecline(requestId: String) async throws { try await _friendDecline(requestId) }
    public func friendCancel(requestId: String) async throws { try await _friendCancel(requestId) }
    public func friendRequestsReceived(cursor: String?, limit: Int) async throws -> (items: [FriendRequest], hasMore: Bool, nextCursor: String?) { try await _friendsReceived(cursor, limit) }
    public func friendRequestsSent(cursor: String?, limit: Int) async throws -> (items: [FriendRequest], hasMore: Bool, nextCursor: String?) { try await _friendsSent(cursor, limit) }
    public func listFriendConnections() async throws -> [FriendConnection] { try await _friendConnections() }
    public func removeFriendConnection(friendId: String) async throws { try await _removeFriendConnection(friendId) }
    public func deleteAccount() async throws { try await _deleteAccount() }
}

public extension AnyEntityAuthProvider {
    static func live(
        facade: EntityAuthFacade,
        config: EntityAuthConfig,
        onSwitchOrg: (@Sendable (_ orgId: String) async throws -> Void)? = nil,
        deleteAccount: (@Sendable () async throws -> Void)? = nil
    ) -> AnyEntityAuthProvider {
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
            switchOrg: { orgId in
                if let customSwitch = onSwitchOrg {
                    try await customSwitch(orgId)
                } else {
                    try await facade.switchOrg(orgId: orgId)
                }
            },
            createOrg: { name, slug, ownerId in try await facade.createOrganization(name: name, slug: slug, ownerId: ownerId) },
            activeOrg: { try await facade.activeOrganization() },
            setUsername: { value in try await facade.setUsername(value) },
            setEmail: { value in try await facade.setEmail(value) },
            setImageUrl: { value in try await facade.setImageUrl(value) },
            setOrgName: { value in try await facade.setOrganizationName(value) },
            setOrgSlug: { value in try await facade.setOrganizationSlug(value) },
            setOrgImageUrl: { value in try await facade.setOrganizationImageUrl(value) },
            listMembers: { orgId in try await facade.listOrganizationMembers(orgId: orgId) },
            removeMember: { orgId, userId in try await facade.removeOrganizationMember(orgId: orgId, userId: userId) },
            listWorkspaceMembers: { workspaceTenantId in try await facade.listWorkspaceMembers(workspaceTenantId: workspaceTenantId) },
            inviteSearchUsers: { q in try await facade.searchUsers(q: q) },
            inviteStart: { orgId, inviteeUserId, role in try await facade.startInvitation(orgId: orgId, inviteeUserId: inviteeUserId, role: role) },
            inviteAccept: { token in try await facade.acceptInvitation(token: token) },
            inviteAcceptById: { invitationId in try await facade.acceptInvitationById(invitationId: invitationId) },
            inviteDecline: { invitationId in try await facade.declineInvitation(invitationId: invitationId) },
            inviteRevoke: { invitationId in try await facade.revokeInvitation(invitationId: invitationId) },
            inviteResend: { invitationId in try await facade.resendInvitation(invitationId: invitationId) },
            invitationsReceived: { cursor, limit in try await facade.listInvitationsReceived(cursor: cursor, limit: limit) },
            invitationsSent: { cursor, limit in try await facade.listInvitationsSent(cursor: cursor, limit: limit) },
            friendStart: { targetUserId in try await facade.startFriendRequest(targetUserId: targetUserId) },
            friendAccept: { requestId in try await facade.acceptFriendRequest(requestId: requestId) },
            friendDecline: { requestId in try await facade.declineFriendRequest(requestId: requestId) },
            friendCancel: { requestId in try await facade.cancelFriendRequest(requestId: requestId) },
            friendsReceived: { cursor, limit in try await facade.listFriendRequestsReceived(cursor: cursor, limit: limit) },
            friendsSent: { cursor, limit in try await facade.listFriendRequestsSent(cursor: cursor, limit: limit) },
            friendConnections: { try await facade.listFriendConnections() },
            removeFriendConnection: { friendId in try await facade.removeFriendConnection(friendId: friendId) },
            deleteAccount: {
                if let customDelete = deleteAccount {
                    try await customDelete()
                } else {
                    try await facade.deleteAccount()
                }
            }
        )
    }

    static func preview(
        name: String = "Entity User",
        email: String = "user@example.com"
    ) -> AnyEntityAuthProvider {
        let orgs: [OrganizationSummary] = []
        actor State: Sendable {
            var orgs: [OrganizationSummary]
            var activeId: String?
            var snapshot: EntityAuthFacade.Snapshot
            init(orgs: [OrganizationSummary], activeId: String?, snapshot: EntityAuthFacade.Snapshot) {
                self.orgs = orgs
                self.activeId = activeId
                self.snapshot = snapshot
            }
            func current() -> EntityAuthFacade.Snapshot { snapshot }
            func organizations() -> [OrganizationSummary] { orgs }
            func switchOrg(id: String) { activeId = id }
            func activeOrg() -> ActiveOrganization? {
                guard let id = activeId, let found = orgs.first(where: { $0.orgId == id }) else { return nil }
                return ActiveOrganization(orgId: found.orgId, name: found.name, slug: found.slug, memberCount: found.memberCount, role: found.role, joinedAt: found.joinedAt, workspaceTenantId: found.workspaceTenantId, description: nil)
            }
        }
        let initialSnapshot = EntityAuthFacade.Snapshot(
            accessToken: nil,
            refreshToken: nil,
            sessionId: nil,
            userId: "user_123",
            username: name,
            email: email,
            organizations: orgs,
            activeOrganization: nil
        )
        let state = State(orgs: orgs, activeId: nil, snapshot: initialSnapshot)
        return AnyEntityAuthProvider(
            stream: { AsyncStream { continuation in Task { let snap = await state.current(); continuation.yield(snap); continuation.finish() } } },
            current: { await state.current() },
            organizations: { await state.organizations() },
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
            switchOrg: { id in await state.switchOrg(id: id) },
            createOrg: { _, _, _ in },
            activeOrg: { await state.activeOrg() },
            setUsername: { _ in },
            setEmail: { _ in },
            setImageUrl: { _ in },
            setOrgName: { _ in },
            setOrgSlug: { _ in },
            setOrgImageUrl: { _ in },
            listMembers: { _ in [] },
            removeMember: { _, _ in },
            listWorkspaceMembers: { _ in [] },
            inviteSearchUsers: { _ in [] },
            inviteStart: { _, _, _ in throw NSError(domain: "preview", code: -1) },
            inviteAccept: { _ in },
            inviteAcceptById: { _ in },
            inviteDecline: { _ in },
            inviteRevoke: { _ in },
            inviteResend: { _ in throw NSError(domain: "preview", code: -1) },
            invitationsReceived: { _, _ in ([], false, nil) },
            invitationsSent: { _, _ in ([], false, nil) },
            friendStart: { _ in },
            friendAccept: { _ in },
            friendDecline: { _ in },
            friendCancel: { _ in },
            friendsReceived: { _, _ in ([], false, nil) },
            friendsSent: { _, _ in ([], false, nil) },
            friendConnections: { [] },
            removeFriendConnection: { _ in },
            deleteAccount: { }
        )
    }

    static func preview(
        name: String = "Entity User",
        email: String = "user@example.com",
        organizations orgs: [OrganizationSummary],
        activeOrgId: String?
    ) -> AnyEntityAuthProvider {
        actor State: Sendable {
            var orgs: [OrganizationSummary]
            var activeId: String?
            var snapshot: EntityAuthFacade.Snapshot
            init(orgs: [OrganizationSummary], activeId: String?, snapshot: EntityAuthFacade.Snapshot) {
                self.orgs = orgs
                self.activeId = activeId
                self.snapshot = snapshot
            }
            func current() -> EntityAuthFacade.Snapshot { snapshot }
            func organizations() -> [OrganizationSummary] { orgs }
            func switchOrg(id: String) { activeId = id }
            func createOrg(name: String, slug: String, ownerId: String) {
                let now = Date().timeIntervalSince1970
                let new = OrganizationSummary(orgId: "org_\(Int.random(in: 1000...9999))", name: name, slug: slug, memberCount: 1, role: "owner", joinedAt: now, workspaceTenantId: nil)
                orgs.insert(new, at: 0)
                activeId = new.orgId
            }
            func activeOrg() -> ActiveOrganization? {
                guard let id = activeId, let found = orgs.first(where: { $0.orgId == id }) else { return nil }
                return ActiveOrganization(orgId: found.orgId, name: found.name, slug: found.slug, memberCount: found.memberCount, role: found.role, joinedAt: found.joinedAt, workspaceTenantId: found.workspaceTenantId, description: nil)
            }
        }
        let initialSnapshot = EntityAuthFacade.Snapshot(
            accessToken: nil,
            refreshToken: nil,
            sessionId: nil,
            userId: "user_123",
            username: name,
            email: email,
            organizations: orgs,
            activeOrganization: activeOrgId.flatMap { id in
                orgs.first(where: { $0.orgId == id }).map { o in
                    ActiveOrganization(orgId: o.orgId, name: o.name, slug: o.slug, memberCount: o.memberCount, role: o.role, joinedAt: o.joinedAt, workspaceTenantId: o.workspaceTenantId, description: nil)
                }
            }
        )
        let state = State(orgs: orgs, activeId: activeOrgId, snapshot: initialSnapshot)
        return AnyEntityAuthProvider(
            stream: { AsyncStream { continuation in Task { let snap = await state.current(); continuation.yield(snap); continuation.finish() } } },
            current: { await state.current() },
            organizations: { await state.organizations() },
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
            switchOrg: { id in await state.switchOrg(id: id) },
            createOrg: { name, slug, ownerId in await state.createOrg(name: name, slug: slug, ownerId: ownerId) },
            activeOrg: { await state.activeOrg() },
            setUsername: { _ in },
            setEmail: { _ in },
            setImageUrl: { _ in },
            setOrgName: { _ in },
            setOrgSlug: { _ in },
            setOrgImageUrl: { _ in },
            listMembers: { _ in [] },
            removeMember: { _, _ in },
            listWorkspaceMembers: { _ in [] },
            inviteSearchUsers: { _ in [] },
            inviteStart: { _, _, _ in throw NSError(domain: "preview", code: -1) },
            inviteAccept: { _ in },
            inviteAcceptById: { _ in },
            inviteDecline: { _ in },
            inviteRevoke: { _ in },
            inviteResend: { _ in throw NSError(domain: "preview", code: -1) },
            invitationsReceived: { _, _ in ([], false, nil) },
            invitationsSent: { _, _ in ([], false, nil) },
            friendStart: { _ in },
            friendAccept: { _ in },
            friendDecline: { _ in },
            friendCancel: { _ in },
            friendsReceived: { _, _ in ([], false, nil) },
            friendsSent: { _, _ in ([], false, nil) },
            friendConnections: { [] },
            removeFriendConnection: { _ in },
            deleteAccount: { }
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

// MARK: - Account Manager Environment

private struct AccountManagerKey: EnvironmentKey {
    static let defaultValue: (any AccountManaging)? = nil
}

public extension EnvironmentValues {
    var accountManager: (any AccountManaging)? {
        get { self[AccountManagerKey.self] }
        set { self[AccountManagerKey.self] = newValue }
    }
}

public extension View {
    func entityAccountManager(_ manager: some AccountManaging) -> some View {
        environment(\.accountManager, manager)
    }
}


// MARK: - Profile Image Upload Adapter

public typealias ProfileImageUploader = @Sendable (_ data: Data) async throws -> URL

private struct ProfileImageUploaderKey: EnvironmentKey {
    static let defaultValue: ProfileImageUploader? = nil
}

public extension EnvironmentValues {
    var profileImageUploader: ProfileImageUploader? {
        get { self[ProfileImageUploaderKey.self] }
        set { self[ProfileImageUploaderKey.self] = newValue }
    }
}

public extension View {
    func profileImageUploader(_ uploader: ProfileImageUploader?) -> some View {
        environment(\.profileImageUploader, uploader)
    }
}

// MARK: - App Preferences Context

/// Value container for application-specific feature preferences.
public struct AppPreferencesValue: Equatable, Sendable {
    public var chat: Bool
    public var notes: Bool
    public var tasks: Bool
    public var feed: Bool
    public var globalViewEnabled: Bool

    public init(chat: Bool, notes: Bool, tasks: Bool, feed: Bool, globalViewEnabled: Bool) {
        self.chat = chat
        self.notes = notes
        self.tasks = tasks
        self.feed = feed
        self.globalViewEnabled = globalViewEnabled
    }
}

public struct AppPreferencesContext: Sendable {
    public var value: AppPreferencesValue?
    public var isLoading: Bool
    public var isSaving: Bool
    public var onChange: (@Sendable (AppPreferencesValue) -> Void)?
    public var onSave: (@Sendable () async -> Void)?

    public init(
        value: AppPreferencesValue? = nil,
        isLoading: Bool = false,
        isSaving: Bool = false,
        onChange: (@Sendable (AppPreferencesValue) -> Void)? = nil,
        onSave: (@Sendable () async -> Void)? = nil
    ) {
        self.value = value
        self.isLoading = isLoading
        self.isSaving = isSaving
        self.onChange = onChange
        self.onSave = onSave
    }
}

private struct AppPreferencesContextKey: EnvironmentKey {
    static let defaultValue: AppPreferencesContext = .init()
}

public extension EnvironmentValues {
    var appPreferencesContext: AppPreferencesContext {
        get { self[AppPreferencesContextKey.self] }
        set { self[AppPreferencesContextKey.self] = newValue }
    }
}

public extension View {
    func appPreferencesContext(_ ctx: AppPreferencesContext) -> some View {
        environment(\.appPreferencesContext, ctx)
    }
}

// MARK: - App Preferences Installer (Driver-based)

/// A lightweight driver that knows how to load and save app preferences.
/// Consumer apps implement this protocol against their own persistence/backend.
public protocol AppPreferencesDriver: Sendable {
    func load() async throws -> AppPreferencesValue
    func save(_ value: AppPreferencesValue) async throws
}

private struct AppPreferencesInstaller: ViewModifier {
    let driver: AppPreferencesDriver
    @State private var value: AppPreferencesValue?
    @State private var isLoading: Bool = false
    @State private var isSaving: Bool = false

    func body(content: Content) -> some View {
        content
            .appPreferencesContext(
                AppPreferencesContext(
                    value: value,
                    isLoading: isLoading,
                    isSaving: isSaving,
                    onChange: { next in
                        Task { @MainActor in
                            value = next
                        }
                    },
                    onSave: {
                        let current = await MainActor.run { value }
                        guard let current else { return }
                        await MainActor.run { isSaving = true }
                        do {
                            try await driver.save(current)
                            // Reload after save to ensure UI reflects persisted state
                            let reloaded = try await driver.load()
                            await MainActor.run {
                                value = reloaded
                                isSaving = false
                            }
                        } catch {
                            // Intentionally ignore - consumer apps can observe/save errors elsewhere if desired
                            await MainActor.run {
                                isSaving = false
                            }
                        }
                    }
                )
            )
            .task {
                var shouldSkip = false
                await MainActor.run {
                    if value != nil || isLoading {
                        shouldSkip = true
                    } else {
                        isLoading = true
                    }
                }
                if shouldSkip { return }
                do {
                    let loaded = try await driver.load()
                    await MainActor.run {
                        value = loaded
                        isLoading = false
                    }
                } catch {
                    // Intentionally ignore to avoid crashing UI; UI will continue to show loading/empty state
                    await MainActor.run {
                        isLoading = false
                    }
                }
            }
    }
}

public extension View {
    /// Installs the App Preferences environment by delegating to a driver for load/save operations.
    func installAppPreferences(driver: AppPreferencesDriver) -> some View {
        modifier(AppPreferencesInstaller(driver: driver))
    }
}
