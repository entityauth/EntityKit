import Foundation

public enum ComponentKind: String, CaseIterable, Sendable {
    case authView = "auth-view"
    case userButton = "user-button"
    case userProfileView = "user-profile-view"
}

public struct ComponentItem: Identifiable, Sendable, Equatable {
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
        title: "User Button",
        slug: ["user", "button"],
        description: "Avatar button opening profile",
        keywords: ["user", "profile"],
        group: "Core",
        component: .userButton
    ),
    .init(
        title: "User Profile",
        slug: ["user", "profile"],
        description: "Account management surface",
        keywords: ["user", "account"],
        group: "Core",
        component: .userProfileView
    )
]


