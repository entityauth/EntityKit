import SwiftUI

public struct SandboxRootView: View {
    @State private var query: String = ""
    @State private var selection: ComponentItem? = componentRegistry.first
    @Environment(\.entityAuthProvider) private var provider

    public init() {}

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
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorText: String?

    var body: some View {
        switch item.component {
        case .authView:
            AuthView(
                email: $email,
                password: $password,
                errorText: $errorText,
                onGoogleSignIn: {
                    // Mock Google SSO callback for preview
                    print("[Preview] Google SSO sign-in tapped")
                    errorText = "Preview mode - Google SSO not implemented"
                },
                onGitHubSignIn: {
                    // Mock GitHub SSO callback for preview
                    print("[Preview] GitHub SSO sign-in tapped")
                    errorText = "Preview mode - GitHub SSO not implemented"
                },
                onPasskeySignIn: {
                    // Mock Passkey sign-in callback for preview
                    print("[Preview] Passkey sign-in tapped")
                    errorText = "Preview mode - Passkey sign-in not implemented"
                },
                onPasskeySignUp: { email in
                    // Mock Passkey sign-up callback for preview
                    print("[Preview] Passkey sign-up tapped: \(email)")
                    errorText = "Preview mode - Passkey sign-up not implemented"
                },
                onEmailSignIn: { email, password in
                    // Mock email sign-in callback for preview
                    print("[Preview] Email sign-in tapped: \(email)")
                    errorText = "Preview mode - Email sign-in not implemented"
                },
                onEmailRegister: { email, password in
                    // Mock email registration callback for preview
                    print("[Preview] Email registration tapped: \(email)")
                    errorText = "Preview mode - Email registration not implemented"
                }
            )
        case .userProfile:
            VStack(spacing: 12) {
                Text("Toolbar-style preview").font(.caption).foregroundStyle(.secondary)
                UserProfile()
            }
        case .userDisplay:
            UserDisplay()
        }
    }
}


