import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct UserProfile: View {
    @State private var isPresented = false
    @Environment(\.entityAuthProvider) private var provider

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
    case security
    case organizations
    case preferences

    var title: String {
        switch self {
        case .account: return "Account"
        case .security: return "Security"
        case .organizations: return "Organizations"
        case .preferences: return "Preferences"
        }
    }

    var symbol: String {
        switch self {
        case .account: return "person"
        case .security: return "lock"
        case .organizations: return "person.3"
        case .preferences: return "gearshape"
        }
    }
}

private struct UserProfileSheet: View {
    @Binding var isPresented: Bool
    @State private var selected: ProfileSection = .account
    @State private var path: [ProfileSection] = []
    @Environment(\.entityAuthProvider) private var provider

    var body: some View {
        #if os(iOS)
        contentIOS
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        #else
        contentMac.frame(minWidth: 640, minHeight: 420)
        #endif
    }

    // MARK: - iOS: Header + row buttons that push to detail views
    @ViewBuilder
    private var contentIOS: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                HStack {
                    Text("Account").font(.headline)
                    Spacer()
                    Button("Close") { isPresented = false }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                Divider()

                VStack(spacing: 8) {
                    sectionRow(.account)
                    sectionRow(.security)
                    sectionRow(.organizations)
                    Divider().padding(.vertical, 4)
                    signOutRow
                }
                .padding(12)

                Spacer(minLength: 0)
            }
            .navigationDestination(for: ProfileSection.self) { section in
                SectionDetail(section: section)
                #if os(iOS)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { isPresented = false }
                        }
                    }
                #endif
            }
        }
    }

    // MARK: - macOS: Sidebar + detail
    @ViewBuilder
    private var contentMac: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Profile").font(.headline)
                Spacer()
                Button("Close") { isPresented = false }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            HStack(spacing: 0) {
                sidebar
                    .frame(minWidth: 180, maxWidth: 220)
                    .padding(.vertical, 12)
                    .background(secondaryBackground)

                Divider()

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(ProfileSection.allCases, id: \.self) { section in
                Button(action: { selected = section }) {
                    HStack(spacing: 8) {
                        Image(systemName: section.symbol)
                            .frame(width: 18)
                        Text(section.title)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected == section ? Color.accentColor.opacity(0.12) : .clear)
                )
            }

            Spacer()

            Button(role: .destructive, action: {
                Task {
                    try? await provider.logout()
                    isPresented = false
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .frame(width: 18)
                    Text("Sign out")
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 8)
    }

    private var detail: some View {
        Group {
            switch selected {
            case .account:
                VStack(alignment: .leading, spacing: 12) {
                    Text("Account").font(.title3).bold()
                    Text("Your account information and settings.")
                        .foregroundStyle(.secondary)
                }
            case .security:
                SectionDetail(section: .security)
            case .organizations:
                SectionDetail(section: .organizations)
            case .preferences:
                SectionDetail(section: .preferences)
            }
            Spacer()
        }
    }

    // MARK: - Reusable rows (iOS)
    private func sectionRow(_ section: ProfileSection) -> some View {
        Button(action: { path.append(section) }) {
            HStack(spacing: 12) {
                Image(systemName: section.symbol)
                    .frame(width: 20)
                Text(section.title)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(secondaryBackground)
            )
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
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .frame(width: 20)
                Text("Sign out")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(secondaryBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Detail
private struct SectionDetail: View {
    let section: ProfileSection
    @Environment(\.entityAuthProvider) private var provider

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3).bold()
            Text(subtitle).foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .navigationTitle(title)
    }

    private var title: String {
        section.title
    }

    private var subtitle: String {
        switch section {
        case .account: return "Name, email, and profile info."
        case .security: return "Passwords, passkeys, and MFA settings."
        case .organizations: return "Switch organizations and manage roles."
        case .preferences: return "Appearance and component options."
        }
    }
}

// MARK: - Cross-platform colors
private var secondaryBackground: Color {
#if os(iOS)
    return Color(UIColor.secondarySystemBackground)
#else
    return Color(NSColor.windowBackgroundColor)
#endif
}
