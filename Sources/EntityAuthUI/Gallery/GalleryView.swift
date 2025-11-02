import SwiftUI

public struct GalleryView: View {
    @State private var query: String = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
            List(filteredItems) { item in
                VStack(alignment: .leading) {
                    Text(item.title).font(.headline)
                    Text(item.description).font(.subheadline).foregroundStyle(.secondary)
                    Preview(item: item)
                }
            }
        }
        .padding()
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
    @Environment(\.entityAuthProvider) private var provider

    var body: some View {
        switch item.component {
        case .authView:
            AuthView()
                .padding(.vertical, 8)
        case .userProfile:
            UserProfile()
                .padding(.vertical, 8)
        case .userDisplay:
            UserDisplay(provider: provider)
                .padding(.vertical, 8)
        case .organizationSwitcher:
            OrganizationSwitcherView()
                .frame(minHeight: 300)
                .padding(.vertical, 8)
        }
    }
}


