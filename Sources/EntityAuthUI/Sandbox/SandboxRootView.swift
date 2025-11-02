import SwiftUI
import EntityAuthDomain

public struct SandboxRootView: View {
    @State private var query: String = ""
    @State private var selection: ComponentItem? = componentRegistry.first
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline)
                    Text(item.description).font(.subheadline).foregroundStyle(.secondary)
                }
                .tag(item)
            }
            .navigationTitle("UI Components")
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
                    if item.component == .organizationSwitcher {
                        Preview(item: item)
                            .padding()
                            .navigationTitle(item.title)
                    } else {
                        ScrollView { Preview(item: item) }
                            .padding()
                            .navigationTitle(item.title)
                    }
                } else {
                    ContentUnavailableView("Select a component", systemImage: "square.grid.2x2")
                }
            } else {
                AuthGate()
            }
        }
        .task {
            // Consider authenticated if we ever get a snapshot with a userId
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
    @State private var showOrgSheet: Bool = false
    @State private var showOrgPopover: Bool = false

    var body: some View {
        switch item.component {
        case .authView:
            AuthView(
                email: $email,
                password: $password,
                errorText: $errorText
            )
        case .authViewModal:
            VStack(spacing: 16) {
                Text("Tap to present auth in a modal").font(.caption).foregroundStyle(.secondary)
                AuthViewModal(title: "Sign in")
            }
        case .userProfile:
            VStack(spacing: 12) {
                Text("Toolbar-style preview").font(.caption).foregroundStyle(.secondary)
                UserProfile()
            }
        case .userDisplay:
            UserDisplay(provider: provider)
        case .organizationSwitcher:
            VStack(alignment: .leading, spacing: 16) {
                // Inline preview
                Text("Inline component").font(.caption).foregroundStyle(.secondary)
                OrganizationSwitcherView()

                // iOS: Presentation sheet demo
                #if os(iOS)
                Divider()
                Text("iOS presentation sheet").font(.caption).foregroundStyle(.secondary)
                Button("My Organizations") { showOrgSheet = true }
                    .buttonStyle(.borderedProminent)
                    .sheet(isPresented: $showOrgSheet) {
                        NavigationStack {
                            OrganizationSwitcherView()
                                .navigationTitle("My Organizations")
                                .navigationBarTitleDisplayMode(.inline)
                                .padding()
                        }
                    }
                #endif

                // macOS: Popover-style menu demo
                #if os(macOS)
                Divider()
                Text("macOS menu (popover)").font(.caption).foregroundStyle(.secondary)
                Button("My Organizations") { showOrgPopover = true }
                    .buttonStyle(.borderedProminent)
                    .popover(isPresented: $showOrgPopover, arrowEdge: .bottom) {
            OrganizationSwitcherView()
                            .frame(width: 420, height: 520)
                            .padding()
                    }
                #endif
            }
        }
    }
}


