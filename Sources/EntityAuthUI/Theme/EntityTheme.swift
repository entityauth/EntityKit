import SwiftUI

public struct EntityTheme: Equatable, Sendable {
    public struct Colors: Equatable, Sendable {
        public var primary: Color
        public var background: Color
        public var text: Color

        public init(primary: Color, background: Color, text: Color) {
            self.primary = primary
            self.background = background
            self.text = text
        }
    }

    public struct Design: Equatable, Sendable {
        public var cornerRadius: CGFloat

        public init(cornerRadius: CGFloat) {
            self.cornerRadius = cornerRadius
        }
    }

    public var colors: Colors
    public var design: Design

    public init(colors: Colors, design: Design) {
        self.colors = colors
        self.design = design
    }

    public static let `default` = EntityTheme(
        colors: .init(primary: .accentColor, background: .clear, text: .primary),
        design: .init(cornerRadius: 12)
    )
}

private struct EntityThemeKey: EnvironmentKey {
    static let defaultValue: EntityTheme = .default
}

public extension EnvironmentValues {
    var entityTheme: EntityTheme {
        get { self[EntityThemeKey.self] }
        set { self[EntityThemeKey.self] = newValue }
    }
}

public extension View {
    func entityTheme(_ theme: EntityTheme) -> some View {
        environment(\.entityTheme, theme)
    }
}


