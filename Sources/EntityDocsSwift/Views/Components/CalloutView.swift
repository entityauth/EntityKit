//
//  CalloutView.swift
//  EntityDocsSwift
//
//  Callout component matching fumadocs
//

import SwiftUI

struct CalloutView: View {
    let component: ComponentNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var type: String {
        component.props["type"]?.stringValue ?? "info"
    }
    
    var title: String? {
        component.props["title"]?.stringValue
    }
    
    var icon: String {
        switch type {
        case "warning", "warn":
            return "exclamationmark.triangle.fill"
        case "error", "danger":
            return "xmark.circle.fill"
        case "success", "check":
            return "checkmark.circle.fill"
        default:
            return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch type {
        case "warning", "warn":
            return .orange
        case "error", "danger":
            return .red
        case "success", "check":
            return .green
        default:
            return .blue
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                if let title = title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                if let children = component.children {
                    MarkdownRenderer(nodes: children, onLinkTap: onLinkTap)
                }
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

