import SwiftUI
import EntityAuthDomain

/// A composable chat message component with support for custom content, authors, and actions.
/// Provides pre-built layouts for common chat message patterns with beautiful styling.
public struct Message<Content: View>: View {
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
    
    private let author: MessageAuthor?
    private let authorId: String?
    private let workspaceTenantId: String?
    private let isCurrentUser: Bool
    private let timestamp: Date?
    private let layout: Layout
    private let bubbleStyle: BubbleStyle
    private let alignment: HorizontalAlignment
    private let showTimestamp: Bool
    private let actions: MessageActions?
    private let content: Content
    
    @Environment(\.entityAuthProvider) private var entityAuth
    @State private var resolvedAuthor: MessageAuthor?
    @State private var workspaceMembers: [WorkspaceMemberDTO] = []
    @State private var isLoadingMembers = false
    @State private var isHovered: Bool = false
    @State private var isRevealingTimestamp: Bool = false
    
    /// Create a composable message with custom content
    /// - Parameters:
    ///   - author: Author information (name, avatar). Pass nil to use current user from environment or resolve from workspace members
    ///   - authorId: Author ID - if provided along with workspaceTenantId, author info will be resolved from workspace members
    ///   - workspaceTenantId: Workspace tenant ID - required if authorId is provided
    ///   - isCurrentUser: Whether this message is from the current user (affects alignment and styling)
    ///   - timestamp: Optional timestamp to display
    ///   - layout: How to arrange the avatar and message
    ///   - bubbleStyle: Visual style of the message bubble
    ///   - alignment: Horizontal alignment of the message (.leading or .trailing)
    ///   - showTimestamp: Whether to show the timestamp (default: true if timestamp is provided)
    ///   - actions: Optional actions (delete, edit, etc.)
    ///   - content: Custom content to display in the message bubble
    public init(
        author: MessageAuthor? = nil,
        authorId: String? = nil,
        workspaceTenantId: String? = nil,
        isCurrentUser: Bool = false,
        timestamp: Date? = nil,
        layout: Layout = .avatarInline,
        bubbleStyle: BubbleStyle = .glass,
        alignment: HorizontalAlignment = .leading,
        showTimestamp: Bool = true,
        actions: MessageActions? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.author = author
        self.authorId = authorId
        self.workspaceTenantId = workspaceTenantId
        self.isCurrentUser = isCurrentUser
        self.timestamp = timestamp
        self.layout = layout
        self.bubbleStyle = bubbleStyle
        self.alignment = alignment
        self.showTimestamp = showTimestamp && timestamp != nil
        self.actions = actions
        self.content = content()
        self._resolvedAuthor = State(initialValue: author)
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
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
        #if os(iOS)
        .gesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                .onChanged { value in
                    // Reveal when swiping from right to left
                    if value.translation.width < -20 {
                        if isRevealingTimestamp == false {
                            isRevealingTimestamp = true
                        }
                    } else if value.translation.width > -5 {
                        if isRevealingTimestamp == true {
                            isRevealingTimestamp = false
                        }
                    }
                }
                .onEnded { _ in
                    // Hide shortly after end to mimic iMessage behavior
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isRevealingTimestamp = false
                    }
                }
        )
        #endif
        .contextMenu {
            if let actions = actions {
                contextMenuContent(actions)
            }
        }
        .task {
            await resolveAuthorIfNeeded()
        }
        .onChange(of: authorId) { _ in
            Task { await resolveAuthorIfNeeded() }
        }
        .onChange(of: workspaceTenantId) { _ in
            Task { await resolveAuthorIfNeeded() }
        }
    }
    
    @MainActor
    private func resolveAuthorIfNeeded() async {
        print("[EA][Swift][Message] resolveAuthorIfNeeded begin authorId=\(authorId ?? "nil") workspaceTenantId=\(workspaceTenantId ?? "nil")")
        // If author is already provided, use it
        if let author = author {
            resolvedAuthor = author
            print("[EA][Swift][Message] Using provided author id=\(author.id) name=\(author.name) hasAvatar=\(author.avatarURL != nil)")
            return
        }
        
        // If authorId and workspaceTenantId are provided, resolve from workspace members
        guard let authorId = authorId else {
            resolvedAuthor = nil
            print("[EA][Swift][Message] Missing authorId or workspaceTenantId - avatar will be hidden")
            return
        }
        // Derive tenant id to use: if provided workspaceTenantId is missing or looks like an orgId, fallback to active org's workspaceTenantId
        var tenantIdToUse: String? = workspaceTenantId
        let looksLikeOrgId = (tenantIdToUse?.hasPrefix("jd") ?? false) && (tenantIdToUse?.count ?? 0) > 12
        if tenantIdToUse == nil || looksLikeOrgId {
            do {
                if let active = try await entityAuth.activeOrganization() {
                    tenantIdToUse = active.workspaceTenantId
                    print("[EA][Swift][Message] Fallback tenant from active org: \(tenantIdToUse ?? "nil")")
                }
            } catch {
                print("[EA][Swift][Message] Failed to read activeOrganization: \(error)")
            }
        }
        guard let resolvedTenant = tenantIdToUse else {
            resolvedAuthor = nil
            print("[EA][Swift][Message] No valid workspaceTenantId after fallback - avatar will be hidden")
            return
        }
        
        // Fetch workspace members if not already loaded
        if workspaceMembers.isEmpty && !isLoadingMembers {
            isLoadingMembers = true
            defer { isLoadingMembers = false }
            
            do {
                // Use the environment's entityAuth provider to fetch workspace members
                workspaceMembers = try await entityAuth.listWorkspaceMembers(workspaceTenantId: resolvedTenant)
                print("[EA][Swift][Message] Fetched workspace members count=\(workspaceMembers.count) sampleIds=\(workspaceMembers.prefix(3).map { $0.id }.joined(separator: ","))")
            } catch {
                // Silently fail - will show fallback
                print("[EA][Swift][Message] ERROR fetching workspace members: \(error)")
                return
            }
        }
        
        // Find the member matching authorId
        if let member = workspaceMembers.first(where: { $0.id == authorId }) {
            resolvedAuthor = MessageAuthor(
                id: member.id,
                name: member.username ?? member.email ?? member.id,
                avatarURL: member.imageUrl
            )
            print("[EA][Swift][Message] Resolved author id=\(member.id) name=\(member.username ?? member.email ?? member.id) hasAvatar=\(member.imageUrl != nil)")
        } else {
            resolvedAuthor = nil
            print("[EA][Swift][Message] No matching member for authorId=\(authorId)")
        }
    }
    
    // MARK: - Layout Variants
    
    private var avatarInlineLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            if alignment == .leading {
                avatarView
                VStack(alignment: .leading, spacing: 4) {
                    messageBubble
                    if shouldRevealTimestamp, showTimestamp, let timestamp = timestamp {
                        timestampView(timestamp)
                    }
                }
                Spacer()
            } else {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    messageBubble
                    if shouldRevealTimestamp, showTimestamp, let timestamp = timestamp {
                        timestampView(timestamp)
                    }
                }
                avatarView
            }
        }
    }
    
    private var avatarWithUsernameLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            if alignment == .leading {
                avatarView
                VStack(alignment: .leading, spacing: 4) {
                    if let author = resolvedAuthor ?? author {
                        Text(author.name)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    messageBubble
                    if shouldRevealTimestamp, showTimestamp, let timestamp = timestamp {
                        timestampView(timestamp)
                    }
                }
                Spacer()
            } else {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let author = resolvedAuthor ?? author {
                        Text(author.name)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    messageBubble
                    if shouldRevealTimestamp, showTimestamp, let timestamp = timestamp {
                        timestampView(timestamp)
                    }
                }
                avatarView
            }
        }
    }
    
    private var avatarStackedLayout: some View {
        VStack(alignment: alignment, spacing: 6) {
            HStack(spacing: 8) {
                if alignment == .leading {
                    avatarView
                    if let author = resolvedAuthor ?? author {
                        Text(author.name)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    if shouldRevealTimestamp, showTimestamp, let timestamp = timestamp {
                        timestampView(timestamp)
                            .padding(.trailing, 4)
                    }
                } else {
                    if shouldRevealTimestamp, showTimestamp, let timestamp = timestamp {
                        timestampView(timestamp)
                            .padding(.leading, 4)
                    }
                    Spacer()
                    if let author = resolvedAuthor ?? author {
                        Text(author.name)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    avatarView
                }
            }
            
            HStack {
                if alignment == .leading {
                    messageBubble
                    Spacer()
                } else {
                    Spacer()
                    messageBubble
                }
            }
        }
    }
    
    // MARK: - Avatar View
    
    @ViewBuilder
    private var avatarView: some View {
        if let author = resolvedAuthor ?? author {
            AvatarView(name: author.name, imageURL: author.avatarURL, size: 36)
        } else {
            // Fallback to environment provider for current user
            EmptyView()
        }
    }
    
    // MARK: - Message Bubble
    
    private var messageBubble: some View {
        content
            .padding(12)
            .background(bubbleBackground)
            .foregroundStyle(bubbleForegroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Timestamp View
    
    private func timestampView(_ date: Date) -> some View {
        Text(formatTimestamp(date))
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(.tertiary)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Visibility Rules
    
    private var shouldRevealTimestamp: Bool {
        #if os(macOS)
        return isHovered
        #elseif os(iOS)
        return isRevealingTimestamp
        #else
        return true
        #endif
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenuContent(_ actions: MessageActions) -> some View {
        if let onEdit = actions.onEdit {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        
        if let onReply = actions.onReply {
            Button {
                onReply()
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
        }
        
        if let onCopy = actions.onCopy {
            Button {
                onCopy()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        
        if actions.onDelete != nil {
            Divider()
        }
        
        if let onDelete = actions.onDelete {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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

// MARK: - Supporting Types

/// Author information for a message
public struct MessageAuthor: Equatable {
    public let id: String
    public let name: String
    public let avatarURL: String?
    
    public init(id: String, name: String, avatarURL: String? = nil) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
    }
}

/// Actions that can be performed on a message
public struct MessageActions {
    public let onEdit: (() -> Void)?
    public let onReply: (() -> Void)?
    public let onCopy: (() -> Void)?
    public let onDelete: (() -> Void)?
    
    public init(
        onEdit: (() -> Void)? = nil,
        onReply: (() -> Void)? = nil,
        onCopy: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.onEdit = onEdit
        self.onReply = onReply
        self.onCopy = onCopy
        self.onDelete = onDelete
    }
}

// MARK: - Internal Avatar View

/// Internal avatar view for displaying user avatars in messages
private struct AvatarView: View {
    let name: String
    let imageURL: String?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let imageURL = imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderAvatar
                            .onAppear {
                                print("[EA][Swift][AvatarView] Loading image url=\(imageURL)")
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onAppear {
                                print("[EA][Swift][AvatarView] Image success url=\(imageURL)")
                            }
                    case .failure:
                        placeholderAvatar
                            .onAppear {
                                print("[EA][Swift][AvatarView] Image failure url=\(imageURL)")
                            }
                    @unknown default:
                        placeholderAvatar
                            .onAppear {
                                print("[EA][Swift][AvatarView] Image unknown phase url=\(imageURL)")
                            }
                    }
                }
            } else {
                placeholderAvatar
                    .onAppear {
                        print("[EA][Swift][AvatarView] No imageURL, showing placeholder for name=\(name)")
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    private var placeholderAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(name.prefix(1).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Convenience Initializer for Text Messages

extension Message where Content == Text {
    /// Create a text message (convenience initializer for simple text content)
    /// - Parameters:
    ///   - text: The message text
    ///   - author: Author information (name, avatar). Pass nil to use current user from environment
    ///   - isCurrentUser: Whether this message is from the current user
    ///   - timestamp: Optional timestamp to display
    ///   - layout: How to arrange the avatar and message
    ///   - bubbleStyle: Visual style of the message bubble
    ///   - alignment: Horizontal alignment of the message (.leading or .trailing)
    ///   - showTimestamp: Whether to show the timestamp
    ///   - actions: Optional actions (delete, edit, etc.)
    public init(
        text: String,
        author: MessageAuthor? = nil,
        isCurrentUser: Bool = false,
        timestamp: Date? = nil,
        layout: Layout = .avatarInline,
        bubbleStyle: BubbleStyle = .glass,
        alignment: HorizontalAlignment = .leading,
        showTimestamp: Bool = true,
        actions: MessageActions? = nil
    ) {
        self.init(
            author: author,
            isCurrentUser: isCurrentUser,
            timestamp: timestamp,
            layout: layout,
            bubbleStyle: bubbleStyle,
            alignment: alignment,
            showTimestamp: showTimestamp,
            actions: actions
        ) {
            Text(text)
                .font(.system(.body, design: .rounded))
        }
    }
}

