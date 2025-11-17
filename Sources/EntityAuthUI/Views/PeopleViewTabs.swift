import SwiftUI
import EntityAuthDomain

// Re-export domain-level friend connection so host apps can just `import EntityAuthUI`
public typealias FriendConnection = EntityAuthDomain.FriendConnection

// MARK: - People Hero Section

struct PeopleHeroSection: View {
    let mode: UserProfilePeopleMode
    @Environment(\.colorScheme) private var colorScheme
    
    private var supportsOrg: Bool { mode != .friends }
    private var supportsFriends: Bool { mode != .org }
    
    var body: some View {
        if supportsFriends && !supportsOrg {
            // Friendly design for personal account mode
            friendsHeroView
        } else if supportsOrg && !supportsFriends {
            // Professional design for workspace account mode
            orgHeroView
        } else {
            // Both modes - balanced design
            bothHeroView
        }
    }
    
    private var friendsHeroView: some View {
        VStack(spacing: 16) {
            // Avatar placeholders - friendly Memoji-style
            HStack(spacing: 12) {
                AvatarCircle(emoji: "👩", color: .pink)
                AvatarCircle(emoji: "👨", color: .blue)
                AvatarCircle(emoji: "👧", color: .yellow)
            }
            
            VStack(spacing: 8) {
                Text("Build Your Friend Circle")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Connect with the people who matter and share moments together.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Decorative icons
            HStack(spacing: 16) {
                DecorativeIcon(emoji: "❤️", color: .red)
                DecorativeIcon(emoji: "🎁", color: .yellow)
                DecorativeIcon(emoji: "💬", color: .blue)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
    
    private var orgHeroView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Professional icon
                Image(systemName: "person.3.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invite & Join Organizations")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text("Expand your workspace by inviting team members or joining existing organizations.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            HStack(spacing: 8) {
                // Team avatars
                HStack(spacing: -8) {
                    TeamAvatar()
                    TeamAvatar()
                    TeamAvatar()
                }
                
                Text("Connect with your team")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var bothHeroView: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect with People")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("Invite friends or team members to collaborate and share resources together.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Hero Section Helper Views

struct AvatarCircle: View {
    let emoji: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Text(emoji)
            .font(.system(size: 32))
            .frame(width: 64, height: 64)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(colorScheme == .dark ? 0.3 : 0.2),
                                color.opacity(colorScheme == .dark ? 0.4 : 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
}

struct DecorativeIcon: View {
    let emoji: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Text(emoji)
            .font(.system(size: 16))
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(color.opacity(colorScheme == .dark ? 0.3 : 0.15))
            )
    }
}

struct TeamAvatar: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Text("👤")
            .font(.system(size: 12))
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(Color.secondary.opacity(colorScheme == .dark ? 0.3 : 0.2))
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 2)
                    )
            )
    }
}

// MARK: - Find People Tab

struct FindPeopleTab: View {
    @ObservedObject var store: PeopleStore
    let mode: UserProfilePeopleMode
    
    @State private var searchText: String = ""
    @State private var orgOptions: [OrganizationSummary] = []
    @Environment(\.entityAuthProvider) private var provider
    
    private var supportsOrg: Bool { mode != .friends }
    private var supportsFriends: Bool { mode != .org }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Search input
                SearchInput(
                    text: $searchText,
                    isSearching: store.isSearching,
                    onSearchChanged: { text in
                        store.updateSearchQuery(text)
                    },
                    onSearchImmediate: {
                        store.performSearchImmediately()
                    }
                )
                
                // Show hero section when no search results, otherwise show results
                if !store.searchResults.isEmpty {
                    // Search results
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Results")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                        
                        ForEach(store.searchResults) { person in
                            PersonSearchResultCard(
                                person: person,
                                supportsOrg: supportsOrg,
                                supportsFriends: supportsFriends,
                                orgOptions: orgOptions,
                                isPendingFriend: store.pendingFriendTargets.contains(person.id),
                                onInviteToOrg: { orgId in
                                    Task {
                                        try? await store.startInvitation(
                                            orgId: orgId,
                                            inviteeUserId: person.id,
                                            role: "member"
                                        )
                                    }
                                },
                                onSendFriendRequest: {
                                    Task {
                                        try? await store.startFriendRequest(targetUserId: person.id)
                                    }
                                }
                            )
                        }
                    }
                } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isSearching {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No matches",
                        message: "Try a different search term"
                    )
                } else {
                    // Hero section as empty state
                    PeopleHeroSection(mode: mode)
                }
            }
            .padding()
        }
        .task {
            if supportsOrg {
                await loadOrgOptions()
            }
        }
    }
    
    private func loadOrgOptions() async {
        do {
            let orgs = try await provider.organizations()
            await MainActor.run {
                orgOptions = orgs
            }
        } catch {
            // Ignore errors
        }
    }
}

// MARK: - Search Input

struct SearchInput: View {
    @Binding var text: String
    let isSearching: Bool
    let onSearchChanged: (String) -> Void
    let onSearchImmediate: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search by username or email", text: $text)
                .textFieldStyle(.plain)
                .onChange(of: text) { _, newValue in
                    onSearchChanged(newValue)
                }
                .onSubmit {
                    onSearchImmediate()
                }
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Group {
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
                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.15 : 0.08))
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
                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.15 : 0.08))
                }
                #else
                Capsule()
                    .fill(Color.secondary.opacity(colorScheme == .dark ? 0.15 : 0.08))
                #endif
            }
        )
    }
}

// MARK: - Person Search Result Card

struct PersonSearchResultCard: View {
    let person: PersonSummary
    let supportsOrg: Bool
    let supportsFriends: Bool
    let orgOptions: [OrganizationSummary]
    /// Whether there is already a pending friend request involving this person
    let isPendingFriend: Bool
    let onInviteToOrg: (String) -> Void
    let onSendFriendRequest: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(person.username ?? person.email ?? person.id)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                
                if let email = person.email, email != person.username {
                    Text(email)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if supportsOrg && !orgOptions.isEmpty {
                Menu {
                    ForEach(orgOptions, id: \.orgId) { org in
                        Button(org.name ?? org.slug ?? org.orgId) {
                            onInviteToOrg(org.orgId)
                        }
                    }
                } label: {
                    Text("Invite")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                #if os(iOS)
                                if #available(iOS 26.0, *) {
                                    Capsule()
                                        .fill(.regularMaterial)
                                        .glassEffect(.regular.interactive(true), in: .capsule)
                                } else {
                                    Capsule()
                                        .fill(.quaternary)
                                }
                                #elseif os(macOS)
                                if #available(macOS 15.0, *) {
                                    Capsule()
                                        .fill(.regularMaterial)
                                        .glassEffect(.regular.interactive(true), in: .capsule)
                                } else {
                                    Capsule()
                                        .fill(.quaternary)
                                }
                                #else
                                Capsule()
                                    .fill(.quaternary)
                                #endif
                            }
                        )
                }
            }
            
            if supportsFriends {
                let disabled = isPendingFriend || person.alreadyFriends
                Button(action: {
                    if !disabled {
                        onSendFriendRequest()
                    }
                }) {
                    Text(disabled ? "Request Sent" : "Add Friend")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                #if os(iOS)
                                if #available(iOS 26.0, *) {
                                    Capsule()
                                        .fill(.regularMaterial)
                                        .glassEffect(.regular.interactive(true), in: .capsule)
                                } else {
                                    Capsule()
                                        .fill(.quaternary)
                                }
                                #elseif os(macOS)
                                if #available(macOS 15.0, *) {
                                    Capsule()
                                        .fill(.regularMaterial)
                                        .glassEffect(.regular.interactive(true), in: .capsule)
                                } else {
                                    Capsule()
                                        .fill(.quaternary)
                                }
                                #else
                                Capsule()
                                    .fill(.quaternary)
                                #endif
                            }
                        )
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        }
        .padding()
        .background(
            Group {
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.05))
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.05))
                }
                #else
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.05))
                #endif
            }
        )
    }
}

// MARK: - Sent Invitations Tab

struct SentInvitationsTab: View {
    @ObservedObject var store: PeopleStore
    
    var body: some View {
        InvitationList(
            invitations: store.sentInvitations,
            isLoading: store.invitationsLoading && store.sentInvitations.isEmpty,
            emptyText: "No invitations sent",
            hasMore: store.invitationsSentHasMore,
            onLoadMore: {
                await store.loadMoreSentInvitations()
            },
            actionType: .sent,
            store: store
        )
    }
}

// MARK: - Received Invitations Tab

struct ReceivedInvitationsTab: View {
    @ObservedObject var store: PeopleStore
    
    var body: some View {
        InvitationList(
            invitations: store.receivedInvitations,
            isLoading: store.invitationsLoading && store.receivedInvitations.isEmpty,
            emptyText: "No invitations received",
            hasMore: store.invitationsReceivedHasMore,
            onLoadMore: {
                await store.loadMoreReceivedInvitations()
            },
            actionType: .received,
            store: store,
            onAccept: { invitationId in
                Task {
                    try? await store.acceptInvitation(invitationId: invitationId)
                }
            },
            onDecline: { invitationId in
                Task {
                    try? await store.declineInvitation(invitationId: invitationId)
                }
            }
        )
    }
}

// MARK: - Sent Friend Requests Tab

struct SentFriendRequestsTab: View {
    @ObservedObject var store: PeopleStore
    
    var body: some View {
        FriendRequestList(
            requests: store.sentFriendRequests,
            isLoading: store.friendsLoading && store.sentFriendRequests.isEmpty,
            emptyText: "No friend requests sent",
            hasMore: store.friendsSentHasMore,
            onLoadMore: {
                await store.loadMoreSentFriendRequests()
            },
            actionType: .sent
        )
    }
}

// MARK: - Received Friend Requests Tab

struct ReceivedFriendRequestsTab: View {
    @ObservedObject var store: PeopleStore
    
    var body: some View {
        FriendRequestList(
            requests: store.receivedFriendRequests,
            isLoading: store.friendsLoading && store.receivedFriendRequests.isEmpty,
            emptyText: "No friend requests received",
            hasMore: store.friendsReceivedHasMore,
            onLoadMore: {
                await store.loadMoreReceivedFriendRequests()
            },
            actionType: .received,
            onAccept: { requestId in
                Task {
                    try? await store.acceptFriendRequest(requestId: requestId)
                }
            },
            onDecline: { requestId in
                Task {
                    try? await store.declineFriendRequest(requestId: requestId)
                }
            }
        )
    }
}

// MARK: - Friends Tab

struct FriendsTab: View {
    @ObservedObject var store: PeopleStore
    
    var body: some View {
        ScrollView {
            if store.connectionsLoading && store.friendConnections.isEmpty {
                ProgressView()
                    .padding()
            } else if store.friendConnections.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No friends yet",
                    message: "Start by searching for people and sending friend requests"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(store.friendConnections) { friend in
                        FriendConnectionCard(
                            friend: friend,
                            onRemove: {
                                Task {
                                    try? await store.removeFriendConnection(friendId: friend.id)
                                }
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .task {
            await store.loadFriendConnections()
        }
    }
}

// MARK: - Helper Views

struct InvitationList: View {
    let invitations: [Invitation]
    let isLoading: Bool
    let emptyText: String
    let hasMore: Bool
    let onLoadMore: () async -> Void
    let actionType: InvitationActionType
    let store: PeopleStore
    var onAccept: ((String) -> Void)? = nil
    var onDecline: ((String) -> Void)? = nil
    
    enum InvitationActionType {
        case sent
        case received
    }
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding()
            } else if invitations.isEmpty {
                EmptyStateView(icon: "envelope", title: emptyText, message: nil)
            } else {
                VStack(spacing: 12) {
                    ForEach(invitations) { invitation in
                        InvitationCard(
                            invitation: invitation,
                            actionType: actionType,
                            onAccept: onAccept.map { closure in { closure(invitation.id) } },
                            onDecline: onDecline.map { closure in { closure(invitation.id) } },
                            store: store
                        )
                    }
                    
                    if hasMore {
                        Button("Load More") {
                            Task { await onLoadMore() }
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
    }
}

struct FriendRequestList: View {
    let requests: [FriendRequest]
    let isLoading: Bool
    let emptyText: String
    let hasMore: Bool
    let onLoadMore: () async -> Void
    let actionType: FriendRequestActionType
    var onAccept: ((String) -> Void)? = nil
    var onDecline: ((String) -> Void)? = nil
    
    enum FriendRequestActionType {
        case sent
        case received
    }
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding()
            } else if requests.isEmpty {
                EmptyStateView(icon: "person.badge.plus", title: emptyText, message: nil)
            } else {
                VStack(spacing: 12) {
                    ForEach(requests) { request in
                        FriendRequestCard(
                            request: request,
                            actionType: actionType,
                            onAccept: onAccept.map { closure in { closure(request.id) } },
                            onDecline: onDecline.map { closure in { closure(request.id) } }
                        )
                    }
                    
                    if hasMore {
                        Button("Load More") {
                            Task { await onLoadMore() }
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.secondary)
            
            if let message = message {
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Invitation Card

struct InvitationCard: View {
    let invitation: Invitation
    let actionType: InvitationList.InvitationActionType
    let onAccept: (() -> Void)?
    let onDecline: (() -> Void)?
    @ObservedObject var store: PeopleStore
    @Environment(\.colorScheme) private var colorScheme
    
    private var isExpired: Bool {
        invitation.expiresAt < Date().timeIntervalSince1970
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with user/org info
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    // User/Org identifier
                    Text(displayIdentifier)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    // Badges row
                    HStack(spacing: 6) {
                        // Role badge
                        Badge(text: invitation.role.capitalized, style: .role)
                        
                        // Status badge
                        Badge(text: invitation.status.capitalized, style: .status(invitation.status))
                        
                        // Expired badge (if applicable)
                        if isExpired {
                            Badge(text: "Expired", style: .expired)
                        }
                    }
                    
                    // Additional context
                    if actionType == .sent {
                        Text("Org: \(invitation.orgId)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else if let createdBy = invitation.createdBy {
                        Text("Invited by \(createdBy)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Action buttons
            if invitation.status == "pending" {
                HStack(spacing: 8) {
                    if actionType == .sent {
                        // Revoke button
                        Button(action: {
                            Task {
                                try? await store.revokeInvitation(invitationId: invitation.id)
                            }
                        }) {
                            Text("Revoke")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                )
                        }
                        .buttonStyle(.plain)
                        
                        // Resend button
                        Button(action: {
                            Task {
                                try? await store.resendInvitation(invitationId: invitation.id)
                            }
                        }) {
                            Text("Resend")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Accept button
                        Button(action: {
                            onAccept?()
                        }) {
                            Text("Accept")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        // Decline button
                        Button(action: {
                            onDecline?()
                        }) {
                            Text("Decline")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(
            Group {
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
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.15 : 0.08))
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
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.15 : 0.08))
                }
                #else
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.1))
                #endif
            }
        )
    }
    
    private var displayIdentifier: String {
        switch actionType {
        case .sent:
            return invitation.inviteeUserId
        case .received:
            return invitation.orgId
        }
    }
}

// MARK: - Badge Component

struct Badge: View {
    let text: String
    let style: BadgeStyle
    @Environment(\.colorScheme) private var colorScheme
    
    enum BadgeStyle {
        case role
        case status(String)
        case expired
        
        func backgroundColor(colorScheme: ColorScheme) -> Color {
            switch self {
            case .role:
                return .secondary.opacity(colorScheme == .dark ? 0.28 : 0.12)
            case .status(let status):
                return statusColor(for: status).opacity(colorScheme == .dark ? 0.3 : 0.15)
            case .expired:
                return .red.opacity(colorScheme == .dark ? 0.3 : 0.15)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .role:
                return .secondary
            case .status(let status):
                return statusColor(for: status)
            case .expired:
                return .red
            }
        }
        
        private func statusColor(for status: String) -> Color {
            switch status.lowercased() {
            case "pending":
                return .yellow
            case "accepted":
                return .green
            case "declined":
                return .orange
            case "revoked":
                return .gray
            case "expired":
                return .red
            default:
                return .secondary
            }
        }
    }
    
    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(style.backgroundColor(colorScheme: colorScheme))
            )
            .foregroundStyle(style.foregroundColor)
    }
}

struct FriendRequestCard: View {
    let request: FriendRequest
    let actionType: FriendRequestList.FriendRequestActionType
    let onAccept: (() -> Void)?
    let onDecline: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    
    private var displayName: String {
        switch actionType {
        case .sent:
            return request.targetUserUsername
                ?? request.targetUserEmail
                ?? request.targetUserId
        case .received:
            return request.requesterUsername
                ?? request.requesterEmail
                ?? request.requesterId
        }
    }
    
    private var statusText: String {
        request.status.capitalized
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    
                    Text(statusText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if request.status == "pending" {
                    switch actionType {
                    case .sent:
                        Button(role: .destructive) {
                            onDecline?()
                        } label: {
                            Text("Cancel")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                    case .received:
                        HStack(spacing: 8) {
                            Button {
                                onAccept?()
                            } label: {
                                Text("Accept")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button(role: .destructive) {
                                onDecline?()
                            } label: {
                                Text("Decline")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            Group {
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                }
                #else
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                #endif
            }
        )
    }
}

struct FriendConnectionCard: View {
    let friend: FriendConnection
    let onRemove: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.username ?? friend.email ?? friend.id)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    
                    if let email = friend.email {
                        Text(email)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Remove", role: .destructive) {
                    onRemove()
                }
                .font(.system(.caption, design: .rounded))
            }
            
            // Action buttons for creating shared resources
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ActionButton(
                        icon: "bubble.left.and.bubble.right",
                        label: "Channel",
                        action: {
                            NotificationCenter.default.post(
                                name: .createSharedResourceWithFriend,
                                object: nil,
                                userInfo: [
                                    "friendId": friend.id,
                                    "resourceType": "channel"
                                ]
                            )
                        }
                    )
                    
                    ActionButton(
                        icon: "note.text",
                        label: "Note",
                        action: {
                            NotificationCenter.default.post(
                                name: .createSharedResourceWithFriend,
                                object: nil,
                                userInfo: [
                                    "friendId": friend.id,
                                    "resourceType": "note"
                                ]
                            )
                        }
                    )
                }
                
                HStack(spacing: 8) {
                    ActionButton(
                        icon: "checklist",
                        label: "Tasks",
                        action: {
                            NotificationCenter.default.post(
                                name: .createSharedResourceWithFriend,
                                object: nil,
                                userInfo: [
                                    "friendId": friend.id,
                                    "resourceType": "task"
                                ]
                            )
                        }
                    )
                    
                    ActionButton(
                        icon: "newspaper",
                        label: "Feed",
                        action: {
                            NotificationCenter.default.post(
                                name: .createSharedResourceWithFriend,
                                object: nil,
                                userInfo: [
                                    "friendId": friend.id,
                                    "resourceType": "feed"
                                ]
                            )
                        }
                    )
                }
            }
        }
        .padding()
        .background(
            Group {
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.05))
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.05))
                }
                #else
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.05))
                #endif
            }
        )
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Group {
                    #if os(iOS)
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.quaternary)
                    }
                    #elseif os(macOS)
                    if #available(macOS 15.0, *) {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.quaternary)
                    }
                    #else
                    Capsule()
                        .fill(.quaternary)
                    #endif
                }
            )
        }
        .buttonStyle(.plain)
    }
}

