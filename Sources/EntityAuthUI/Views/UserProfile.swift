import SwiftUI
import EntityAuthDomain
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct UserProfile: View {
    @State private var isPresented = false
    @Environment(\.entityAuthProvider) private var provider
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        UserButton(provider: provider, size: .standard) {
            isPresented = true
        }
        .accessibilityLabel("Open user profile")
        .sheet(isPresented: $isPresented) {
            UserProfileSheet(isPresented: $isPresented)
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

    var title: String {
        switch self {
        case .account: return "Account"
        case .organizations: return "Organizations"
        case .invitations: return "Invitations"
        case .preferences: return "Preferences"
        case .security: return "Security"
        case .deleteAccount: return "Delete Account"
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
        }
    }
}

private struct UserProfileSheet: View {
    @Binding var isPresented: Bool
    @State private var selected: ProfileSection = .account
    @State private var path: [ProfileSection] = []
    @Environment(\.entityAuthProvider) private var provider
    @Environment(\.colorScheme) private var colorScheme

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
                        ForEach(ProfileSection.allCases, id: \.self) { section in
                            sectionRow(section)
                        }
                    }
                    
                    // Sign Out Button
                    signOutRow
                }
                .padding(16)
            }
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
                SectionDetail(section: section, isPresented: $isPresented)
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
                ForEach(ProfileSection.allCases, id: \.self) { section in
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = section 
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(section.iconName, bundle: .module)
                            .resizable()
                            .renderingMode(.template)
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
                        .renderingMode(.template)
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
            }
        }
    }
    
    // MARK: - Account Detail View
    
    private var accountDetailView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Account")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            
            // User Display Component
            UserDisplay(provider: provider, variant: .plain)
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

    // MARK: - Reusable rows (iOS)
    private func sectionRow(_ section: ProfileSection) -> some View {
        Button(action: { path.append(section) }) {
            HStack(spacing: 14) {
                // Icon Circle
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(section.iconName, bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.primary)
                }
                
                Text(section.title)
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
                    #else
                    Capsule()
                        .fill(.ultraThinMaterial)
                    #endif
                }
            )
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.08), radius: 8, x: 0, y: 2)
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
                    .renderingMode(.template)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white)
                
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
}

// MARK: - Section Detail (for iOS navigation)
private struct SectionDetail: View {
    let section: ProfileSection
    @Environment(\.entityAuthProvider) private var provider
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch section {
                case .account:
                    UserDisplay(provider: provider, variant: .plain)
                    
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
                }
            }
            .padding()
        }
        .navigationTitle(section.title)
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
                        .renderingMode(.template)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.white)
                    
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

// MARK: - Invitations Content (Shared)
private struct InvitationsContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var invitations: [MockInvitation] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                loadingView
            } else if invitations.isEmpty {
                emptyStateView
            } else {
                invitationsListView
            }
        }
        .onAppear {
            // TODO: Load actual invitations from provider
            // For now, showing mock data for UI demonstration
            loadMockInvitations()
        }
    }
    
    private func loadMockInvitations() {
        isLoading = true
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            invitations = [
                MockInvitation(
                    id: "1",
                    organizationName: "Acme Corporation",
                    inviterName: "Sarah Chen",
                    role: "Member",
                    invitedAt: Date().addingTimeInterval(-86400 * 2) // 2 days ago
                ),
                MockInvitation(
                    id: "2",
                    organizationName: "Tech Innovators",
                    inviterName: "Michael Rodriguez",
                    role: "Admin",
                    invitedAt: Date().addingTimeInterval(-3600 * 5) // 5 hours ago
                ),
                MockInvitation(
                    id: "3",
                    organizationName: "Design Studio Co",
                    inviterName: "Emma Watson",
                    role: "Viewer",
                    invitedAt: Date().addingTimeInterval(-60 * 30) // 30 minutes ago
                )
            ]
            isLoading = false
        }
    }
    
    private func acceptInvitation(_ invitation: MockInvitation) {
        withAnimation {
            invitations.removeAll { $0.id == invitation.id }
        }
        // TODO: Implement actual accept logic
    }
    
    private func declineInvitation(_ invitation: MockInvitation) {
        withAnimation {
            invitations.removeAll { $0.id == invitation.id }
        }
        // TODO: Implement actual decline logic
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading invitations...")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image("PaperPlace", bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 36, height: 36)
                    .foregroundStyle(Color.accentColor.opacity(0.7))
            }
            
            // Text
            VStack(spacing: 8) {
                Text("No pending invitations")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("You'll see organization invitations here when someone invites you to join their team.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Invitations List
    
    private var invitationsListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with count
            HStack {
                Text("\(invitations.count) Pending Invitation\(invitations.count == 1 ? "" : "s")")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding(.bottom, 4)
            
            // Invitations
            VStack(spacing: 12) {
                ForEach(invitations) { invitation in
                    invitationCard(invitation)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
    }
    
    @ViewBuilder
    private func invitationCard(_ invitation: MockInvitation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with org info
            HStack(spacing: 12) {
                // Organization Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Text(invitation.organizationName.prefix(1).uppercased())
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                // Organization Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.organizationName)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text("Invited by \(invitation.inviterName)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Role badge
                Text(invitation.role.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    )
            }
            
            // Timestamp
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                
                Text(formatRelativeTime(invitation.invitedAt))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Decline
                Button(action: {
                    declineInvitation(invitation)
                }) {
                    Text("Decline")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                // Accept
                Button(action: {
                    acceptInvitation(invitation)
                }) {
                    Text("Accept")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
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
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 12, x: 0, y: 4)
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if seconds < 604800 {
            let days = Int(seconds / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else {
            let weeks = Int(seconds / 604800)
            return "\(weeks) week\(weeks == 1 ? "" : "s") ago"
        }
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

