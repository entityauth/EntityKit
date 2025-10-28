//
//  ContentView.swift
//  EntityKitSandbox
//
//  Created by naaiyy on 10/20/25.
//

import SwiftUI
import EntityAuthUI

struct ContentView: View {
    var body: some View {
        UIDesignGallery()
            .entityTheme(.default)
    }
}

/// Pure UI design sandbox - no real auth required
private struct UIDesignGallery: View {
    @State private var query: String = ""
    @State private var selection: ComponentItem? = componentRegistry.first
    
    var body: some View {
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
            if let item = selection {
                ScrollView {
                    ComponentPreview(item: item)
                }
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

private struct ComponentPreview: View {
    let item: ComponentItem
    
    var body: some View {
        switch item.component {
        case .authView:
            AuthView()
        case .userProfile:
            UserProfile()
        case .userDisplay:
            // Mock display for design preview
            VStack(alignment: .leading, spacing: 6) {
                Text("John Appleseed").font(.headline)
                Text("john@example.com").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
