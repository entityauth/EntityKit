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
        case advanced = "Advanced"
        
        var icon: String {
            switch self {
            case .layouts: return "square.stack.3d.up"
            case .styles: return "paintbrush.fill"
            case .examples: return "bubble.left.and.bubble.right.fill"
            case .advanced: return "wand.and.stars"
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
            
            advancedView
                .tabItem {
                    Label(GalleryTab.advanced.rawValue, systemImage: GalleryTab.advanced.icon)
                }
                .tag(GalleryTab.advanced)
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
            case .advanced:
                advancedView
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
                        
                        Message(
                            text: "Hey! Just wanted to check in on the progress.",
                            author: MessageAuthor(id: "1", name: "Alex Chen"),
                            timestamp: Date().addingTimeInterval(-3600),
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
                        
                        Message(
                            text: "This variant is perfect when you want to show who sent the message!",
                            author: MessageAuthor(id: "2", name: "John Doe"),
                            timestamp: Date().addingTimeInterval(-7200),
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
                        
                        Message(
                            text: "This is perfect! The new variants make it so much easier to build custom chat interfaces.",
                            author: MessageAuthor(id: "3", name: "Sarah Chen"),
                            timestamp: Date().addingTimeInterval(-1800),
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
                        
                        Message(
                            text: "Glass style with liquid glass effect",
                            author: MessageAuthor(id: "1", name: "Alex"),
                            timestamp: Date().addingTimeInterval(-300),
                            layout: .avatarInline,
                            bubbleStyle: .glass
                        )
                        
                        Message(
                            text: "Perfect for modern, elegant chat interfaces",
                            author: MessageAuthor(id: "2", name: "Designer"),
                            timestamp: Date().addingTimeInterval(-600),
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
                        
                        Message(
                            text: "Tinted glass with blue color",
                            author: MessageAuthor(id: "1", name: "Sarah"),
                            timestamp: Date().addingTimeInterval(-120),
                            layout: .avatarInline,
                            bubbleStyle: .tintedGlass(.blue)
                        )
                        
                        Message(
                            text: "Tinted glass with purple color",
                            author: MessageAuthor(id: "2", name: "Designer"),
                            timestamp: Date().addingTimeInterval(-240),
                            layout: .avatarWithUsername,
                            bubbleStyle: .tintedGlass(.purple)
                        )
                        
                        Message(
                            text: "Tinted glass with orange color",
                            author: MessageAuthor(id: "3", name: "Mike"),
                            timestamp: Date().addingTimeInterval(-360),
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
                        
                        Message(
                            text: "Filled style with solid blue background",
                            author: MessageAuthor(id: "1", name: "Emma"),
                            timestamp: Date().addingTimeInterval(-180),
                            layout: .avatarInline,
                            bubbleStyle: .filled(.blue)
                        )
                        
                        Message(
                            text: "Filled style with solid purple background",
                            author: MessageAuthor(id: "2", name: "David"),
                            timestamp: Date().addingTimeInterval(-480),
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
                            author: MessageAuthor(id: "1", name: "Alex"),
                            timestamp: Date().addingTimeInterval(-3600),
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass,
                            alignment: .leading,
                            actions: MessageActions(
                                onReply: { print("Reply to Alex") },
                                onCopy: { print("Copy message") }
                            )
                        )
                        
                        // Message 2
                        Message(
                            text: "Amazing work! I love how clean the API is.",
                            author: MessageAuthor(id: "2", name: "Sarah"),
                            timestamp: Date().addingTimeInterval(-3000),
                            layout: .avatarStacked,
                            bubbleStyle: .glass,
                            alignment: .leading,
                            actions: MessageActions(
                                onReply: { print("Reply to Sarah") },
                                onCopy: { print("Copy message") }
                            )
                        )
                        
                        // Message 3
                        Message(
                            text: "This is going to make building chat UIs so much easier!",
                            author: MessageAuthor(id: "3", name: "Mike"),
                            timestamp: Date().addingTimeInterval(-2400),
                            layout: .avatarInline,
                            bubbleStyle: .glass,
                            alignment: .leading,
                            actions: MessageActions(
                                onReply: { print("Reply to Mike") },
                                onCopy: { print("Copy message") }
                            )
                        )
                        
                        // Message 4 (from current user, aligned right)
                        Message(
                            text: "Thanks! Let me know if you need any other variants.",
                            author: MessageAuthor(id: "4", name: "You"),
                            isCurrentUser: true,
                            timestamp: Date().addingTimeInterval(-1800),
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass,
                            alignment: .trailing,
                            actions: MessageActions(
                                onEdit: { print("Edit message") },
                                onCopy: { print("Copy message") },
                                onDelete: { print("Delete message") }
                            )
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
                            author: MessageAuthor(id: "support", name: "Support Agent"),
                            timestamp: Date().addingTimeInterval(-1200),
                            layout: .avatarStacked,
                            bubbleStyle: .glass,
                            alignment: .leading
                        )
                        
                        Message(
                            text: "I'm having trouble with the authentication flow.",
                            author: MessageAuthor(id: "user", name: "You"),
                            isCurrentUser: true,
                            timestamp: Date().addingTimeInterval(-900),
                            layout: .avatarInline,
                            bubbleStyle: .glass,
                            alignment: .trailing
                        )
                        
                        Message(
                            text: "No problem! Let me help you with that. Can you describe what's happening?",
                            author: MessageAuthor(id: "support", name: "Support Agent"),
                            timestamp: Date().addingTimeInterval(-600),
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
                            author: MessageAuthor(id: "1", name: "Alex"),
                            timestamp: Date().addingTimeInterval(-1500),
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass,
                            alignment: .leading
                        )
                        
                        Message(
                            text: "Yes! The color tint using Liquid Glass API looks incredible!",
                            author: MessageAuthor(id: "2", name: "You"),
                            isCurrentUser: true,
                            timestamp: Date().addingTimeInterval(-1200),
                            layout: .avatarInline,
                            bubbleStyle: .tintedGlass(.blue),
                            alignment: .trailing
                        )
                        
                        Message(
                            text: "The glassmorphic effect with tints really elevates the design. Very modern!",
                            author: MessageAuthor(id: "3", name: "Sarah"),
                            timestamp: Date().addingTimeInterval(-900),
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
    
    // MARK: - Advanced View (Custom Content)
    
    private var advancedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Content Support")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("Use the ViewBuilder content parameter to compose your own message content with the beautiful Message styling.")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Example 1: Rich Text / Custom View
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rich Content Example")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 16) {
                        // Message with custom rich content
                        Message(
                            author: MessageAuthor(id: "1", name: "Product Designer"),
                            timestamp: Date().addingTimeInterval(-3600),
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass,
                            alignment: .leading
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Check out the new feature!")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Authentication flows")
                                }
                                .font(.system(.callout, design: .rounded))
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("User profile management")
                                }
                                .font(.system(.callout, design: .rounded))
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Organization switching")
                                }
                                .font(.system(.callout, design: .rounded))
                            }
                        }
                        
                        // Message with image/media content
                        Message(
                            author: MessageAuthor(id: "2", name: "Developer"),
                            timestamp: Date().addingTimeInterval(-2400),
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass,
                            alignment: .leading,
                            actions: MessageActions(
                                onReply: { print("Reply") },
                                onCopy: { print("Copy") }
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Here's a preview of the UI:")
                                    .font(.system(.body, design: .rounded))
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.quaternary)
                                    .frame(height: 120)
                                    .overlay {
                                        VStack(spacing: 4) {
                                            Image(systemName: "photo")
                                                .font(.system(size: 32))
                                                .foregroundStyle(.secondary)
                                            Text("Image Preview")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                            }
                        }
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
                
                // Example 2: Code Snippet
                VStack(alignment: .leading, spacing: 12) {
                    Text("Code Example")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Text("Customer can use their PageEditorView or any custom content:")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        codeBlock("""
                        Message(
                            author: MessageAuthor(
                                id: message.authorId,
                                name: message.author.name,
                                avatarURL: message.author.avatarURL
                            ),
                            timestamp: message.createdAt,
                            layout: .avatarWithUsername,
                            bubbleStyle: .glass,
                            actions: MessageActions(
                                onDelete: { deleteMessage(message.id) }
                            )
                        ) {
                            // Use your own rich text editor!
                            PageEditorView(pageId: message.pageId, embedded: true)
                        }
                        """)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    )
                }
                
                // Example 3: Real-world usage
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Content, Our Styling")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 16) {
                        // Simulating a custom PageEditor-style message
                        Message(
                            author: MessageAuthor(id: "1", name: "Team Lead"),
                            timestamp: Date().addingTimeInterval(-1800),
                            layout: .avatarStacked,
                            bubbleStyle: .glass,
                            alignment: .leading,
                            actions: MessageActions(
                                onEdit: { print("Edit") },
                                onReply: { print("Reply") },
                                onCopy: { print("Copy") },
                                onDelete: { print("Delete") }
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Project Update")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                
                                Text("The new authentication system is ready for testing. Here are the key improvements:")
                                    .font(.system(.body, design: .rounded))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    bulletPoint("Passkey support")
                                    bulletPoint("Multi-organization management")
                                    bulletPoint("Enhanced security features")
                                }
                                .padding(.leading, 8)
                            }
                        }
                        
                        // Reply from current user
                        Message(
                            author: MessageAuthor(id: "2", name: "You"),
                            isCurrentUser: true,
                            timestamp: Date().addingTimeInterval(-900),
                            layout: .avatarInline,
                            bubbleStyle: .glass,
                            alignment: .trailing,
                            actions: MessageActions(
                                onEdit: { print("Edit") },
                                onDelete: { print("Delete") }
                            )
                        ) {
                            Text("Awesome! I'll start testing the passkey integration today.")
                                .font(.system(.body, design: .rounded))
                        }
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
    
    // MARK: - Helper Views
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(.body, design: .rounded))
        }
    }
    
    private func codeBlock(_ code: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

