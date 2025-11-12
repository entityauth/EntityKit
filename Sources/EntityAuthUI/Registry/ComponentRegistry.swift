import Foundation

public enum ComponentKind: String, CaseIterable, Sendable {
    case authView = "auth-view"
    case userProfile = "user-profile"
    case userDisplay = "user-display"
    case organizationDisplay = "organization-display"
    case message = "message"
    case organizationSwitcher = "organization-switcher"
    case docsViewer = "docs-viewer"
}

public struct ComponentItem: Identifiable, Sendable, Equatable, Hashable {
    public var id: String { slug.joined(separator: "/") }
    public var title: String
    public var slug: [String]
    public var description: String
    public var keywords: [String]
    public var group: String
    public var component: ComponentKind
}

public let componentRegistry: [ComponentItem] = [
    .init(
        title: "Auth View",
        slug: ["auth", "view"],
        description: "Complete sign in/up flow with embedded and modal variants",
        keywords: ["auth", "signin", "signup", "modal"],
        group: "Core",
        component: .authView
    ),
    .init(
        title: "User Profile",
        slug: ["user", "profile"],
        description: "Profile access button and surface",
        keywords: ["user", "profile"],
        group: "Core",
        component: .userProfile
    ),
    .init(
        title: "User Display",
        slug: ["user", "display"],
        description: "Modern user identity components with Liquid Glass design - display variants and interactive buttons",
        keywords: ["user", "identity", "avatar", "button", "profile"],
        group: "Core",
        component: .userDisplay
    ),
    .init(
        title: "Organization Display",
        slug: ["org", "display"],
        description: "Modern organization identity components with Liquid Glass design - display variants for showing org info",
        keywords: ["organization", "org", "identity", "avatar", "display"],
        group: "Core",
        component: .organizationDisplay
    ),
    .init(
        title: "Message",
        slug: ["message", "chat"],
        description: "Pre-built chat message components with avatar, username, and bubble styles",
        keywords: ["message", "chat", "bubble", "conversation", "messaging"],
        group: "Core",
        component: .message
    ),
    .init(
        title: "Organization Switcher",
        slug: ["org", "switcher"],
        description: "List, switch, and create organizations",
        keywords: ["org", "organization", "switch"],
        group: "Core",
        component: .organizationSwitcher
    ),
    .init(
        title: "Docs Viewer",
        slug: ["docs", "viewer"],
        description: "MDX-based documentation and changelog viewer",
        keywords: ["docs", "documentation", "changelog", "mdx", "markdown"],
        group: "EntityDocs",
        component: .docsViewer
    )
]


