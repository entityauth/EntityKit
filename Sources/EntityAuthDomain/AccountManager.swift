import Foundation
import Security
import EntityAuthCore
import EntityAuthNetworking

/// AccountManager manages multiple accounts on a device, storing account metadata
/// and tokens, and providing account switching functionality with cloud sync support.
public actor AccountManager: AccountManaging {
    private let storageKey = "entityauth:accounts:v1"
    private let userDefaults: UserDefaults
    private let facade: EntityAuthFacade
    private let apiClient: APIClientType
    private let baseURL: URL
    
    private struct StoredAccount: Codable, Sendable {
        let accountId: String
        let userId: String
        let email: String?
        let username: String?
        let imageUrl: String?
        let workspaceTenantId: String?
        let mode: AccountMode
        let organizations: [OrganizationSummary]
        let activeOrganizationId: String?
        let lastActiveAt: Date
        let hydratedOnThisDevice: Bool
    }
    
    public init(
        facade: EntityAuthFacade,
        apiClient: APIClientType,
        baseURL: URL,
        userDefaults: UserDefaults = .standard
    ) {
        self.facade = facade
        self.apiClient = apiClient
        self.baseURL = baseURL
        self.userDefaults = userDefaults
    }
    
    private func generateAccountId(userId: String, workspaceTenantId: String?) -> String {
        let tenant = workspaceTenantId ?? "default"
        return "user:\(userId):tenant:\(tenant)"
    }
    
    private func deriveMode(organizations: [OrganizationSummary]) -> AccountMode {
        if organizations.isEmpty {
            return .personal
        }
        // If there are orgs, it's team mode.
        return .team
    }
    
    private func loadAccounts() -> [StoredAccount] {
        guard let data = userDefaults.data(forKey: storageKey),
              let accounts = try? JSONDecoder().decode([StoredAccount].self, from: data) else {
            print("[AccountManager] loadAccounts() -> 0 (no data for key \(storageKey))")
            return []
        }
        print("[AccountManager] loadAccounts() -> \(accounts.count) accounts")
        return accounts
    }
    
    private func saveAccounts(_ accounts: [StoredAccount]) {
        if let data = try? JSONEncoder().encode(accounts) {
            userDefaults.set(data, forKey: storageKey)
        }
    }
    
    private func keychainKey(for accountId: String, tokenType: String) -> String {
        "com.entityauth.account.\(accountId).\(tokenType)"
    }
    
    private func loadTokenBundle(for accountId: String) throws -> TokenBundle? {
        guard let accessToken = try loadToken(for: accountId, tokenType: "accessToken") else {
            return nil
        }
        let refreshToken = try loadToken(for: accountId, tokenType: "refreshToken")
        let sessionId = try loadToken(for: accountId, tokenType: "sessionId")
        return TokenBundle(accessToken: accessToken, refreshToken: refreshToken, sessionId: sessionId)
    }
    
    private func saveTokenBundle(_ bundle: TokenBundle, for accountId: String) throws {
        try saveToken(for: accountId, tokenType: "accessToken", value: bundle.accessToken)
        try saveToken(for: accountId, tokenType: "refreshToken", value: bundle.refreshToken)
        try saveToken(for: accountId, tokenType: "sessionId", value: bundle.sessionId)
    }
    
    private func loadToken(for accountId: String, tokenType: String) throws -> String? {
        let key = keychainKey(for: accountId, tokenType: tokenType)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw EntityAuthError.keychain(status)
        }
        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw EntityAuthError.storage("Unable to decode token")
        }
        return string
    }
    
    private func saveToken(for accountId: String, tokenType: String, value: String?) throws {
        let key = keychainKey(for: accountId, tokenType: tokenType)
        if let value = value {
            guard let data = value.data(using: .utf8) else {
                throw EntityAuthError.storage("Unable to encode token")
            }
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data
            ]
            SecItemDelete(query as CFDictionary)
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw EntityAuthError.keychain(status)
            }
        } else {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw EntityAuthError.keychain(status)
            }
        }
    }
    
    private func fetchAccountData(accessToken: String) async throws -> BootstrapResponse {
        let req = APIRequest(
            method: .get,
            path: "/api/user/bootstrap",
            headers: ["Authorization": "Bearer \(accessToken)"]
        )
        return try await apiClient.send(req, decode: BootstrapResponse.self)
    }
    
    // MARK: - AccountManaging Protocol
    
    public func listAccounts() async throws -> [AccountSummary] {
        let stored = loadAccounts()
        print("[AccountManager] listAccounts() stored.count=\(stored.count)")
        return stored.map { stored in
            AccountSummary(
                id: stored.accountId,
                userId: stored.userId,
                email: stored.email,
                username: stored.username,
                imageUrl: stored.imageUrl.flatMap { URL(string: $0) },
                mode: stored.mode,
                organizations: stored.organizations,
                activeOrganizationId: stored.activeOrganizationId,
                workspaceTenantId: stored.workspaceTenantId,
                lastActiveAt: stored.lastActiveAt,
                hydratedOnThisDevice: stored.hydratedOnThisDevice
            )
        }
    }
    
    public func activeAccount() async throws -> AccountSummary? {
        let snapshot = await facade.currentSnapshot()
        guard let userId = snapshot.userId else {
            print("[AccountManager] activeAccount() -> nil (no userId in snapshot)")
            return nil
        }
        let accountId = generateAccountId(userId: userId, workspaceTenantId: apiClient.workspaceTenantId)
        let accounts = loadAccounts()
        guard let stored = accounts.first(where: { $0.accountId == accountId }) else {
            print("[AccountManager] activeAccount() -> nil (no stored account for id \(accountId), total=\(accounts.count))")
            return nil
        }
        print("[AccountManager] activeAccount() -> accountId=\(stored.accountId)")
        return AccountSummary(
            id: stored.accountId,
            userId: stored.userId,
            email: stored.email,
            username: stored.username,
            imageUrl: stored.imageUrl.flatMap { URL(string: $0) },
            mode: stored.mode,
            organizations: stored.organizations,
            activeOrganizationId: stored.activeOrganizationId,
            workspaceTenantId: stored.workspaceTenantId,
            lastActiveAt: stored.lastActiveAt,
            hydratedOnThisDevice: stored.hydratedOnThisDevice
        )
    }
    
    public func syncFromCurrentSession() async throws {
        let snapshot = await facade.currentSnapshot()
        guard let userId = snapshot.userId else {
            print("[AccountManager] syncFromCurrentSession() abort (no userId in snapshot)")
            return
        }
        
        let accountId = generateAccountId(userId: userId, workspaceTenantId: apiClient.workspaceTenantId)
        
        // Derive account data purely from the current facade snapshot.
        // This avoids extra network calls and ensures we never depend on a
        // potentially stale or mismatched access token when syncing accounts.
        let orgs = snapshot.organizations
        let mode = deriveMode(organizations: orgs)
        
        print("[AccountManager] syncFromCurrentSession() using snapshot accountId=\(accountId)")
        
        let stored = StoredAccount(
            accountId: accountId,
            userId: userId,
            email: snapshot.email,
            username: snapshot.username,
            imageUrl: snapshot.imageUrl,
            workspaceTenantId: snapshot.activeOrganization?.workspaceTenantId ?? orgs.first?.workspaceTenantId,
            mode: mode,
            organizations: orgs,
            activeOrganizationId: snapshot.activeOrganization?.orgId,
            lastActiveAt: Date(),
            hydratedOnThisDevice: snapshot.accessToken != nil
        )
        
        // Persist token bundle if we have one; failures here should not prevent
        // the account from appearing in the switcher UI.
        if let accessToken = snapshot.accessToken {
            do {
                let bundle = TokenBundle(
                    accessToken: accessToken,
                    refreshToken: snapshot.refreshToken,
                    sessionId: snapshot.sessionId
                )
                try saveTokenBundle(bundle, for: accountId)
            } catch {
                print("[AccountManager] syncFromCurrentSession() WARNING failed to save tokens: \(error)")
            }
        }
        
        var accounts = loadAccounts()
        if let index = accounts.firstIndex(where: { $0.accountId == accountId }) {
            accounts[index] = stored
        } else {
            accounts.append(stored)
        }
        saveAccounts(accounts)
        print("[AccountManager] syncFromCurrentSession() persisted account, total=\(accounts.count)")
    }
    
    public func switchAccount(id accountId: String) async throws {
        let accounts = loadAccounts()
        guard let account = accounts.first(where: { $0.accountId == accountId }) else {
            throw EntityAuthError.storage("Account not found")
        }
        
        // Load token bundle from keychain
        guard let bundle = try loadTokenBundle(for: accountId) else {
            throw EntityAuthError.storage("Token bundle not found for account")
        }
        
        // Apply tokens to facade directly (no casting needed)
        try await facade.applyTokens(
            accessToken: bundle.accessToken,
            refreshToken: bundle.refreshToken,
            sessionId: bundle.sessionId,
            userId: account.userId
        )
        
        // Update lastActiveAt
        var updatedAccounts = accounts
        if let index = updatedAccounts.firstIndex(where: { $0.accountId == accountId }) {
            updatedAccounts[index] = StoredAccount(
                accountId: account.accountId,
                userId: account.userId,
                email: account.email,
                username: account.username,
                imageUrl: account.imageUrl,
                workspaceTenantId: account.workspaceTenantId,
                mode: account.mode,
                organizations: account.organizations,
                activeOrganizationId: account.activeOrganizationId,
                lastActiveAt: Date(),
                hydratedOnThisDevice: true
            )
            saveAccounts(updatedAccounts)
        }
    }
    
    public func addAccount() async throws {
        // Stub: host app should provide implementation via callback or UI
        throw EntityAuthError.storage("addAccount must be implemented by the host app")
    }
    
    public func logoutAccount(id accountId: String) async throws {
        var accounts = loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.accountId == accountId }) else {
            return
        }
        
        // If this is the active account, logout via facade
        let snapshot = await facade.currentSnapshot()
        let activeAccountId = snapshot.userId.map { generateAccountId(userId: $0, workspaceTenantId: apiClient.workspaceTenantId) }
        if accountId == activeAccountId {
            try await facade.logout()
        }
        
        // Remove token bundle from keychain
        try? saveToken(for: accountId, tokenType: "accessToken", value: nil)
        try? saveToken(for: accountId, tokenType: "refreshToken", value: nil)
        try? saveToken(for: accountId, tokenType: "sessionId", value: nil)
        
        // Remove from storage
        accounts.remove(at: index)
        saveAccounts(accounts)
        
        // If we logged out the active account and there are others, switch to most recent
        if accountId == activeAccountId && !accounts.isEmpty {
            let sorted = accounts.sorted { $0.lastActiveAt > $1.lastActiveAt }
            try await switchAccount(id: sorted[0].accountId)
        }
    }
    
    public func logoutAll() async throws {
        // Logout active account via facade
        try await facade.logout()
        
        // Clear all tokens from keychain
        let accounts = loadAccounts()
        for account in accounts {
            try? saveToken(for: account.accountId, tokenType: "accessToken", value: nil)
            try? saveToken(for: account.accountId, tokenType: "refreshToken", value: nil)
            try? saveToken(for: account.accountId, tokenType: "sessionId", value: nil)
        }
        
        // Clear storage
        userDefaults.removeObject(forKey: storageKey)
    }
    
    // MARK: - Cloud Sync
    
    public func syncFromCloud() async throws {
        let snapshot = await facade.currentSnapshot()
        guard snapshot.userId != nil,
              let workspaceTenantId = apiClient.workspaceTenantId else {
            print("[AccountManager] syncFromCloud() abort (no userId or workspaceTenantId)")
            return
        }
        
        // Call Convex account_sets.getForCurrentUser
        // Note: This requires a Convex client. For now, we'll use a simple HTTP call to a Next.js route
        // In a full implementation, you'd use ConvexMobile client here
        
        let url = baseURL.appendingPathComponent("/api/account-sets/me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let accessToken = snapshot.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            print("[AccountManager] syncFromCloud() failed: HTTP \(response)")
            return
        }
        
        struct AccountSetResponse: Decodable {
            let accountIds: [String]
            let accounts: [AccountMetadata]
        }
        
        struct AccountMetadata: Decodable {
            let userId: String
            let email: String?
            let username: String?
            let imageUrl: String?
        }
        
        guard let accountSet = try? JSONDecoder().decode(AccountSetResponse.self, from: data) else {
            print("[AccountManager] syncFromCloud() failed to decode response")
            return
        }
        
        // Merge cloud accounts with local accounts
        var localAccounts = loadAccounts()
        let localAccountIds = Set(localAccounts.map { $0.accountId })
        
        for cloudAccount in accountSet.accounts {
            let accountId = generateAccountId(userId: cloudAccount.userId, workspaceTenantId: workspaceTenantId)
            
            if !localAccountIds.contains(accountId) {
                // Add cloud account as unhydrated (no tokens yet)
                let stored = StoredAccount(
                    accountId: accountId,
                    userId: cloudAccount.userId,
                    email: cloudAccount.email,
                    username: cloudAccount.username,
                    imageUrl: cloudAccount.imageUrl,
                    workspaceTenantId: workspaceTenantId,
                    mode: .personal, // Will be updated when hydrated
                    organizations: [],
                    activeOrganizationId: nil,
                    lastActiveAt: Date(),
                    hydratedOnThisDevice: false
                )
                localAccounts.append(stored)
            }
        }
        
        saveAccounts(localAccounts)
        print("[AccountManager] syncFromCloud() merged \(accountSet.accounts.count) accounts")
    }
    
    public func pushToCloud() async throws {
        let snapshot = await facade.currentSnapshot()
        guard snapshot.userId != nil,
              apiClient.workspaceTenantId != nil else {
            print("[AccountManager] pushToCloud() abort (no userId or workspaceTenantId)")
            return
        }
        
        // Call Convex account_sets.ensureForCurrentUser
        let url = baseURL.appendingPathComponent("/api/account-sets/ensure")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken = snapshot.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            print("[AccountManager] pushToCloud() failed: HTTP \(response)")
            return
        }
        
        print("[AccountManager] pushToCloud() success")
    }
}

extension BootstrapResponse.Organization {
    var asDomain: OrganizationSummary {
        OrganizationSummary(
            orgId: orgId,
            name: name,
            slug: slug,
            memberCount: memberCount,
            role: role,
            joinedAt: joinedAt,
            workspaceTenantId: workspaceTenantId
        )
    }
}
