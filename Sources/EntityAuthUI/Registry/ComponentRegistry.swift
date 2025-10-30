import Foundation

public enum ComponentKind: String, CaseIterable, Sendable {
    case authView = "auth-view"
    case authViewModal = "auth-view-modal"
    case userProfile = "user-profile"
    case userDisplay = "user-display"
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
        description: "Complete sign in/up flow",
        keywords: ["auth", "signin", "signup"],
        group: "Core",
        component: .authView
    ),
    .init(
        title: "Auth View (Modal Button)",
        slug: ["auth", "modal"],
        description: "Button that presents AuthView in a modal",
        keywords: ["auth", "modal", "signin", "signup"],
        group: "Core",
        component: .authViewModal
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
        description: "Compact identity display",
        keywords: ["user", "identity"],
        group: "Core",
        component: .userDisplay
    )
]


