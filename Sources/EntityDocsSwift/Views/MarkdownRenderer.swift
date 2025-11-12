//
//  MarkdownRenderer.swift
//  EntityDocsSwift
//
//  Renders ProcessedNode tree into SwiftUI views
//

import SwiftUI

public struct MarkdownRenderer: View {
    let nodes: [ProcessedNode]
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    public init(nodes: [ProcessedNode], onLinkTap: (@MainActor @Sendable (String) -> Void)? = nil) {
        self.nodes = nodes
        self.onLinkTap = onLinkTap
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                renderNode(node)
            }
        }
    }
    
    @ViewBuilder
    private func renderNode(_ node: ProcessedNode) -> some View {
        switch node {
        case .heading(let heading):
            HeadingView(heading: heading)
        case .paragraph(let para):
            ParagraphView(paragraph: para, onLinkTap: onLinkTap)
        case .list(let list):
            ListView(list: list, onLinkTap: onLinkTap)
        case .code(let code):
            CodeBlockView(code: code)
        case .blockquote(let blockquote):
            BlockquoteView(blockquote: blockquote, onLinkTap: onLinkTap)
        case .table(let table):
            TableView(table: table, onLinkTap: onLinkTap)
        case .thematicBreak:
            Divider()
        case .component(let component):
            ComponentView(component: component, onLinkTap: onLinkTap)
        case .text(let text):
            Text(text.value)
        case .strong(let strong):
            StrongView(strong: strong, onLinkTap: onLinkTap)
        case .emphasis(let emphasis):
            EmphasisView(emphasis: emphasis, onLinkTap: onLinkTap)
        case .link(let link):
            LinkView(link: link, onLinkTap: onLinkTap)
        case .image(let image):
            ImageView(image: image)
        case .inlineCode(let code):
            InlineCodeView(code: code)
        }
    }
}

// MARK: - Heading View

private struct HeadingView: View {
    let heading: HeadingNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(inlineAttributedString(from: heading.children))
                .font(fontForDepth(heading.depth))
                .fontWeight(.bold)
                .id(heading.id)
        }
    }
    
    private func fontForDepth(_ depth: Int) -> Font {
        switch depth {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        case 5: return .headline
        default: return .subheadline
        }
    }
}

// MARK: - Paragraph View

private struct ParagraphView: View {
    let paragraph: ParagraphNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var body: some View {
        inlineText(from: paragraph.children, onLinkTap: onLinkTap)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - List View

private struct ListView: View {
    let list: ListNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var body: some View {
        if list.ordered {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(list.children.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.body)
                            .foregroundColor(.secondary)
                        MarkdownRenderer(nodes: item.children, onLinkTap: onLinkTap)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(list.children.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundColor(.secondary)
                        MarkdownRenderer(nodes: item.children, onLinkTap: onLinkTap)
                    }
                }
            }
        }
    }
}

// MARK: - Code Block View

private struct CodeBlockView: View {
    let code: CodeBlockNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = code.language {
                HStack {
                    Text(language)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    Spacer()
                }
                .background(Color.secondary.opacity(0.1))
            }
            
            ScrollView(.horizontal, showsIndicators: true) {
                SyntaxHighlightedCode(code: code.code, language: code.language)
                    .padding()
            }
            .background(Color.secondary.opacity(0.1))
        }
        .cornerRadius(8)
    }
}

// MARK: - Syntax Highlighted Code

private struct SyntaxHighlightedCode: View {
    let code: String
    let language: String?
    
    var body: some View {
        // Simple syntax highlighting - can be enhanced with a proper library later
        Text(code)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.primary)
    }
}

// MARK: - Blockquote View

private struct BlockquoteView: View {
    let blockquote: BlockquoteNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 4)
            
            MarkdownRenderer(nodes: blockquote.children, onLinkTap: onLinkTap)
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(4)
    }
}

// MARK: - Table View

private struct TableView: View {
    let table: TableNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(table.children.enumerated()), id: \.offset) { rowIndex, row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.children.enumerated()), id: \.offset) { cellIndex, cell in
                        VStack(alignment: .leading, spacing: 4) {
                            inlineText(from: cell.children, onLinkTap: onLinkTap)
                                .font(.body)
                                .padding(8)
                        }
                        .frame(maxWidth: .infinity, alignment: alignmentForIndex(cellIndex))
                        .background(rowIndex == 0 ? Color.secondary.opacity(0.1) : Color.clear)
                        .overlay(
                            Rectangle()
                                .frame(width: 1)
                                .foregroundColor(Color.secondary.opacity(0.2)),
                            alignment: .trailing
                        )
                    }
                }
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.secondary.opacity(0.2)),
                    alignment: .bottom
                )
            }
            }
        }
    }
    
    private func alignmentForIndex(_ index: Int) -> Alignment {
        guard let align = table.align, index < align.count else {
            return .leading
        }
        
        switch align[index] {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }
}

// MARK: - Inline Text Helper

private func inlineAttributedString(from nodes: [InlineNode]) -> AttributedString {
    var result = AttributedString()
    
    for node in nodes {
        switch node {
        case .text(let text):
            result += AttributedString(text.value)
        case .strong(let strong):
            var strongText = inlineAttributedString(from: strong.children)
            strongText.inlinePresentationIntent = .stronglyEmphasized
            result += strongText
        case .emphasis(let emphasis):
            var emphasisText = inlineAttributedString(from: emphasis.children)
            emphasisText.inlinePresentationIntent = .emphasized
            result += emphasisText
        case .link(let link):
            var linkText = inlineAttributedString(from: link.children)
            linkText.foregroundColor = .accentColor
            if let url = URL(string: link.url) {
                linkText.link = url
            }
            result += linkText
        case .image(let image):
            result += AttributedString(image.alt ?? "")
        case .inlineCode(let code):
            var codeText = AttributedString(code.value)
            codeText.font = .monospaced(.body)()
            result += codeText
        }
    }
    
    return result
}

@MainActor
private struct InlineTextView: View {
    let nodes: [InlineNode]
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var body: some View {
        Text(inlineAttributedString(from: nodes))
    }
}

@MainActor
private func inlineText(from nodes: [InlineNode], onLinkTap: (@MainActor @Sendable (String) -> Void)? = nil) -> some View {
    InlineTextView(nodes: nodes, onLinkTap: onLinkTap)
}

// MARK: - Component View

private struct ComponentView: View {
    let component: ComponentNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var body: some View {
        switch component.name {
        case "Accordions":
            AccordionsView(component: component, onLinkTap: onLinkTap)
        case "Accordion":
            AccordionView(component: component, onLinkTap: onLinkTap)
        case "Tabs":
            TabsView(component: component, onLinkTap: onLinkTap)
        case "Tab":
            TabView(component: component, onLinkTap: onLinkTap)
        case "Callout":
            CalloutView(component: component, onLinkTap: onLinkTap)
        default:
            // Fallback for unknown components
            VStack(alignment: .leading, spacing: 8) {
                if let children = component.children {
                    MarkdownRenderer(nodes: children, onLinkTap: onLinkTap)
                }
            }
        }
    }
}

// MARK: - Strong View

private struct StrongView: View {
    let strong: StrongNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var body: some View {
        inlineText(from: strong.children, onLinkTap: onLinkTap)
    }
}

// MARK: - Emphasis View

private struct EmphasisView: View {
    let emphasis: EmphasisNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var body: some View {
        inlineText(from: emphasis.children, onLinkTap: onLinkTap)
    }
}

// MARK: - Link View

private struct LinkView: View {
    let link: LinkNode
    let onLinkTap: (@MainActor @Sendable (String) -> Void)?
    
    var body: some View {
        Button(action: {
            onLinkTap?(link.url)
        }) {
            inlineText(from: link.children, onLinkTap: onLinkTap)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Image View

private struct ImageView: View {
    let image: ImageNode
    
    var body: some View {
        AsyncImage(url: URL(string: image.url)) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let img):
                img
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                Text(image.alt ?? "Image")
                    .foregroundColor(.secondary)
            @unknown default:
                EmptyView()
            }
        }
    }
}

// MARK: - Inline Code View

private struct InlineCodeView: View {
    let code: InlineCodeNode
    
    var body: some View {
        Text(code.value)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
    }
}

