import SwiftUI

public struct SandboxRootView: View {
    @State private var query: String = ""
    @State private var selection: ComponentItem? = componentRegistry.first
    @Environment(\.entityAuthProvider) private var provider

    public init() {}
    
    /// Convenience initializer that sets up the sandbox with mock auth provider
    public static func withMockAuth() -> some View {
        SandboxRootView()
            .entityTheme(.default)
            .entityAuthProvider(.preview(name: "John Appleseed", email: "john@example.com"))
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
                    ScrollView { Preview(item: item) }
                        .padding()
                        .navigationTitle(item.title)
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
        }
    }
}


