import SwiftUI
import EntityAuthDomain

// MARK: - Invitations Content (New System)
struct InvitationsContent: View {
    @Environment(\.entityAuthProvider) private var ea
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false
    @State private var received: [Invitation]? = nil
    @State private var sent: [Invitation]? = nil
    @State private var selectedInvitationTab: InvitationActions = .received
    @State private var receivedCursor: String?
    @State private var sentCursor: String?
    @State private var receivedHasMore = false
    @State private var sentHasMore = false
    @State private var error: String?
    @State private var searchText: String = ""
    @State private var foundUsers: [(id: String, email: String?, username: String?)] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var orgsICanInvite: [OrganizationSummary] = []
    @State private var orgNameForId: [String: String] = [:]
    @State private var invitationTokens: [String: String] = [:] // Map invitation ID to token for accept

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                inviteSearchSection
                listsSection
            }
            .padding()
        }
        .onAppear { Task { await loadAll() } }
        .task {
            let stream = await ea.snapshotStream()
            for await _ in stream {
                await loadAll()
            }
        }
    }

    private var inviteSearchSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invite a user")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            
            TextField("", text: $searchText, prompt: Text("Search users"))
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.08))
                )
                .frame(maxWidth: .infinity)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.08), lineWidth: 1)
                )
                .onChange(of: searchText) { _, newValue in
                    searchTask?.cancel()
                    let q = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if q.isEmpty {
                        foundUsers = []
                        return
                    }
                    guard q.count >= 2 else { return }
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                        if Task.isCancelled { return }
                        await search()
                    }
                }
            if !foundUsers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(foundUsers, id: \.id) { user in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.username ?? user.email ?? user.id)
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                if let email = user.email {
                                    Text(email)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Menu {
                                ForEach(orgsICanInvite, id: \.orgId) { org in
                                    Button("\(org.name ?? org.slug ?? org.orgId) (\(org.role))") {
                                        Task { await sendInvite(orgId: org.orgId, inviteeUserId: user.id) }
                                    }
                                }
                            } label: {
                                Label("Invite to...", systemImage: "paperplane.fill")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        capsuleBackground(tint: .accentColor)
                                    )
                                    .foregroundStyle(.white)
                            }
                            .disabled(orgsICanInvite.isEmpty)
                            .menuStyle(.borderlessButton)
                        }
                        .padding(12)
                        .background(
                            roundedBackground(cornerRadius: 14)
                        )
                    }
                }
            } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                roundedInfo("No users found. Try a different search term.")
            }
            
            if let error {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .background(
            roundedBackground(cornerRadius: 18)
        )
    }

    private var listsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invitations")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            
            if isLoading {
                ProgressView()
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 16) {
                    invitationTabPicker
                    
                    TabView(selection: $selectedInvitationTab) {
                        invitationPanel(
                            title: "Received",
                            subtitle: "Invites sent to you",
                            invitations: received,
                            isLoading: received == nil,
                            emptyText: "No invitations",
                            actions: .received,
                            hasMore: receivedHasMore,
                            loadMore: { await loadMoreReceived() }
                        )
                        .tag(InvitationActions.received)
                        
                        invitationPanel(
                            title: "Sent",
                            subtitle: "Invites you've issued",
                            invitations: sent,
                            isLoading: sent == nil,
                            emptyText: "No invitations sent",
                            actions: .sent,
                            hasMore: sentHasMore,
                            loadMore: { await loadMoreSent() }
                        )
                        .tag(InvitationActions.sent)
                    }
                    #if os(iOS)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    #else
                    .tabViewStyle(.automatic)
                    #endif
                }
            }
        }
    }

    private enum InvitationActions: Hashable { case received, sent }
    
    @ViewBuilder
    private var invitationTabPicker: some View {
        HStack(spacing: 0) {
            invitationTabButton(for: .received, title: "Received", count: received?.count ?? 0)
            invitationTabButton(for: .sent, title: "Sent", count: sent?.count ?? 0)
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.12))
        )
        .animation(.easeInOut(duration: 0.2), value: selectedInvitationTab)
    }
    
    @ViewBuilder
    private func invitationTabButton(for tab: InvitationActions, title: String, count: Int) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                selectedInvitationTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(selectedInvitationTab == tab ? Color.primary : Color.secondary)
                Text("\(count)")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(selectedInvitationTab == tab ? 0.15 : 0.08))
                    )
                    .foregroundStyle(selectedInvitationTab == tab ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            Group {
                if selectedInvitationTab == tab {
                    #if os(iOS)
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.18), lineWidth: 1)
                            )
                    } else {
                        Capsule()
                            .fill(Color.secondary.opacity(colorScheme == .dark ? 0.4 : 0.2))
                            .overlay(
                                Capsule()
                                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.25 : 0.12), lineWidth: 1)
                            )
                    }
                    #elseif os(macOS)
                    if #available(macOS 15.0, *) {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.2), lineWidth: 1)
                            )
                    } else {
                        Capsule()
                            .fill(Color.secondary.opacity(colorScheme == .dark ? 0.35 : 0.18))
                            .overlay(
                                Capsule()
                                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.1), lineWidth: 1)
                            )
                    }
                    #else
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                    #endif
                }
            }
        )
        .clipShape(Capsule())
    }
    
    @ViewBuilder
    private func invitationPanel(
        title: String,
        subtitle: String,
        invitations: [Invitation]?,
        isLoading: Bool,
        emptyText: String,
        actions: InvitationActions,
        hasMore: Bool,
        loadMore: @escaping () async -> Void
    ) -> some View {
        let items = invitations ?? []
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(items.count)")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.12))
                    )
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if items.isEmpty {
                roundedInfo(emptyText)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items, id: \.id) { inv in
                        invitationRow(inv, actions: actions)
                    }
                    
                    if hasMore {
                        Button("Load more...") {
                            Task { await loadMore() }
                        }
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(18)
        .background(roundedBackground(cornerRadius: 18))
    }

    @ViewBuilder
    private func invitationRow(_ inv: Invitation, actions: InvitationActions) -> some View {
        let expiresDate = Date(timeIntervalSince1970: inv.expiresAt / 1000)
        let isExpired = expiresDate < Date()
        
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(orgNameForId[inv.orgId] ?? inv.orgId)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    if isExpired {
                        Capsule()
                            .fill(Color.red.opacity(0.18))
                            .overlay(
                                Capsule()
                                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
                            )
                            .frame(height: 22)
                            .overlay(
                                Text("Expired")
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.red)
                            )
                    }
                }
                
                HStack(spacing: 8) {
                    roleBadge(inv.role)
                    statusBadge(inv.status)
                }
                
                if !isExpired {
                    Text("Expires \(expiresDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer(minLength: 12)
            
            switch actions {
            case .received:
                if inv.status == "pending" {
                    HStack(spacing: 8) {
                        Button("Accept") {
                            Task { await accept(inv.id) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        
                        Button("Decline") {
                            Task { await decline(inv.id) }
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                }
            case .sent:
                if inv.status == "pending" {
                    HStack(spacing: 8) {
                        Button("Revoke") {
                            Task { await revoke(inv.id) }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        Button("Resend") {
                            Task { await resend(inv.id) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                }
            }
        }
        .padding(16)
        .background(roundedBackground(cornerRadius: 16))
    }
    
    private func roleBadge(_ role: String) -> some View {
        Text(role.capitalized)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(colorScheme == .dark ? 0.28 : 0.12))
            )
            .foregroundStyle(.secondary)
    }
    
    private func statusBadge(_ status: String) -> some View {
        Text(status.capitalized)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor(status))
            )
            .foregroundStyle(statusTextColor(status))
    }

    @ViewBuilder
    private func roundedInfo(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(roundedBackground(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func roundedBackground(cornerRadius: CGFloat) -> some View {
        Group {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.secondary.opacity(colorScheme == .dark ? 0.28 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.1), radius: 8, x: 0, y: 4)
            }
            #elseif os(macOS)
            if #available(macOS 15.0, *) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.18), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.secondary.opacity(colorScheme == .dark ? 0.24 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.1), radius: 8, x: 0, y: 4)
            }
            #else
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
            #endif
        }
    }
    
    @ViewBuilder
    private func capsuleBackground(tint: Color) -> some View {
        let gradient = LinearGradient(
            colors: [
                tint.opacity(colorScheme == .dark ? 0.95 : 0.9),
                tint.opacity(colorScheme == .dark ? 0.7 : 0.65)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        Group {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                Capsule()
                    .fill(gradient)
                    .glassEffect(.regular.interactive(true), in: .capsule)
            } else {
                Capsule()
                    .fill(gradient)
                    .shadow(color: tint.opacity(0.35), radius: 6, x: 0, y: 4)
            }
            #elseif os(macOS)
            if #available(macOS 15.0, *) {
                Capsule()
                    .fill(gradient)
                    .glassEffect(.regular.interactive(true), in: .capsule)
            } else {
                Capsule()
                    .fill(gradient)
                    .shadow(color: tint.opacity(0.35), radius: 6, x: 0, y: 4)
            }
            #else
            Capsule()
                .fill(gradient)
            #endif
        }
    }

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        received = nil
        sent = nil
        do {
            let (receivedResult, sentResult) = try await (
                ea.invitationsReceived(cursor: nil, limit: 20),
                ea.invitationsSent(cursor: nil, limit: 20)
            )
            received = receivedResult.items
            receivedHasMore = receivedResult.hasMore
            receivedCursor = receivedResult.nextCursor
            sent = sentResult.items
            sentHasMore = sentResult.hasMore
            sentCursor = sentResult.nextCursor
            
            let orgs = try await ea.organizations()
            orgsICanInvite = orgs.filter { $0.role == "owner" || $0.role == "admin" }
            orgNameForId = Dictionary(uniqueKeysWithValues: orgs.map { org in
                (org.orgId, (org.name ?? org.slug ?? org.orgId))
            })
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func loadMoreReceived() async {
        guard let cursor = receivedCursor else { return }
        do {
            let result = try await ea.invitationsReceived(cursor: cursor, limit: 20)
            if received == nil {
                received = result.items
            } else {
                received?.append(contentsOf: result.items)
            }
            receivedHasMore = result.hasMore
            receivedCursor = result.nextCursor
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func loadMoreSent() async {
        guard let cursor = sentCursor else { return }
        do {
            let result = try await ea.invitationsSent(cursor: cursor, limit: 20)
            if sent == nil {
                sent = result.items
            } else {
                sent?.append(contentsOf: result.items)
            }
            sentHasMore = result.hasMore
            sentCursor = result.nextCursor
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func search() async {
        error = nil
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, q.count >= 2 else { return }
        do {
            let users = try await ea.inviteSearchUsers(q: q)
            foundUsers = users
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func sendInvite(orgId: String, inviteeUserId: String) async {
        error = nil
        do {
            let result = try await ea.inviteStart(orgId: orgId, inviteeUserId: inviteeUserId, role: "member")
            // Store token for this invitation (though we may not need it unless accepting)
            invitationTokens[result.id] = result.token
            await loadAll()
            searchText = "" // Clear search
            foundUsers = []
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func accept(_ id: String) async {
        error = nil
        do {
            try await ea.inviteAcceptById(invitationId: id)
            await loadAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func decline(_ id: String) async {
        error = nil
        do {
            try await ea.inviteDecline(invitationId: id)
            await loadAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func revoke(_ id: String) async {
        error = nil
        do {
            try await ea.inviteRevoke(invitationId: id)
            await loadAll()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func resend(_ id: String) async {
        error = nil
        do {
            let result = try await ea.inviteResend(invitationId: id)
            invitationTokens[id] = result.token
            await loadAll()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Styling Helpers
private func statusColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "pending": return Color.yellow.opacity(0.2)
    case "accepted": return Color.green.opacity(0.2)
    case "declined": return Color.orange.opacity(0.2)
    case "revoked": return Color.gray.opacity(0.2)
    case "expired": return Color.red.opacity(0.2)
    default: return Color.secondary.opacity(0.15)
    }
}

private func statusTextColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "pending": return .yellow
    case "accepted": return .green
    case "declined": return .orange
    case "revoked": return .gray
    case "expired": return .red
    default: return .secondary
    }
}

// MARK: - Mock Invitation Model
private struct MockInvitation: Identifiable {
    let id: String
    let organizationName: String
    let inviterName: String
    let role: String
    let invitedAt: Date
}

