import SwiftUI
import EntityAuthDomain
#if canImport(EntityDocsSwift)
import EntityDocsSwift
#endif
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Feature flags for user profile sections
public struct UserProfileFeatureFlags: Sendable {
    public let showPreferences: Bool
    public let showSecurity: Bool
    public let showDeleteAccount: Bool
    public let showDocs: Bool
    public let docsAppName: String? // e.g., "past", "entity-auth"
    
    public init(
        showPreferences: Bool = false,
        showSecurity: Bool = false,
        showDeleteAccount: Bool = false,
        showDocs: Bool = false,
        docsAppName: String? = nil
    ) {
        self.showPreferences = showPreferences
        self.showSecurity = showSecurity
        self.showDeleteAccount = showDeleteAccount
        self.showDocs = showDocs
        self.docsAppName = docsAppName
    }
    
    /// Default flags with only core sections enabled
    public static let production = UserProfileFeatureFlags()
    
    /// All sections enabled for development
    public static let development = UserProfileFeatureFlags(
        showPreferences: true,
        showSecurity: true,
        showDeleteAccount: true
    )
}

public struct UserProfile: View {
    @State private var isPresented = false
    @Environment(\.entityAuthProvider) private var provider
    @Environment(\.colorScheme) private var colorScheme
    private let featureFlags: UserProfileFeatureFlags

    public init(featureFlags: UserProfileFeatureFlags = .production) {
        self.featureFlags = featureFlags
    }

    public var body: some View {
        UserButton(provider: provider, size: .standard) {
            isPresented = true
        }
        .accessibilityLabel("Open user profile")
        .sheet(isPresented: $isPresented) {
            UserProfileSheet(isPresented: $isPresented, featureFlags: featureFlags)
        }
    }
}

/// A toolbar-ready user profile button that displays a user avatar and opens the profile sheet
public struct UserProfileToolbarButton: View {
    @State private var isPresented = false
    @Environment(\.entityAuthProvider) private var provider
    private let featureFlags: UserProfileFeatureFlags
    
    public enum Style {
        case avatar  // Shows user's avatar with initial letter
        case icon    // Shows generic user icon (system image)
    }
    
    private let style: Style
    
    public init(style: Style = .avatar, featureFlags: UserProfileFeatureFlags = .production) {
        self.style = style
        self.featureFlags = featureFlags
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
            UserProfileSheet(isPresented: $isPresented, featureFlags: featureFlags)
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
    case docs
    case changelog

    var title: String {
        switch self {
        case .account: return "Account"
        case .organizations: return "Organizations"
        case .invitations: return "Invitations"
        case .preferences: return "Preferences"
        case .security: return "Security"
        case .deleteAccount: return "Delete Account"
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
        case .docs: return "system:doc.text" // Documentation icon (system icon)
        case .changelog: return "system:clock.arrow.circlepath" // Changelog icon (system icon)
        }
    }
    
    /// Returns sections that should be visible based on feature flags
    static func visibleSections(with flags: UserProfileFeatureFlags) -> [ProfileSection] {
        var sections: [ProfileSection] = [.account, .organizations, .invitations]
        
        if flags.showPreferences {
            sections.append(.preferences)
        }
        if flags.showSecurity {
            sections.append(.security)
        }
        if flags.showDeleteAccount {
            sections.append(.deleteAccount)
        }
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
    @Environment(\.entityAuthProvider) private var provider
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.profileImageUploader) private var profileImageUploader
    let featureFlags: UserProfileFeatureFlags
    
    private var visibleSections: [ProfileSection] {
        ProfileSection.visibleSections(with: featureFlags)
    }

    var body: some View {
        #if os(iOS)
        contentIOS
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        #else
        contentMac.frame(minWidth: 700, minHeight: 480)
        #endif
    }

    // MARK: - iOS: Header + row buttons that push to detail views
    @ViewBuilder
    private var contentIOS: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    // Section Cards
                    VStack(spacing: 12) {
                        ForEach(visibleSections, id: \.self) { section in
                            sectionRow(section)
                        }
                    }
                    
                    // Sign Out Button
                    signOutRow
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
            }
            .navigationDestination(for: ProfileSection.self) { section in
                SectionDetail(section: section, isPresented: $isPresented, featureFlags: featureFlags)
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
            // Navigation Buttons
            VStack(spacing: 6) {
                ForEach(visibleSections, id: \.self) { section in
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
                        Text(section.title)
                            .font(.system(.subheadline, design: .rounded, weight: selected == section ? .semibold : .medium))
                        Spacer()
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
            }
            
            Spacer()
            
            // Sign Out Button (at bottom, inside container)
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
            case .docs:
                docsDetailView
            case .changelog:
                changelogDetailView
            }
        }
    }
    
    // MARK: - Account Detail View
    
    private var accountDetailView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Account")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                
                Spacer()
                
                // Edit Toggle Button
                Button(action: { isEditingAccount.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: isEditingAccount ? "xmark.circle.fill" : "pencil.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(isEditingAccount ? "Cancel" : "Edit")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(isEditingAccount ? Color.secondary : Color.blue)
                    .padding(.horizontal, 14)
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
            }
            
            // User Display or Edit Mode
            if isEditingAccount {
                UserDisplayEditable(
                    provider: provider,
                    onSave: { name, email in
                        Task {
                            await saveAccountChanges(name: name, email: email)
                        }
                    },
                    onCancel: {
                        isEditingAccount = false
                    },
                    onImageSelected: { imageData in
                        Task {
                            await saveProfileImage(imageData)
                        }
                    }
                )
            } else {
                UserDisplay(provider: provider, variant: .plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
    
    // MARK: - Organizations Detail View
    
    private var organizationsDetailView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Organizations")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            
            OrganizationList(onDismiss: nil)

            // Members of active organization
            ActiveOrgMembersSection()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
    
    // MARK: - Invitations Detail View
    
    private var invitationsDetailView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Invitations")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            
            InvitationsContent()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
    
    // MARK: - Preferences Detail View
    
    private var preferencesDetailView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preferences")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            
            PreferencesContent()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
    
    // MARK: - Security Detail View
    
    private var securityDetailView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Security")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            
            SecurityContent()
        }
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
                    
                    Text(section.title)
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
        Button(role: .destructive, action: {
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
                    .foregroundStyle(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                Group {
                    #if os(iOS)
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(.red.gradient)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.red.gradient)
                    }
                    #else
                    Capsule()
                        .fill(.red.gradient)
                    #endif
                }
            )
            .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
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

// MARK: - Active Organization Members Section
private struct ActiveOrgMembersSection: View {
    @Environment(\.entityAuthProvider) private var ea
    @State private var activeOrgId: String?
    @State private var canManage: Bool = false
    @State private var meId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let orgId = activeOrgId {
                OrganizationMembersList(
                    orgId: orgId,
                    canManage: canManage,
                    currentUserId: meId
                )
            }
        }
        .task {
            await loadActive()
        }
    }

    private func loadActive() async {
        do {
            let snap = await ea.currentSnapshot()
            meId = snap.userId
            if let active = try await ea.activeOrganization() {
                activeOrgId = active.orgId
                canManage = (active.role.lowercased() == "owner" || active.role.lowercased() == "admin")
            } else {
                activeOrgId = nil
                canManage = false
            }
        } catch {
            activeOrgId = nil
            canManage = false
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
    @State private var isEditingAccount: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch section {
                case .account:
                    if isEditingAccount {
                        UserDisplayEditable(
                            provider: provider,
                            onSave: { name, email in
                                Task {
                                    await saveAccountChanges(name: name, email: email)
                                }
                            },
                            onCancel: {
                                isEditingAccount = false
                            },
                            onImageSelected: { imageData in
                                Task {
                                    await saveProfileImage(imageData)
                                }
                            }
                        )
                    } else {
                        UserDisplay(provider: provider, variant: .plain)
                    }
                    
                case .organizations:
                    OrganizationList(onDismiss: { isPresented = false })
                    
                case .invitations:
                    InvitationsContent()
                    
                case .preferences:
                    PreferencesContent()
                    
                case .security:
                    SecurityContent()
                    
                case .deleteAccount:
                    DeleteAccountContent()
                    
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
        .navigationTitle(section.title)
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

// MARK: - Preferences Content (Shared)
private struct PreferencesContent: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            
            HStack(spacing: 12) {
                themeButton(title: "Light", icon: "sun.max.fill", isSelected: false)
                themeButton(title: "Dark", icon: "moon.fill", isSelected: true)
                themeButton(title: "Auto", icon: "circle.lefthalf.filled", isSelected: false)
            }
        }
    }
    
    @ViewBuilder
    private func themeButton(title: String, icon: String, isSelected: Bool) -> some View {
        Button(action: {
            // TODO: Implement theme switching
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Security Content (Shared)
private struct SecurityContent: View {
    var body: some View {
        VStack(spacing: 12) {
            securityOption(title: "Change Password", icon: "key.fill")
            securityOption(title: "Two-Factor Authentication", icon: "shield.checkered")
            securityOption(title: "Passkeys", icon: "person.badge.key.fill")
            securityOption(title: "Active Sessions", icon: "laptopcomputer.and.iphone")
        }
    }
    
    @ViewBuilder
    private func securityOption(title: String, icon: String) -> some View {
        Button(action: {
            // TODO: Implement security actions
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Delete Account Content (Shared)
private struct DeleteAccountContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Warning message
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.red)
                    
                    Text("Warning")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.red)
                }
                
                Text("This will permanently delete your account, including all your data, organizations, and settings. This action is irreversible.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.red.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.red.opacity(0.3), lineWidth: 1)
            )
            
            // Delete button
            Button(action: {
                // TODO: Implement delete account flow
            }) {
                HStack(spacing: 12) {
                    Image("DeleteX", bundle: .module)
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 18, height: 18)
                    
                    Text("Delete My Account")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(.red.gradient)
                )
            }
            .buttonStyle(.plain)
            .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Invitations Content (New System)
private struct InvitationsContent: View {
    @Environment(\.entityAuthProvider) private var ea
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false
    @State private var received: [Invitation] = []
    @State private var sent: [Invitation] = []
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite a user")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            TextField("", text: $searchText, prompt: Text("Search users (fuzzy)"))
                .textFieldStyle(.roundedBorder)
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
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(foundUsers, id: \.id) { user in
                        HStack {
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
                            Menu("Invite to...") {
                                ForEach(orgsICanInvite, id: \.orgId) { org in
                                    Button("\(org.name ?? org.slug ?? org.orgId) (\(org.role))") {
                                        Task { await sendInvite(orgId: org.orgId, inviteeUserId: user.id) }
                                    }
                                }
                            }
                            .disabled(orgsICanInvite.isEmpty)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                }
            }

            if let error {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
    }

    private var listsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invitations")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            if isLoading {
                ProgressView().padding(.vertical, 24)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Received").font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Text("\(received.count)")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        }
                        if received.isEmpty {
                            roundedInfo("No invitations")
                        } else {
                            ForEach(received, id: \.id) { inv in
                                invitationRow(inv, actions: .received)
                            }
                            if receivedHasMore {
                                Button("Load more...") {
                                    Task { await loadMoreReceived() }
                                }
                                .font(.caption)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Sent").font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Text("\(sent.count)")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        }
                        if sent.isEmpty {
                            roundedInfo("No invitations sent")
                        } else {
                            ForEach(sent, id: \.id) { inv in
                                invitationRow(inv, actions: .sent)
                            }
                            if sentHasMore {
                                Button("Load more...") {
                                    Task { await loadMoreSent() }
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }

    private enum InvitationActions { case received, sent }

    @ViewBuilder
    private func invitationRow(_ inv: Invitation, actions: InvitationActions) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Org: \(orgNameForId[inv.orgId] ?? inv.orgId)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                HStack(spacing: 8) {
                    Text(inv.role.capitalized)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    Text(inv.status.capitalized)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(statusColor(inv.status)))
                        .foregroundStyle(statusTextColor(inv.status))
                }
                let expiresDate = Date(timeIntervalSince1970: inv.expiresAt / 1000)
                if expiresDate < Date() {
                    Text("Expired")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            switch actions {
            case .received:
                if inv.status == "pending" {
                    HStack(spacing: 8) {
                        Button("Accept") { Task { await accept(inv.id) } }
                        Button("Decline") { Task { await decline(inv.id) } }.buttonStyle(.bordered)
                    }
                }
            case .sent:
                if inv.status == "pending" {
                    HStack(spacing: 8) {
                        Button("Revoke") { Task { await revoke(inv.id) } }.buttonStyle(.bordered)
                        Button("Resend") { Task { await resend(inv.id) } }.buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    @ViewBuilder
    private func roundedInfo(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
            )
    }

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        error = nil
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
            received.append(contentsOf: result.items)
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
            sent.append(contentsOf: result.items)
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

