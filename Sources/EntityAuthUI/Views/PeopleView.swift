import SwiftUI
import EntityAuthDomain
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Unified People view with tab-based navigation
/// Replaces PeopleContent and InvitationsContent with a single, coherent experience
public struct PeopleView: View {
    @Environment(\.entityAuthProvider) private var provider
    @Environment(\.colorScheme) private var colorScheme
    
    let mode: UserProfilePeopleMode
    let initialTab: PeopleTab?
    
    @State private var store: PeopleStore?
    @State private var selectedTab: PeopleTab = .find
    
    private var supportsOrg: Bool { mode != .friends }
    private var supportsFriends: Bool { mode != .org }
    
    public init(mode: UserProfilePeopleMode, initialTab: PeopleTab? = nil) {
        self.mode = mode
        self.initialTab = initialTab
    }
    
    public var body: some View {
        Group {
            if let store = store {
                VStack(spacing: 0) {
                    // Error banner
                    if let error = currentError(for: store) {
                        ErrorBanner(error: error)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    
                    // Tab bar
                    TabBar(selectedTab: $selectedTab, mode: mode, store: store)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Tab content - use conditional rendering for both iOS and macOS
                    // to match the glass tab bar style
                    Group {
                        if selectedTab == .find && (supportsOrg || supportsFriends) {
                            FindPeopleTab(store: store, mode: mode)
                        } else if selectedTab == .sentInvitations && supportsOrg {
                            SentInvitationsTab(store: store)
                        } else if selectedTab == .receivedInvitations && supportsOrg {
                            ReceivedInvitationsTab(store: store)
                        } else if selectedTab == .sentFriends && supportsFriends {
                            SentFriendRequestsTab(store: store)
                        } else if selectedTab == .receivedFriends && supportsFriends {
                            ReceivedFriendRequestsTab(store: store)
                        } else if selectedTab == .friends && supportsFriends {
                            FriendsTab(store: store)
                        } else {
                            // Fallback empty state
                            EmptyStateView(
                                icon: "person.2",
                                title: "No content",
                                message: nil
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .refreshable {
                    await store.refreshAll()
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await initializeStore()
        }
    }
    
    private func currentError(for store: PeopleStore) -> PeopleError? {
        store.searchError ?? store.invitationsError ?? store.friendsError ?? store.connectionsError
    }
    
    @MainActor
    private func initializeStore() async {
        guard store == nil else { return }
        
        let snapshot = await provider.currentSnapshot()
        guard let userId = snapshot.userId else { return }
        
        // Create store with proper userId
        let peopleService = provider.makePeopleService()
        let newStore = PeopleStore(peopleService: peopleService, userId: userId)
        
        // Load initial data
        await newStore.refreshAll()
        
        // Set store
        store = newStore
        
        // Set initial tab if provided
        if let initialTab = initialTab {
            selectedTab = initialTab
        }
    }
}

public enum PeopleTab: Hashable, Sendable {
    case find
    case sentInvitations
    case receivedInvitations
    case sentFriends
    case receivedFriends
    case friends
}

// MARK: - Tab Bar

struct TabBar: View {
    @Binding var selectedTab: PeopleTab
    let mode: UserProfilePeopleMode
    let store: PeopleStore
    @Environment(\.colorScheme) private var colorScheme
    
    private var supportsOrg: Bool { mode != .friends }
    private var supportsFriends: Bool { mode != .org }
    
    var body: some View {
        HStack(spacing: 0) {
            if supportsOrg || supportsFriends {
                TabButton(
                    title: "Find people",
                    badge: nil,
                    isSelected: selectedTab == .find,
                    action: { 
                        withAnimation(.spring(duration: 0.25)) {
                            selectedTab = .find
                        }
                    }
                )
            }
            
            if supportsOrg {
                TabButton(
                    title: "Sent",
                    badge: supportsOrg && store.pendingSentInvitationsCount > 0 ? store.pendingSentInvitationsCount : nil,
                    isSelected: selectedTab == .sentInvitations,
                    action: { 
                        withAnimation(.spring(duration: 0.25)) {
                            selectedTab = .sentInvitations
                        }
                    }
                )
                
                TabButton(
                    title: "Received",
                    badge: store.unreadInvitationsCount > 0 ? store.unreadInvitationsCount : nil,
                    isSelected: selectedTab == .receivedInvitations,
                    action: { 
                        withAnimation(.spring(duration: 0.25)) {
                            selectedTab = .receivedInvitations
                        }
                    }
                )
            }
            
            if supportsFriends {
                TabButton(
                    title: "Sent",
                    badge: store.pendingSentFriendRequestsCount > 0 ? store.pendingSentFriendRequestsCount : nil,
                    isSelected: selectedTab == .sentFriends,
                    action: { 
                        withAnimation(.spring(duration: 0.25)) {
                            selectedTab = .sentFriends
                        }
                    }
                )
                
                TabButton(
                    title: "Received",
                    badge: store.unreadFriendRequestsCount > 0 ? store.unreadFriendRequestsCount : nil,
                    isSelected: selectedTab == .receivedFriends,
                    action: { 
                        withAnimation(.spring(duration: 0.25)) {
                            selectedTab = .receivedFriends
                        }
                    }
                )
                
                TabButton(
                    title: "Friends",
                    badge: store.friendConnections.count,
                    isSelected: selectedTab == .friends,
                    action: { 
                        withAnimation(.spring(duration: 0.25)) {
                            selectedTab = .friends
                        }
                    }
                )
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.12))
        )
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}

struct TabButton: View {
    let title: String
    let badge: Int?
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                
                if let badge = badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(isSelected ? 0.15 : 0.08))
                        )
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            Group {
                if isSelected {
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
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let error: PeopleError
    @State private var copied = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(errorMessage)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            Button(action: {
                copyToClipboard()
            }) {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundColor(copied ? .green : .orange)
                    .font(.system(.subheadline))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            Group {
                #if os(iOS)
                if #available(iOS 26.0, *) {
                    Capsule()
                        .fill(.regularMaterial)
                        .glassEffect(.regular.interactive(true), in: .capsule)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                }
                #elseif os(macOS)
                if #available(macOS 15.0, *) {
                    Capsule()
                        .fill(.regularMaterial)
                        .glassEffect(.regular.interactive(true), in: .capsule)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                }
                #else
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                #endif
            }
        )
    }
    
    private var errorMessage: String {
        switch error {
        case .invitation(let invError):
            return "Invitation error: \(invError.localizedDescription)"
        case .friend(let friendError):
            return "Friend request error: \(friendError.localizedDescription)"
        case .search(let searchError):
            return "Search error: \(searchError.localizedDescription)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unauthorized:
            return "Please sign in to continue"
        case .unknown(let message):
            return "Error: \(message)"
        }
    }
    
    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = errorMessage
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(errorMessage, forType: .string)
        #endif
        
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copied = false
        }
    }
}

