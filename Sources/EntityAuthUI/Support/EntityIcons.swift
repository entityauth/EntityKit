//
//  EntityIcons.swift
//  Generated from @entityy/entity-icons
//
//  DO NOT EDIT - This file is auto-generated
//

import SwiftUI

/// Type-safe access to Entity Icons
public enum EntityIcon: String, CaseIterable {
    case github_dark = "GithubDark"
    case github_light = "GithubLight"
    case google = "Google"
    case passkey_dark = "PasskeyDark"
    case passkey_light = "PasskeyLight"
    case at_sign_dark = "AtSignDark"
    case at_sign_light = "AtSignLight"
    case chat = "Chat"
    case delete_x = "DeleteX"
    case folder = "Folder"
    case home = "Home"
    case inbox = "Inbox"
    case layers = "Layers"
    case lock = "Lock"
    case paper_place = "PaperPlace"
    case password_dark = "PasswordDark"
    case password_light = "PasswordLight"
    case power_off = "PowerOff"
    case settings = "Settings"
    case sitemap = "Sitemap"
    case sparkle = "Sparkle"
    case square_grid = "SquareGrid"
    case user = "User"
    case users = "Users"
    
    /// SwiftUI Image for this icon with original colors preserved
    public var image: Image {
        Image(self.rawValue)
            .renderingMode(.original)
    }
    
    /// SwiftUI Image for this icon as a template (monochrome, tintable)
    public var templateImage: Image {
        Image(self.rawValue)
            .renderingMode(.template)
    }
    
    /// UIKit UIImage for this icon
    #if canImport(UIKit)
    public var uiImage: UIImage? {
        UIImage(named: self.rawValue)?.withRenderingMode(.alwaysTemplate)
    }
    #endif
    
    /// AppKit NSImage for this icon
    #if canImport(AppKit)
    public var nsImage: NSImage? {
        if let image = NSImage(named: self.rawValue) {
            image.isTemplate = true
            return image
        }
        return nil
    }
    #endif
}

// MARK: - SwiftUI View Extension
extension Image {
    /// Create an Entity Icon with template rendering
    public static func entityIcon(_ icon: EntityIcon) -> Image {
        icon.image
    }
}
