import SwiftUI
import EntityAuthDomain

/// A modern organization display component with Liquid Glass design matching UserDisplay.
/// Shows organization avatar, name, and member info with flexible display variants:
/// - `.expanded` & `.compact`: Full org info in glass container
/// - `.plain`: Org info without glass container (for custom backgrounds)
/// - `.avatarOnly`: Just the avatar icon (perfect for lists, activity feeds)
public struct OrganizationDisplay: View {
    private let organization: OrganizationSummary
    private let variant: Variant
    @Environment(\.colorScheme) private var colorScheme
    
    /// Display variant - compact for inline use, expanded for standalone display
    public enum Variant {
        case compact        // Avatar + name only, smaller, in glass container
        case expanded       // Avatar + name + member count/role, larger, in glass container
        case plain          // Avatar + name + member count/role, no glass container (for custom backgrounds)
        case avatarOnly     // Just the avatar icon, no name/info (for tight spaces)
    }
    
    /// Initialize with organization data and variant
    public init(organization: OrganizationSummary, variant: Variant = .expanded) {
        self.organization = organization
        self.variant = variant
    }
    
    public var body: some View {
        Group {
            if variant == .avatarOnly {
                // Just the avatar
                avatarView
            } else {
                HStack(spacing: spacingForVariant) {
                    // Organization Avatar
                    avatarView
                    
                    // Organization Info (not shown for avatarOnly)
                    VStack(alignment: .leading, spacing: textSpacingForVariant) {
                        nameText
                        if shouldShowDetails {
                            detailsText
                        }
                    }
                    
                    if hasContainer {
                        Spacer()
                    }
                }
                .conditionalPadding(hasContainer: hasContainer)
                .conditionalFrame(hasContainer: hasContainer)
                .conditionalBackground(hasContainer: hasContainer, colorScheme: colorScheme)
            }
        }
    }
    
    // MARK: - Variant Helpers
    
    private var hasContainer: Bool {
        variant == .compact || variant == .expanded
    }
    
    private var shouldShowDetails: Bool {
        variant == .expanded || variant == .plain
    }
    
    private var spacingForVariant: CGFloat {
        switch variant {
        case .compact: return 10
        case .expanded: return 12
        case .plain: return 12
        case .avatarOnly: return 0
        }
    }
    
    private var textSpacingForVariant: CGFloat {
        switch variant {
        case .compact: return 2
        case .expanded: return 4
        case .plain: return 4
        case .avatarOnly: return 0
        }
    }
    
    // MARK: - Avatar View
    
    private var avatarView: some View {
        let size: CGFloat = avatarSizeForVariant
        
        return ZStack {
            Circle()
                .fill(.blue.gradient)
                .frame(width: size, height: size)
            
            Text(orgInitial)
                .font(.system(avatarFontSize, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    private var avatarSizeForVariant: CGFloat {
        switch variant {
        case .compact: return 32
        case .expanded: return 40
        case .plain: return 40
        case .avatarOnly: return 32
        }
    }
    
    private var avatarFontSize: Font.TextStyle {
        switch variant {
        case .compact: return .caption
        case .expanded: return .body
        case .plain: return .body
        case .avatarOnly: return .caption
        }
    }
    
    // MARK: - Text Views
    
    private var nameText: some View {
        Text(organization.name ?? organization.slug ?? "Organization")
            .font(.system(variant == .compact ? .subheadline : .body, design: .rounded, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
    }
    
    private var detailsText: some View {
        HStack(spacing: 4) {
            let memberCount = organization.memberCount ?? 0
            Text("\(memberCount) members")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            
            Text("•")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)
            
            Text(organization.role.capitalized)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }
    
    // MARK: - Helpers
    
    private var orgInitial: String {
        let name = organization.name ?? organization.slug ?? "O"
        return String(name.prefix(1).uppercased())
    }
}

// MARK: - Conditional View Modifiers

private extension View {
    @ViewBuilder
    func conditionalPadding(hasContainer: Bool) -> some View {
        if hasContainer {
            self
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func conditionalFrame(hasContainer: Bool) -> some View {
        if hasContainer {
            self.frame(maxWidth: 320)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func conditionalBackground(hasContainer: Bool, colorScheme: ColorScheme) -> some View {
        if hasContainer {
            self
                .background(backgroundView(colorScheme: colorScheme))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        } else {
            self
        }
    }
    
    @ViewBuilder
    private func backgroundView(colorScheme: ColorScheme) -> some View {
        Group {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                Capsule()
                    .fill(.regularMaterial)
                    .glassEffect(.regular.interactive(true), in: .capsule)
            } else {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
            #elseif os(macOS)
            if #available(macOS 15.0, *) {
                Capsule()
                    .fill(.regularMaterial)
                    .glassEffect(.regular.interactive(true), in: .capsule)
            } else {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
            #else
            Capsule()
                .fill(.ultraThinMaterial)
            #endif
        }
    }
}

