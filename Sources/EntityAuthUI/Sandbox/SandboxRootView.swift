import SwiftUI
import EntityAuthDomain

public struct SandboxRootView: View {
    @State private var query: String = ""
    #if os(iOS)
    @State private var selection: ComponentItem? = nil  // Start with sidebar on iOS
    #else
    @State private var selection: ComponentItem? = componentRegistry.first  // Auto-select first on macOS
    #endif
    @Environment(\.entityAuthProvider) private var provider

    public init() {}
    
    /// Convenience initializer that sets up the sandbox with mock auth provider
    public static func withMockAuth() -> some View {
        let orgs: [OrganizationSummary] = [
            OrganizationSummary(orgId: "org_acme", name: "Acme Inc.", slug: "acme", memberCount: 12, role: "owner", joinedAt: Date().addingTimeInterval(-86400 * 400).timeIntervalSince1970, workspaceTenantId: "demo"),
            OrganizationSummary(orgId: "org_umbrella", name: "Umbrella", slug: "umbrella", memberCount: 5, role: "member", joinedAt: Date().addingTimeInterval(-86400 * 200).timeIntervalSince1970, workspaceTenantId: "demo"),
            OrganizationSummary(orgId: "org_wayne", name: "Wayne Enterprises", slug: "wayne", memberCount: 28, role: "member", joinedAt: Date().addingTimeInterval(-86400 * 30).timeIntervalSince1970, workspaceTenantId: "demo")
        ]
        return SandboxRootView()
            .entityTheme(.default)
            .entityAuthProvider(.preview(name: "John Appleseed", email: "john@example.com", organizations: orgs, activeOrgId: "org_acme"))
    }

    public var body: some View {
        NavigationSplitView {
            List(filteredItems, selection: $selection) { item in
                Text(item.title).font(.headline)
                    .tag(item)
            }
            .navigationTitle("Components")
            .searchable(text: $query, placement: .sidebar)
        } detail: {
            AuthOrContent(selection: selection)
        }
    }

    private var filteredItems: [ComponentItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return componentRegistry }
        return componentRegistry.filter { item in
            item.title.lowercased().contains(q) ||
            item.description.lowercased().contains(q) ||
            item.keywords.contains(where: { $0.lowercased().contains(q) })
        }
    }
}

private struct AuthOrContent: View {
    let selection: ComponentItem?
    @Environment(\.entityAuthProvider) private var provider
    @State private var isAuthenticated: Bool = false

    var body: some View {
        Group {
            if isAuthenticated {
                if let item = selection {
                    Preview(item: item)
                } else {
                    ContentUnavailableView("Select a component", systemImage: "square.grid.2x2")
                }
            } else {
                AuthGate()
            }
        }
        .task {
            // Check current snapshot first
            let current = await provider.currentSnapshot()
            if current.userId != nil {
                isAuthenticated = true
                return
            }
            
            // Then listen to stream for changes
            let stream = await provider.snapshotStream()
            for await snap in stream {
                if snap.userId != nil {
                    isAuthenticated = true
                    break
                }
            }
        }
    }
}

private struct Preview: View {
    let item: ComponentItem
    @Environment(\.entityAuthProvider) private var provider
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorText: String?

    var body: some View {
        switch item.component {
        case .authView:
            AuthView(
                email: $email,
                password: $password,
                errorText: $errorText
            )
        case .userProfile:
            UserProfile()
        case .userDisplay:
            UserDisplayGallery()
        case .message:
            MessageGallery()
        case .organizationSwitcher:
            OrganizationSwitcherView()
        }
    }
}


