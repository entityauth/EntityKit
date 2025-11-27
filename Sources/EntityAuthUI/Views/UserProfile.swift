import SwiftUI
import Foundation
import EntityAuthDomain
#if canImport(EntityDocsSwift)
import EntityDocsSwift
#endif
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Notification name for opening UserProfile to People section
extension Notification.Name {
    public static let openUserProfileToPeople = Notification.Name("openUserProfileToPeople")
    /// Notification posted when user wants to create a shared resource with a friend
    /// UserInfo: ["friendId": String, "resourceType": "channel" | "note" | "task" | "feed"]
    public static let createSharedResourceWithFriend = Notification.Name("createSharedResourceWithFriend")
}

/// Feature flags for user profile sections
public struct UserProfileFeatureFlags: Sendable {
    public let showPreferences: Bool
    public let showSecurity: Bool
    public let showDocs: Bool
    public let docsAppName: String? // e.g., "past", "entity-auth"
    
    public init(
        showPreferences: Bool = true,
        showSecurity: Bool = false,
        showDocs: Bool = false,
        docsAppName: String? = nil
    ) {
        self.showPreferences = showPreferences
        self.showSecurity = showSecurity
        self.showDocs = showDocs
        self.docsAppName = docsAppName
    }
    
    /// Default flags with only core sections enabled
    public static let production = UserProfileFeatureFlags()
    
    /// All sections enabled for development
    public static let development = UserProfileFeatureFlags(
        showPreferences: true,
        showSecurity: true
    )
}

public enum UserProfileModeIndicator: String, Sendable {
    case personal
    case work
    case both
}

public enum UserProfilePeopleMode: String, Sendable {
    case org
    case friends
    case both
}

public struct UserProfile: View {
    @State private var isPresented = false
    @State private var peopleInitialTab: PeopleTab? = nil
    @Environment(\.entityAuthProvider) private var provider
    @Environment(\.colorScheme) private var colorScheme
    private let featureFlags: UserProfileFeatureFlags
    private let modeIndicator: UserProfileModeIndicator?
    private let peopleMode: UserProfilePeopleMode

    public init(
        featureFlags: UserProfileFeatureFlags = .production,
        modeIndicator: UserProfileModeIndicator? = nil,
        peopleMode: UserProfilePeopleMode = .org
    ) {
        self.featureFlags = featureFlags
        self.modeIndicator = modeIndicator
        self.peopleMode = peopleMode
    }

    public var body: some View {
        UserButton(provider: provider, size: .standard) {
            isPresented = true
        }
        .accessibilityLabel("Open user profile")
        .sheet(isPresented: $isPresented) {
            UserProfileSheet(
                isPresented: $isPresented,
                featureFlags: featureFlags,
                modeIndicator: modeIndicator,
                peopleMode: peopleMode,
                peopleInitialTab: peopleInitialTab
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .openUserProfileToPeople)) { notification in
            // Handle notification to open People section
            if let tab = notification.userInfo?["tab"] as? PeopleTab {
                peopleInitialTab = tab
            }
            isPresented = true
        }
    }
}

/// A toolbar-ready user profile button that displays a user avatar and opens the profile sheet
public struct UserProfileToolbarButton: View {
    @State private var isPresented = false
    @State private var peopleInitialTab: PeopleTab? = nil
    @Environment(\.entityAuthProvider) private var provider
    private let featureFlags: UserProfileFeatureFlags
    private let modeIndicator: UserProfileModeIndicator?
    private let peopleMode: UserProfilePeopleMode
    
    public enum Style {
        case avatar  // Shows user's avatar with initial letter
        case icon    // Shows generic user icon (system image)
    }
    
    private let style: Style
    
    public init(
        style: Style = .avatar,
        featureFlags: UserProfileFeatureFlags = .production,
        modeIndicator: UserProfileModeIndicator? = nil,
        peopleMode: UserProfilePeopleMode = .org
    ) {
        self.style = style
        self.featureFlags = featureFlags
        self.modeIndicator = modeIndicator
        self.peopleMode = peopleMode
    }
    
    public var body: some View {
        Button(action: { isPresented = true }) {
            switch style {
            case .avatar:
                UserDisplay(provider: provider, variant: .avatarOnly)
            case .icon:
                Image("User", bundle: .module)
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 28, height: 28)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open user profile")
        .sheet(isPresented: $isPresented) {
            UserProfileSheet(
                isPresented: $isPresented,
                featureFlags: featureFlags,
                modeIndicator: modeIndicator,
                peopleMode: peopleMode,
                peopleInitialTab: peopleInitialTab
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .openUserProfileToPeople)) { notification in
            // Handle notification to open People section
            if let tab = notification.userInfo?["tab"] as? PeopleTab {
                peopleInitialTab = tab
            }
            isPresented = true
        }
    }
}

private enum ProfileSection: String, CaseIterable, Hashable {
    case account
    case organizations
    case invitations
    case preferences
    case security
    case deleteAccount
    case accounts
    case docs
    case changelog

    func title(modeIndicator: UserProfileModeIndicator? = nil) -> String {
        switch self {
        case .account: return "Account"
        case .organizations: return "Organizations"
        case .invitations:
            if let modeIndicator {
                switch modeIndicator {
                case .personal:
                    return "Invite friends"
                case .work:
                    return "Invite & join organizations"
                case .both:
                    return "People"
                }
            }
            return "People"
        case .preferences: return "Preferences"
        case .security: return "Security"
        case .deleteAccount: return "Delete Account"
        case .accounts: return "Switch account"
        case .docs: return "Documentation"
        case .changelog: return "Changelog"
        }
    }

    var iconName: String {
        switch self {
        case .account: return "User"
        case .organizations: return "Sitemap"
        case .invitations: return "PaperPlace"
        case .preferences: return "Settings"
        case .security: return "Lock"
        case .deleteAccount: return "DeleteX"
        case .accounts: return "AtSign"
        case .docs: return "File" // Documentation icon
        case .changelog: return "TimelineVertical" // Changelog icon
        }
    }
    
    /// Returns sections that should be visible based on feature flags and mode.
    /// Note: This is now only used for filtering - grouping is handled in the UI.
    /// - Parameters:
    ///   - flags: Feature flags controlling optional sections.
    ///   - modeIndicator: When `.personal`, we hide Organizations to keep the
    ///     sheet focused on the single personal space. Work/Hybrid modes still
    ///     expose organization management just like the web UI.
    static func visibleSections(
        with flags: UserProfileFeatureFlags,
        modeIndicator: UserProfileModeIndicator?
    ) -> [ProfileSection] {
        // This function is kept for compatibility but grouping is now handled in the UI
        var sections: [ProfileSection] = [.account, .invitations]

        // Only show Organizations when we are not explicitly in personal mode.
        if modeIndicator != .personal {
            sections.insert(.organizations, at: 1)
        }

        // Note: .accounts is NOT added to the menu sections - it appears in the toolbar
        // matching the web version behavior.

        if flags.showPreferences {
            sections.append(.preferences)
        }
        if flags.showSecurity {
            sections.append(.security)
        }
        // Delete account is always visible (no feature flag)
        sections.append(.deleteAccount)
        if flags.showDocs && flags.docsAppName != nil {
            sections.append(.docs)
            sections.append(.changelog)
        }
        
        return sections
    }
}

private struct UserProfileSheet: View {
    @Binding var isPresented: Bool
    @State private var selected: ProfileSection = .account
    @State private var path: [ProfileSection] = []
    @State private var isEditingAccount: Bool = false
    @State private var peopleBadgeCount: Int = 0
    #if os(iOS)
    @State private var selectedDetent: PresentationDetent = .large
    #endif
    let peopleInitialTab: PeopleTab?
    @Environment(\.entityAuthProvider) private var provider
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.profileImageUploader) private var profileImageUploader
    let featureFlags: UserProfileFeatureFlags
    let modeIndicator: UserProfileModeIndicator?
    let peopleMode: UserProfilePeopleMode
    
    init(
        isPresented: Binding<Bool>,
        featureFlags: UserProfileFeatureFlags,
        modeIndicator: UserProfileModeIndicator?,
        peopleMode: UserProfilePeopleMode,
        peopleInitialTab: PeopleTab? = nil
    ) {
        self._isPresented = isPresented
        self.featureFlags = featureFlags
        self.modeIndicator = modeIndicator
        self.peopleMode = peopleMode
        self.peopleInitialTab = peopleInitialTab
    }
    
    private var visibleSections: [ProfileSection] {
        ProfileSection.visibleSections(with: featureFlags, modeIndicator: modeIndicator)
    }
    
    private var modeBadge: (label: String, color: Color)? {
        guard let modeIndicator else { return nil }
        switch modeIndicator {
        case .personal:
            return ("Personal space", .green)
        case .work:
            return ("Work mode", .blue)
        case .both:
            return ("Hybrid mode", .pink)
        }
    }

    var body: some View {
        Group {
            #if os(iOS)
            contentIOS
                .presentationDetents([.medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
            #else
            contentMac.frame(minWidth: 700, minHeight: 480)
            #endif
        }
        .task {
            await fetchPeopleBadgeCount()
        }
        .onChange(of: isPresented) { oldValue, newValue in
            // Refresh badge count when sheet is presented
            if newValue {
                #if os(iOS)
                // Reset to large detent when sheet is presented
                selectedDetent = .large
                #endif
                Task {
                    await fetchPeopleBadgeCount()
                }
                // If we have an initial tab, select People section
                if peopleInitialTab != nil {
                    selected = .invitations
                }
            }
        }
    }
    
    /// Fetch badge count for People section (invitations + friend requests)
    /// This is handled entirely inside the SDK so host apps don't need to wire custom hooks
    @MainActor
    private func fetchPeopleBadgeCount() async {
        let snapshot = await provider.currentSnapshot()
        guard let userId = snapshot.userId else {
            peopleBadgeCount = 0
            return
        }
        
        let peopleService = provider.makePeopleService()
        
        do {
            // Fetch received invitations and friend requests in parallel
            async let receivedInvitesTask = peopleService.listReceivedInvitations(userId: userId, cursor: nil, limit: 100)
            async let receivedFriendReqsTask = peopleService.listReceivedFriendRequests(targetUserId: userId, cursor: nil, limit: 100)
            
            let (receivedInvites, receivedFriendReqs) = try await (receivedInvitesTask, receivedFriendReqsTask)
            
            // Count pending items
            let pendingInvites = receivedInvites.items.filter { $0.status == "pending" }.count
            let pendingFriends = receivedFriendReqs.items.filter { $0.status == "pending" }.count
            
            peopleBadgeCount = pendingInvites + pendingFriends
        } catch {
            // On error, just clear the badge; the People tab itself will show
            // a proper error banner when opened.
            peopleBadgeCount = 0
        }
    }

    // MARK: - iOS: Header + row buttons that push to detail views
    @ViewBuilder
    private var contentIOS: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    if let badge = modeBadge {
                        HStack {
                            Circle()
                                .fill(badge.color)
                                .frame(width: 10, height: 10)
                            Text(badge.label.uppercased())
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Account Group
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            sectionRow(.account)
                            if featureFlags.showPreferences {
                                sectionRow(.preferences)
                            }
                        }
                    }
                    
                    // People & Organizations Group
                    VStack(alignment: .leading, spacing: 12) {
                        Text(modeIndicator == .personal ? "People" : "Organizations")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            sectionRow(.invitations)
                            if modeIndicator != .personal {
                                sectionRow(.organizations)
                            }
                            if featureFlags.showSecurity {
                                sectionRow(.security)
                            }
                        }
                    }
                    
                    // Resources Group (if docs enabled)
                    if featureFlags.showDocs && featureFlags.docsAppName != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resources")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 12) {
                                sectionRow(.docs)
                                sectionRow(.changelog)
                            }
                        }
                    }
                    
                    // Account Actions Group (iOS)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account Actions")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            sectionRow(.deleteAccount)
                            signOutRow
                        }
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { 
                        isPresented = false 
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        path.append(.accounts)
                    }) {
                        Image("Users", bundle: .module)
                            .resizable()
                            .renderingMode(.original)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 36, height: 36)
                    .background {
                        #if os(iOS)
                        if #available(iOS 26.0, *) {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .glassEffect(.regular.interactive(true), in: .circle)
                        } else {
                            Circle()
                                .fill(.ultraThinMaterial)
                        }
                        #else
                        Circle()
                            .fill(.ultraThinMaterial)
                        #endif
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.2),
                                        Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .help("Switch account")
                }
            }
            .navigationDestination(for: ProfileSection.self) { section in
                SectionDetail(
                    section: section,
                    isPresented: $isPresented,
                    featureFlags: featureFlags,
                    modeIndicator: modeIndicator,
                    peopleMode: peopleMode,
                    peopleInitialTab: peopleInitialTab
                )
                    .toolbar {
                        #if os(iOS)
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { isPresented = false }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        #else
                        ToolbarItem(placement: .cancellationAction) {
                            Button(action: { isPresented = false }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        #endif
                    }
            }
        }
    }

    // MARK: - macOS: Sidebar + detail
    @ViewBuilder
    private var contentMac: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                // Sidebar with concentric glass layers
                sidebar
                    .frame(minWidth: 200, maxWidth: 240)
                    .frame(maxHeight: .infinity)
                    .padding(12)

                // Detail
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Close button overlay
            Button(action: { 
                isPresented = false 
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .background {
            #if os(macOS)
            if #available(macOS 15.0, *) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            #endif
        }
        .presentationSizing(.fitted)
    }

    private var sidebar: some View {
        // Full-height container with concentricity: Base → Glass → Content
        VStack(spacing: 0) {
            if let badge = modeBadge {
                HStack(spacing: 8) {
                    Circle()
                        .fill(badge.color)
                        .frame(width: 10, height: 10)
                    Text(badge.label.uppercased())
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Account Group
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 14)
                            .padding(.top, 4)
                        
                        VStack(spacing: 6) {
                            sectionButton(.account)
                            if featureFlags.showPreferences {
                                sectionButton(.preferences)
                            }
                        }
                    }
                    
                    // People & Organizations Group
                    VStack(alignment: .leading, spacing: 8) {
                        Text(modeIndicator == .personal ? "People" : "Organizations")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 14)
                            .padding(.top, 4)
                        
                        VStack(spacing: 6) {
                            sectionButton(.invitations)
                            if modeIndicator != .personal {
                                sectionButton(.organizations)
                            }
                            if featureFlags.showSecurity {
                                sectionButton(.security)
                            }
                        }
                    }
                    
                    // Resources Group (if docs enabled)
                    if featureFlags.showDocs && featureFlags.docsAppName != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Resources")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 14)
                                .padding(.top, 4)
                            
                            VStack(spacing: 6) {
                                sectionButton(.docs)
                                sectionButton(.changelog)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
            
            // Account Actions Footer
            VStack(alignment: .leading, spacing: 8) {
                Text("Account Actions")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                
                VStack(spacing: 6) {
                    sectionButton(.deleteAccount)
                    signOutButton
                }
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity)
        .background {
            // Concentricity Layer 1: Base gradient for depth
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(colorScheme == .dark ? 0.08 : 0.06),
                                Color.accentColor.opacity(colorScheme == .dark ? 0.03 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Concentricity Layer 2: Glass material on top
                #if os(macOS)
                if #available(macOS 15.0, *) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .glassEffect(.regular.interactive(false), in: .rect(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                #endif
            }
        }
        .overlay {
            // Concentricity Layer 3: Subtle gradient border for depth perception
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.2),
                            Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.1), radius: 12, x: 0, y: 4)
        .shadow(color: Color.accentColor.opacity(0.05), radius: 20, x: 0, y: 8)
    }

    private var detail: some View {
        VStack(spacing: 0) {
            // Toolbar at top
            HStack {
                Spacer()
                Button(action: {
                    selected = .accounts
                }) {
                    Image("Users", bundle: .module)
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .frame(width: 36, height: 36)
                .background {
                    #if os(macOS)
                    if #available(macOS 15.0, *) {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .glassEffect(.regular.interactive(true), in: .circle)
                    } else {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }
                    #endif
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.2),
                                    Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .help("Switch account")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            
            // Content
            ScrollView {
                switch selected {
                case .account:
                    accountDetailView
                case .organizations:
                    organizationsDetailView
                case .invitations:
                    invitationsDetailView
                case .preferences:
                    preferencesDetailView
                case .security:
                    securityDetailView
                case .deleteAccount:
                    deleteAccountDetailView
                case .accounts:
                    AccountSwitcherView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .docs:
                    docsDetailView
                case .changelog:
                    changelogDetailView
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionButton(_ section: ProfileSection) -> some View {
        Button(action: { 
            withAnimation(.easeInOut(duration: 0.2)) {
                selected = section 
            }
        }) {
            HStack(spacing: 10) {
                Group {
                    if section.iconName.hasPrefix("system:") {
                        Image(systemName: String(section.iconName.dropFirst(7)))
                            .font(.system(size: 16, weight: .medium))
                    } else {
                        Image(section.iconName, bundle: .module)
                            .resizable()
                            .renderingMode(.original)
                    }
                }
                .frame(width: 16, height: 16)
                Text(section.title(modeIndicator: modeIndicator))
                    .font(.system(.subheadline, design: .rounded, weight: selected == section ? .semibold : .medium))
                Spacer()
                
                // Badge for invitations section
                if section == .invitations && peopleBadgeCount > 0 {
                    Text("\(peopleBadgeCount)")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(selected == section ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.2))
                        )
                        .foregroundColor(selected == section ? .accentColor : .secondary)
                }
            }
            .foregroundStyle(selected == section ? Color.primary : Color.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            if selected == section {
                #if os(macOS)
                if #available(macOS 15.0, *) {
                    Capsule()
                        .fill(.regularMaterial)
                        .glassEffect(.regular.interactive(true), in: .capsule)
                } else {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.15))
                }
                #endif
            }
        }
    }
    
    private var signOutButton: some View {
        Button(action: {
            Task {
                try? await provider.logout()
                isPresented = false
            }
        }) {
            HStack(spacing: 10) {
                Image("PowerOff", bundle: .module)
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 16, height: 16)
                Text("Sign out")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            #if os(macOS)
            if #available(macOS 15.0, *) {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .glassEffect(.regular.interactive(true), in: .capsule)
            } else {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
            #endif
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.2),
                            Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
    
    // MARK: - Account Detail View
    
    private var accountDetailView: some View {
        AccountSectionView(
            provider: provider,
            isEditing: $isEditingAccount,
            onSave: { name, email in
                Task {
                    await saveAccountChanges(name: name, email: email)
                }
            },
            onImageSelected: { imageData in
                Task {
                    await saveProfileImage(imageData)
                }
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
    
    // MARK: - Organizations Detail View
    
    private var organizationsDetailView: some View {
        OrganizationsSectionView()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
    }
    
    // MARK: - Invitations Detail View
    
    private var invitationsDetailView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Invitations")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            
            PeopleView(mode: peopleMode, initialTab: peopleInitialTab)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
    
    // MARK: - Preferences Detail View
    
    private var preferencesDetailView: some View {
        PreferencesSectionView()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
    }
    
    // MARK: - Security Detail View
    
    private var securityDetailView: some View {
        SecuritySectionView()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
    }
    
    // MARK: - Delete Account Detail View
    
    private var deleteAccountDetailView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Delete Account")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.red)
            
            DeleteAccountContent()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
    
    // MARK: - Docs Detail View
    
    private var docsDetailView: some View {
        Group {
            #if canImport(EntityDocsSwift)
            if let appName = featureFlags.docsAppName {
                DocsView(appName: appName, isChangelog: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Documentation")
                        .font(.headline)
                    Text("No app name configured")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            #else
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Documentation")
                    .font(.headline)
                Text("EntityDocsSwift module not available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Changelog Detail View
    
    private var changelogDetailView: some View {
        Group {
            #if canImport(EntityDocsSwift)
            if let appName = featureFlags.docsAppName {
                DocsView(appName: appName, isChangelog: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Changelog")
                        .font(.headline)
                    Text("No app name configured")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            #else
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Changelog")
                    .font(.headline)
                Text("EntityDocsSwift module not available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Reusable rows (iOS)
    private func sectionRow(_ section: ProfileSection) -> some View {
        Button(action: { path.append(section) }) {
            HStack(spacing: 16) {
                // Section Info
                HStack(spacing: 12) {
                    Group {
                        if section.iconName.hasPrefix("system:") {
                            Image(systemName: String(section.iconName.dropFirst(7)))
                                .font(.system(size: 20, weight: .medium))
                        } else {
                            Image(section.iconName, bundle: .module)
                                .resizable()
                                .renderingMode(.original)
                        }
                    }
                    .frame(width: 20, height: 20)
                    
                    Text(section.title(modeIndicator: modeIndicator))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Badge for invitations section
                if section == .invitations && peopleBadgeCount > 0 {
                    Text("\(peopleBadgeCount)")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.2))
                        )
                        .foregroundColor(.accentColor)
                }
                
                // Chevron
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Group {
                    #if os(iOS)
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                    #elseif os(macOS)
                    if #available(macOS 15.0, *) {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                    #else
                    Capsule()
                        .fill(.ultraThinMaterial)
                    #endif
                }
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var switchAccountRow: some View {
        Button(action: { path.append(.accounts) }) {
            HStack(spacing: 16) {
                // Section Info
                HStack(spacing: 12) {
                    Image("AtSign", bundle: .module)
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 20, height: 20)
                    
                    Text("Switch account")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Chevron
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Group {
                    #if os(iOS)
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                    #elseif os(macOS)
                    if #available(macOS 15.0, *) {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                    #else
                    Capsule()
                        .fill(.ultraThinMaterial)
                    #endif
                }
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var signOutRow: some View {
        Button(action: {
            Task {
                try? await provider.logout()
                isPresented = false
            }
        }) {
            HStack(spacing: 12) {
                Image("PowerOff", bundle: .module)
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 18, height: 18)
                
                Text("Sign out")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                Group {
                    #if os(iOS)
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                    #else
                    Capsule()
                        .fill(.ultraThinMaterial)
                    #endif
                }
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.2),
                                Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Account Save Handlers
    
    private func saveAccountChanges(name: String, email: String) async {
        do {
            try await provider.setUsername(name)
            try await provider.setEmail(email)
            isEditingAccount = false
        } catch {
            print("[UserProfile] Failed to save account changes: \(error)")
        }
    }
    
    private func saveProfileImage(_ imageData: Data) async {
        guard let uploader = profileImageUploader else {
            print("[UserProfile] No profileImageUploader provided; skipping upload")
            return
        }
        do {
            let url = try await uploader(imageData)
            try await provider.setImageUrl(url.absoluteString)
        } catch {
            print("[UserProfile] Failed to upload/set profile image: \(error)")
        }
    }
}

// MARK: - Section Detail (for iOS navigation)
private struct SectionDetail: View {
    let section: ProfileSection
    @Environment(\.entityAuthProvider) private var provider
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.profileImageUploader) private var profileImageUploader
    @Binding var isPresented: Bool
    let featureFlags: UserProfileFeatureFlags
    let modeIndicator: UserProfileModeIndicator?
    let peopleMode: UserProfilePeopleMode
    let peopleInitialTab: PeopleTab?
    @State private var isEditingAccount: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch section {
                case .account:
                    AccountSectionView(
                        provider: provider,
                        isEditing: $isEditingAccount,
                        onSave: { name, email in
                            Task {
                                await saveAccountChanges(name: name, email: email)
                            }
                        },
                        onImageSelected: { imageData in
                            Task {
                                await saveProfileImage(imageData)
                            }
                        },
                        showsHeader: false
                    )
                    
                case .organizations:
                    OrganizationsSectionView(onDismiss: { isPresented = false }, showsHeader: false)
                    
                case .invitations:
                    PeopleView(mode: peopleMode, initialTab: peopleInitialTab)
                    
                case .preferences:
                    PreferencesSectionView(showsHeader: false)
                    
                case .security:
                    SecuritySectionView(showsHeader: false)
                    
                case .deleteAccount:
                    DeleteAccountContent()
                    
                case .accounts:
                    AccountSwitcherView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                    
                case .docs:
                    #if canImport(EntityDocsSwift)
                    if let appName = featureFlags.docsAppName {
                        DocsView(appName: appName, isChangelog: false)
                    } else {
                        Text("No app name configured")
                            .foregroundColor(.secondary)
                    }
                    #else
                    Text("EntityDocsSwift module not available")
                        .foregroundColor(.secondary)
                    #endif
                    
                case .changelog:
                    #if canImport(EntityDocsSwift)
                    if let appName = featureFlags.docsAppName {
                        DocsView(appName: appName, isChangelog: true)
                    } else {
                        Text("No app name configured")
                            .foregroundColor(.secondary)
                    }
                    #else
                    Text("EntityDocsSwift module not available")
                        .foregroundColor(.secondary)
                    #endif
                }
            }
            .padding()
        }
        .navigationTitle(section.title(modeIndicator: modeIndicator))
        .toolbar {
            if section == .account {
                ToolbarItem(placement: .automatic) {
                    Button(action: { isEditingAccount.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: isEditingAccount ? "xmark.circle.fill" : "pencil.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text(isEditingAccount ? "Cancel" : "Edit")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        }
                        .foregroundStyle(isEditingAccount ? Color.secondary : Color.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func saveAccountChanges(name: String, email: String) async {
        do {
            try await provider.setUsername(name)
            try await provider.setEmail(email)
            isEditingAccount = false
        } catch {
            print("[SectionDetail] Failed to save account changes: \(error)")
        }
    }
    
    private func saveProfileImage(_ imageData: Data) async {
        guard let uploader = profileImageUploader else {
            print("[SectionDetail] No profileImageUploader provided; skipping upload")
            return
        }
        do {
            let url = try await uploader(imageData)
            try await provider.setImageUrl(url.absoluteString)
        } catch {
            print("[SectionDetail] Failed to upload/set profile image: \(error)")
        }
    }
}
