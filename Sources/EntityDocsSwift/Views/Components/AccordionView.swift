//
//  AccordionView.swift
//  EntityDocsSwift
//
//  Accordion component matching fumadocs
//

import SwiftUI

struct AccordionsView: View {
    let component: ComponentNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let children = component.children {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    if case .component(let accordion) = child, accordion.name == "Accordion" {
                        AccordionView(component: accordion, onLinkTap: onLinkTap)
                    }
                }
            }
        }
    }
}

struct AccordionView: View {
    let component: ComponentNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    @State private var isExpanded = false
    
    var title: String {
        component.props["title"]?.stringValue ?? ""
    }
    
    var id: String {
        component.props["id"]?.stringValue ?? UUID().uuidString
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let children = component.children {
                        MarkdownRenderer(nodes: children, onLinkTap: onLinkTap)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

