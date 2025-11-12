//
//  TabsView.swift
//  EntityDocsSwift
//
//  Tabs component matching fumadocs
//

import SwiftUI

struct TabsView: View {
    let component: ComponentNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    @State private var selectedIndex = 0
    
    fileprivate var tabs: [TabItem] {
        guard let children = component.children else { return [] }
        
        var items: [TabItem] = []
        var currentTab: TabItem?
        
        for child in children {
            if case .component(let tabComponent) = child, tabComponent.name == "Tab" {
                if let existing = currentTab {
                    items.append(existing)
                }
                currentTab = TabItem(
                    title: tabComponent.props["title"]?.stringValue ?? "",
                    value: tabComponent.props["value"]?.stringValue,
                    children: tabComponent.children ?? []
                )
            } else if var tab = currentTab {
                tab.children.append(child)
                currentTab = tab
            }
        }
        
        if let tab = currentTab {
            items.append(tab)
        }
        
        return items
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab headers
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button(action: {
                            withAnimation {
                                selectedIndex = index
                            }
                        }) {
                            Text(tab.title)
                                .font(.subheadline)
                                .fontWeight(selectedIndex == index ? .semibold : .regular)
                                .foregroundColor(selectedIndex == index ? .accentColor : .secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(selectedIndex == index ? .accentColor : .clear),
                            alignment: .bottom
                        )
                    }
                }
            }
            .background(Color.secondary.opacity(0.05))
            
            // Tab content
            if selectedIndex < tabs.count {
                VStack(alignment: .leading, spacing: 8) {
                    MarkdownRenderer(nodes: tabs[selectedIndex].children, onLinkTap: onLinkTap)
                        .padding()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.secondary.opacity(0.02))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

fileprivate struct TabItem {
    let title: String
    let value: String?
    var children: [ProcessedNode]
}

struct TabView: View {
    let component: ComponentNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var body: some View {
        // Tab is handled by parent TabsView
        EmptyView()
    }
}

