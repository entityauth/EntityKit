import SwiftUI

/// A chat message component that combines UserDisplay with message bubbles.
/// Provides pre-built layouts for common chat message patterns.
public struct Message: View {
    @Environment(\.entityAuthProvider) private var provider
    
    /// Message layout variant
    public enum Layout {
        case avatarInline       // Avatar aligned with message bubble (no username)
        case avatarWithUsername // Avatar inline, username above the bubble
        case avatarStacked      // Avatar and username on same row, message below
    }
    
    /// Message bubble style
    public enum BubbleStyle {
        case filled(Color)      // Solid color background
        case glass              // Glassmorphic effect matching app design
        case tintedGlass(Color) // Liquid Glass with color tint
    }
    
    private let layout: Layout
    private let text: String
    private let username: String?
    private let bubbleStyle: BubbleStyle
    private let alignment: HorizontalAlignment
    
    /// Create a message with specified layout and style
    /// - Parameters:
    ///   - text: The message text content
    ///   - username: Optional username to display (required for avatarWithUsername and avatarStacked)
    ///   - layout: How to arrange the avatar and message
    ///   - bubbleStyle: Visual style of the message bubble
    ///   - alignment: Horizontal alignment of the message (.leading or .trailing)
    public init(
        text: String,
        username: String? = nil,
        layout: Layout = .avatarInline,
        bubbleStyle: BubbleStyle = .filled(.blue),
        alignment: HorizontalAlignment = .leading
    ) {
        self.text = text
        self.username = username
        self.layout = layout
        self.bubbleStyle = bubbleStyle
        self.alignment = alignment
    }
    
    public var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            switch layout {
            case .avatarInline:
                avatarInlineLayout
            case .avatarWithUsername:
                avatarWithUsernameLayout
            case .avatarStacked:
                avatarStackedLayout
            }
        }
    }
    
    // MARK: - Layout Variants
    
    private var avatarInlineLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            if alignment == .leading {
                UserDisplay(provider: provider, variant: .avatarOnly)
                messageBubble
                Spacer()
            } else {
                Spacer()
                messageBubble
                UserDisplay(provider: provider, variant: .avatarOnly)
            }
        }
    }
    
    private var avatarWithUsernameLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            if alignment == .leading {
                UserDisplay(provider: provider, variant: .avatarOnly)
                VStack(alignment: .leading, spacing: 4) {
                    if let username = username {
                        Text(username)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    messageBubble
                }
                Spacer()
            } else {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let username = username {
                        Text(username)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    messageBubble
                }
                UserDisplay(provider: provider, variant: .avatarOnly)
            }
        }
    }
    
    private var avatarStackedLayout: some View {
        VStack(alignment: alignment, spacing: 6) {
            HStack(spacing: 8) {
                if alignment == .leading {
                    UserDisplay(provider: provider, variant: .avatarOnly)
                    if let username = username {
                        Text(username)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                } else {
                    Spacer()
                    if let username = username {
                        Text(username)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    UserDisplay(provider: provider, variant: .avatarOnly)
                }
            }
            
            messageBubble
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        }
    }
    
    // MARK: - Message Bubble
    
    private var messageBubble: some View {
        Text(text)
            .font(.system(.body, design: .rounded))
            .padding(12)
            .background(bubbleBackground)
            .foregroundStyle(bubbleForegroundColor)
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        switch bubbleStyle {
        case .filled(let color):
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color)
        case .glass:
            glassBackgroundView(tintColor: nil)
        case .tintedGlass(let color):
            glassBackgroundView(tintColor: color)
        }
    }
    
    @ViewBuilder
    private func glassBackgroundView(tintColor: Color?) -> some View {
        Group {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .glassEffect(
                        tintColor != nil ? .regular.tint(tintColor!).interactive(true) : .regular.interactive(true),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if let tintColor = tintColor {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(tintColor.opacity(0.1))
                        }
                    }
            }
            #elseif os(macOS)
            if #available(macOS 15.0, *) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .glassEffect(
                        tintColor != nil ? .regular.tint(tintColor!).interactive(true) : .regular.interactive(true),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if let tintColor = tintColor {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(tintColor.opacity(0.1))
                        }
                    }
            }
            #else
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    if let tintColor = tintColor {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tintColor.opacity(0.1))
                    }
                }
            #endif
        }
    }
    
    private var bubbleForegroundColor: Color {
        switch bubbleStyle {
        case .filled:
            return .white
        case .glass, .tintedGlass:
            return .primary
        }
    }
}

