//
//  ProcessedPage.swift
//  EntityDocsSwift
//
//  Models for processed MDX content
//

import Foundation

// MARK: - ProcessedPage

public struct ProcessedPage: Codable, Identifiable {
    public let slug: [String]
    public let url: String
    public let frontmatter: Frontmatter?
    public let content: ProcessedContent
    public let toc: [TableOfContentsItem]
    
    public var id: String {
        url
    }
    
    public var title: String {
        frontmatter?.title ?? slug.last ?? "Untitled"
    }
    
    public var description: String? {
        frontmatter?.description
    }
    
    public var date: Date? {
        guard let dateString = frontmatter?.date, dateString != "TBD" else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return formatter.date(from: dateString)
    }
}

// MARK: - Frontmatter

public struct Frontmatter: Codable {
    public let title: String?
    public let description: String?
    public let date: String?
    public let version: String?
    
    private enum CodingKeys: String, CodingKey {
        case title, description, date, version
    }
}

// MARK: - ProcessedContent

public struct ProcessedContent: Codable {
    public let type: String
    public let children: [ProcessedNode]
}

// MARK: - ProcessedNode

public indirect enum ProcessedNode: Codable {
    case heading(HeadingNode)
    case paragraph(ParagraphNode)
    case list(ListNode)
    case code(CodeBlockNode)
    case blockquote(BlockquoteNode)
    case table(TableNode)
    case thematicBreak
    case component(ComponentNode)
    case text(TextNode)
    case strong(StrongNode)
    case emphasis(EmphasisNode)
    case link(LinkNode)
    case image(ImageNode)
    case inlineCode(InlineCodeNode)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "heading":
            self = .heading(try HeadingNode(from: decoder))
        case "paragraph":
            self = .paragraph(try ParagraphNode(from: decoder))
        case "list":
            self = .list(try ListNode(from: decoder))
        case "code":
            self = .code(try CodeBlockNode(from: decoder))
        case "blockquote":
            self = .blockquote(try BlockquoteNode(from: decoder))
        case "table":
            self = .table(try TableNode(from: decoder))
        case "thematicBreak":
            self = .thematicBreak
        case "component":
            self = .component(try ComponentNode(from: decoder))
        case "text":
            self = .text(try TextNode(from: decoder))
        case "strong":
            self = .strong(try StrongNode(from: decoder))
        case "emphasis":
            self = .emphasis(try EmphasisNode(from: decoder))
        case "link":
            self = .link(try LinkNode(from: decoder))
        case "image":
            self = .image(try ImageNode(from: decoder))
        case "inlineCode":
            self = .inlineCode(try InlineCodeNode(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown node type: \(type)"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .heading(let node):
            try container.encode("heading", forKey: .type)
            try node.encode(to: encoder)
        case .paragraph(let node):
            try container.encode("paragraph", forKey: .type)
            try node.encode(to: encoder)
        case .list(let node):
            try container.encode("list", forKey: .type)
            try node.encode(to: encoder)
        case .code(let node):
            try container.encode("code", forKey: .type)
            try node.encode(to: encoder)
        case .blockquote(let node):
            try container.encode("blockquote", forKey: .type)
            try node.encode(to: encoder)
        case .table(let node):
            try container.encode("table", forKey: .type)
            try node.encode(to: encoder)
        case .thematicBreak:
            try container.encode("thematicBreak", forKey: .type)
        case .component(let node):
            try container.encode("component", forKey: .type)
            try node.encode(to: encoder)
        case .text(let node):
            try container.encode("text", forKey: .type)
            try node.encode(to: encoder)
        case .strong(let node):
            try container.encode("strong", forKey: .type)
            try node.encode(to: encoder)
        case .emphasis(let node):
            try container.encode("emphasis", forKey: .type)
            try node.encode(to: encoder)
        case .link(let node):
            try container.encode("link", forKey: .type)
            try node.encode(to: encoder)
        case .image(let node):
            try container.encode("image", forKey: .type)
            try node.encode(to: encoder)
        case .inlineCode(let node):
            try container.encode("inlineCode", forKey: .type)
            try node.encode(to: encoder)
        }
    }
}

// MARK: - Node Types

public struct HeadingNode: Codable {
    public let depth: Int
    public let children: [InlineNode]
    public let id: String?
}

public struct ParagraphNode: Codable {
    public let children: [InlineNode]
}

public struct ListNode: Codable {
    public let ordered: Bool
    public let children: [ListItemNode]
}

public struct ListItemNode: Codable {
    public let children: [ProcessedNode]
}

public struct CodeBlockNode: Codable {
    public let language: String?
    public let code: String
}

public struct BlockquoteNode: Codable {
    public let children: [ProcessedNode]
}

public struct TableNode: Codable {
    public let align: [String?]?
    public let children: [TableRowNode]
}

public struct TableRowNode: Codable {
    public let children: [TableCellNode]
}

public struct TableCellNode: Codable {
    public let children: [InlineNode]
}

public struct ComponentNode: Codable {
    public let name: String
    public let props: [String: JSONValue]
    public let children: [ProcessedNode]?
}

public struct TextNode: Codable {
    public let value: String
}

public struct StrongNode: Codable {
    public let children: [InlineNode]
}

public struct EmphasisNode: Codable {
    public let children: [InlineNode]
}

public struct LinkNode: Codable {
    public let url: String
    public let title: String?
    public let children: [InlineNode]
}

public struct ImageNode: Codable {
    public let url: String
    public let alt: String?
    public let title: String?
}

public struct InlineCodeNode: Codable {
    public let value: String
}

// MARK: - InlineNode

public enum InlineNode: Codable {
    case text(TextNode)
    case strong(StrongNode)
    case emphasis(EmphasisNode)
    case link(LinkNode)
    case image(ImageNode)
    case inlineCode(InlineCodeNode)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            self = .text(try TextNode(from: decoder))
        case "strong":
            self = .strong(try StrongNode(from: decoder))
        case "emphasis":
            self = .emphasis(try EmphasisNode(from: decoder))
        case "link":
            self = .link(try LinkNode(from: decoder))
        case "image":
            self = .image(try ImageNode(from: decoder))
        case "inlineCode":
            self = .inlineCode(try InlineCodeNode(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown inline node type: \(type)"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let node):
            try container.encode("text", forKey: .type)
            try node.encode(to: encoder)
        case .strong(let node):
            try container.encode("strong", forKey: .type)
            try node.encode(to: encoder)
        case .emphasis(let node):
            try container.encode("emphasis", forKey: .type)
            try node.encode(to: encoder)
        case .link(let node):
            try container.encode("link", forKey: .type)
            try node.encode(to: encoder)
        case .image(let node):
            try container.encode("image", forKey: .type)
            try node.encode(to: encoder)
        case .inlineCode(let node):
            try container.encode("inlineCode", forKey: .type)
            try node.encode(to: encoder)
        }
    }
}

// MARK: - TableOfContentsItem

public struct TableOfContentsItem: Codable, Identifiable {
    public let title: String
    public let id: String
    public let depth: Int
    public let children: [TableOfContentsItem]?
    
    public var identifier: String { id }
}

// MARK: - JSONValue

public enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode JSONValue"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
    
    public var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
    
    public var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }
}

