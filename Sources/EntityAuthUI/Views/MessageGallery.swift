import SwiftUI
import EntityAuthDomain

/// A gallery view showcasing all Message component variants and styles
public struct MessageGallery: View {
    @Environment(\.entityAuthProvider) private var provider
    @State private var selectedTab: GalleryTab = .layouts
    
    public enum GalleryTab: String, CaseIterable {
        case layouts = "Layouts"
        case styles = "Bubble Styles"
        case examples = "Real Examples"
        
        var icon: String {
            switch self {
            case .layouts: return "square.stack.3d.up"
            case .styles: return "paintbrush.fill"
            case .examples: return "bubble.left.and.bubble.right.fill"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        #if os(iOS)
        // iOS: Use standard bottom tab bar
        TabView(selection: $selectedTab) {
            layoutsView
                .tabItem {
                    Label(GalleryTab.layouts.rawValue, systemImage: GalleryTab.layouts.icon)
                }
                .tag(GalleryTab.layouts)
            
            stylesView
                .tabItem {
                    Label(GalleryTab.styles.rawValue, systemImage: GalleryTab.styles.icon)
                }
                .tag(GalleryTab.styles)
            
            examplesView
                .tabItem {
                    Label(GalleryTab.examples.rawValue, systemImage: GalleryTab.examples.icon)
                }
                .tag(GalleryTab.examples)
        }
        #else
        // macOS: Content with toolbar picker
        Group {
            switch selectedTab {
            case .layouts:
                layoutsView
            case .styles:
                stylesView
            case .examples:
                examplesView
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selectedTab) {
                    ForEach(GalleryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        #endif
    }
    
    // MARK: - Layouts View
    
    private var layoutsView: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 24) {
                    // Avatar Inline
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Avatar Inline")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Text("Avatar aligned with message bubble, no username")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        Message(
                            text: "Hey! Just wanted to check in on the progress.",
                            layout: .avatarInline,
                            bubbleStyle: .glass
                        )
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // Avatar with Username
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Avatar with Username")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Text("Avatar inline, username label above the bubble")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        Message(
                            text: "This variant is perfect when you want to show who sent the message!",
                            username: "John Doe",
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass
                        )
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // Avatar Stacked
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Avatar Stacked")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Text("Avatar and username on same row, message below")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        Message(
                            text: "This is perfect! The new variants make it so much easier to build custom chat interfaces.",
                            username: "Sarah Chen",
                            layout: .avatarStacked,
                            bubbleStyle: .glass
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer(minLength: 40)
            }
        }
    }
    
    // MARK: - Styles View
    
    private var stylesView: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 24) {
                    // Glass Style
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Glass")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Text("Glassmorphic effect matching app design")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        Message(
                            text: "Glass style with liquid glass effect",
                            layout: .avatarInline,
                            bubbleStyle: .glass
                        )
                        
                        Message(
                            text: "Perfect for modern, elegant chat interfaces",
                            username: "Designer",
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass
                        )
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // Tinted Glass Style
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tinted Glass")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Text("Liquid Glass with color tint using .tint() API")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        Message(
                            text: "Tinted glass with blue color",
                            layout: .avatarInline,
                            bubbleStyle: .tintedGlass(.blue)
                        )
                        
                        Message(
                            text: "Tinted glass with purple color",
                            username: "Designer",
                            layout: .avatarWithUsername,
                            bubbleStyle: .tintedGlass(.purple)
                        )
                        
                        Message(
                            text: "Tinted glass with orange color",
                            layout: .avatarInline,
                            bubbleStyle: .tintedGlass(.orange)
                        )
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // Filled Style
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filled")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Text("Solid color background with white text")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        Message(
                            text: "Filled style with solid blue background",
                            layout: .avatarInline,
                            bubbleStyle: .filled(.blue)
                        )
                        
                        Message(
                            text: "Filled style with solid purple background",
                            layout: .avatarInline,
                            bubbleStyle: .filled(.purple)
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer(minLength: 40)
            }
        }
    }
    
    // MARK: - Examples View
    
    private var examplesView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chat Conversation")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 16) {
                        // Message 1
                        Message(
                            text: "Hey team! I just pushed the new Message component to the repo.",
                            username: "Alex",
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass,
                            alignment: .leading
                        )
                        
                        // Message 2
                        Message(
                            text: "Amazing work! I love how clean the API is.",
                            username: "Sarah",
                            layout: .avatarStacked,
                            bubbleStyle: .glass,
                            alignment: .leading
                        )
                        
                        // Message 3
                        Message(
                            text: "This is going to make building chat UIs so much easier!",
                            layout: .avatarInline,
                            bubbleStyle: .glass,
                            alignment: .leading
                        )
                        
                        // Message 4 (from current user, aligned right)
                        Message(
                            text: "Thanks! Let me know if you need any other variants.",
                            username: "You",
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass,
                            alignment: .trailing
                        )
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.tertiary.opacity(0.3), lineWidth: 1)
                    )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Support Chat Example")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 16) {
                        Message(
                            text: "Hi! How can I help you today?",
                            username: "Support Agent",
                            layout: .avatarStacked,
                            bubbleStyle: .glass,
                            alignment: .leading
                        )
                        
                        Message(
                            text: "I'm having trouble with the authentication flow.",
                            username: "You",
                            layout: .avatarInline,
                            bubbleStyle: .glass,
                            alignment: .trailing
                        )
                        
                        Message(
                            text: "No problem! Let me help you with that. Can you describe what's happening?",
                            username: "Support Agent",
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass,
                            alignment: .leading
                        )
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.tertiary.opacity(0.3), lineWidth: 1)
                    )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Glass & Tinted Glass Example")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 16) {
                        Message(
                            text: "Have you tried the new tinted glass style?",
                            username: "Alex",
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass,
                            alignment: .leading
                        )
                        
                        Message(
                            text: "Yes! The color tint using Liquid Glass API looks incredible!",
                            username: "You",
                            layout: .avatarInline,
                            bubbleStyle: .tintedGlass(.blue),
                            alignment: .trailing
                        )
                        
                        Message(
                            text: "The glassmorphic effect with tints really elevates the design. Very modern!",
                            username: "Sarah",
                            layout: .avatarStacked,
                            bubbleStyle: .tintedGlass(.purple),
                            alignment: .leading
                        )
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.tertiary.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }
}

