import SwiftUI
import EntityAuthDomain

public struct AccountSwitcherView: View {
    @Environment(\.accountManager) private var accountManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var accounts: [AccountSummary] = []
    @State private var activeAccount: AccountSummary?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var isSwitching = false
    @State private var isLoggingOut = false
    @State private var isAddingAccount = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if let error = error {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    // Active Account Section
                    if let activeAccount = activeAccount {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Account")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            AccountRow(account: activeAccount, isActive: true)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    // Other Accounts Section
                    if !otherAccounts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Other Accounts")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            VStack(spacing: 8) {
                                ForEach(otherAccounts) { account in
                                    Button(action: {
                                        Task {
                                            await switchToAccount(account)
                                        }
                                    }) {
                                        AccountRow(account: account, isActive: false)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.secondary.opacity(0.05))
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isSwitching)
                                }
                            }
                        }
                    }
                    
                    // Actions Section
                    Divider()
                        .padding(.vertical, 8)

                    VStack(spacing: 8) {
                        // Inline add-account UI: toggle a lightweight embedded auth flow
                        if isAddingAccount {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Add another account")
                                        .font(.system(.headline, design: .rounded, weight: .semibold))
                                    Spacer()
                                    Button {
                                        isAddingAccount = false
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Text("Sign in to another Entity Auth account. After signing in, it will appear in this list so you can switch between accounts.")
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundColor(.secondary)

                                // Reuse the shared AuthGate inside the profile sheet instead of a new sheet.
                                AuthGate()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(10)
                        } else {
                            Button(action: {
                                isAddingAccount = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text("Add account")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: {
                            Task {
                                await logoutAll()
                            }
                        }) {
                            HStack {
                                Image(systemName: "power")
                                Text(isLoggingOut ? "Signing out..." : "Sign out of all accounts")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .foregroundColor(.red)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoggingOut)
                    }
                }
            }
            .padding()
        }
        .task {
            await loadAccounts()
        }
    }
    
    private var otherAccounts: [AccountSummary] {
        guard let activeAccount = activeAccount else {
            return accounts
        }
        return accounts.filter { $0.id != activeAccount.id }
    }
    
    private func loadAccounts() async {
        guard let accountManager = accountManager else {
            print("[AccountSwitcherView] No accountManager in environment")
            error = NSError(domain: "AccountSwitcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "Account manager not available"])
            isLoading = false
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            print("[AccountSwitcherView] loadAccounts() BEGIN")
            let allAccounts = try await accountManager.listAccounts()
            let active = try await accountManager.activeAccount()
            print("[AccountSwitcherView] loadAccounts() fetched accounts=\(allAccounts.count) activeId=\(active?.id ?? "nil")")
            
            await MainActor.run {
                self.accounts = allAccounts
                self.activeAccount = active
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            print("[AccountSwitcherView] loadAccounts() ERROR \(error)")
        }
    }
    
    private func switchToAccount(_ account: AccountSummary) async {
        guard let accountManager = accountManager else { return }
        
        // If account is not hydrated, we can't switch to it directly
        // The UI should trigger login flow instead (handled by host app)
        if !account.hydratedOnThisDevice {
            await MainActor.run {
                self.error = NSError(domain: "AccountSwitcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "Please sign in to this account first"])
            }
            return
        }
        
        isSwitching = true
        do {
            try await accountManager.switchAccount(id: account.id)
            await loadAccounts()
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
        isSwitching = false
    }
    
    private func addAccount() async {
        guard let accountManager = accountManager else { return }
        
        do {
            try await accountManager.addAccount()
            await loadAccounts()
        } catch {
            // addAccount throws by default - this is expected
            // Host app should handle opening login UI
        }
    }
    
    private func logoutAll() async {
        guard let accountManager = accountManager else { return }
        
        isLoggingOut = true
        do {
            try await accountManager.logoutAll()
            await loadAccounts()
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
        isLoggingOut = false
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: AccountSummary
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: isActive ? 48 : 40, height: isActive ? 48 : 40)
                
                if let imageUrl = account.imageUrl {
                    AsyncImage(url: imageUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: isActive ? 48 : 40, height: isActive ? 48 : 40)
                    .clipShape(Circle())
                } else {
                    Text(initial)
                        .font(.system(isActive ? .title3 : .body, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            
            // Account Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(account.username ?? account.email ?? "User")
                        .font(.system(isActive ? .headline : .body, design: .rounded, weight: isActive ? .semibold : .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    // Mode badge
                    Text(modeLabel)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    
                    // Hydration status badge
                    if !account.hydratedOnThisDevice {
                        Text("Sign in")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                if let email = account.email, account.username != nil {
                    Text(email)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Organizations
                if !account.organizations.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(account.organizations.prefix(3)) { org in
                            Text(org.name ?? org.slug ?? org.orgId)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                        if account.organizations.count > 3 {
                            Text("+\(account.organizations.count - 3)")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
    }
    
    private var initial: String {
        let text = account.username ?? account.email ?? "U"
        return String(text.prefix(1)).uppercased()
    }
    
    private var modeLabel: String {
        switch account.mode {
        case .personal:
            return "Personal"
        case .workspace:
            return "Workspace"
        case .hybrid:
            return "Hybrid"
        }
    }
}

