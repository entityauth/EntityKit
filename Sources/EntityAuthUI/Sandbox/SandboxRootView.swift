import SwiftUI
import EntityAuthDomain

public struct SandboxRootView: View {
    @State private var query: String = ""
    @State private var selection: ComponentItem? = componentRegistry.first

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(filteredItems, selection: $selection) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline)
                    Text(item.description).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("UI Components")
            .searchable(text: $query, placement: .sidebar)
        } detail: {
            if let item = selection {
                ScrollView { Preview(item: item) }
                    .padding()
                    .navigationTitle(item.title)
            } else {
                ContentUnavailableView("Select a component", systemImage: "square.grid.2x2")
            }
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

private struct Preview: View {
    let item: ComponentItem

    var body: some View {
        switch item.component {
        case .authView:
            AuthView(viewModel: .init(authService: AuthService()))
        case .userButton:
            VStack(spacing: 12) {
                Text("Toolbar-style preview").font(.caption).foregroundStyle(.secondary)
                UserButton()
            }
        case .userProfileView:
            UserProfileView(viewModel: .init(facade: Facade()))
        }
    }
}


