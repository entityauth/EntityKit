import SwiftUI

/// A modern user display component with Liquid Glass design matching AuthView and OrganizationSwitcher.
/// Shows user avatar, name, and email with flexible display variants:
/// - `.expanded` & `.compact`: Full user info in glass container
/// - `.plain`: User info without glass container (for custom backgrounds)
/// - `.avatarOnly`: Just the avatar icon (perfect for chat messages, activity feeds)
public struct UserDisplay: View {
    @StateObject private var viewModel: UserDisplayViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    /// Display variant - compact for inline use, expanded for standalone display
    public enum Variant {
        case compact        // Avatar + name only, smaller, in glass container
        case expanded       // Avatar + name + email, larger, in glass container
        case plain          // Avatar + name + email, no glass container (for custom backgrounds)
        case avatarOnly     // Just the avatar icon, no name/email (for tight spaces like chat)
    }
    
    private let variant: Variant
    
    /// Explicit provider injection so SwiftUI can observe the view model with @StateObject.
    public init(provider: AnyEntityAuthProvider, variant: Variant = .expanded) {
        _viewModel = StateObject(wrappedValue: UserDisplayViewModel(provider: provider))
        self.variant = variant
    }

    public var body: some View {
        let out = viewModel.output as UserDisplayViewModel.Output?
        
        Group {
            if variant == .avatarOnly {
                // Just the avatar
                avatarView(for: out)
            } else {
                HStack(spacing: spacingForVariant) {
                    // User Avatar
                    avatarView(for: out)
                    
                    // User Info (not shown for avatarOnly)
                    VStack(alignment: .leading, spacing: textSpacingForVariant) {
                        if out == nil || out!.isLoading {
                            loadingView
                        } else {
                            nameText(out!.name)
                            if shouldShowEmail {
                                emailText(out!.email)
                            }
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
    
    private var shouldShowEmail: Bool {
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
    
    @ViewBuilder
    private func avatarView(for output: UserDisplayViewModel.Output?) -> some View {
        let size: CGFloat = avatarSizeForVariant
        
        if output == nil || output!.isLoading {
            // Loading skeleton
            Circle()
                .fill(.tertiary.opacity(0.5))
                .frame(width: size, height: size)
                .overlay {
                    ProgressView()
                        .scaleEffect(variant == .avatarOnly ? 0.6 : 0.7)
                }
        } else {
            // User avatar with initial
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: size, height: size)
                
                Text(userInitial(from: output!.name))
                    .font(.system(avatarFontSize, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
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
    
    @ViewBuilder
    private func nameText(_ name: String?) -> some View {
        Text(name ?? "User")
            .font(.system(variant == .compact ? .subheadline : .body, design: .rounded, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
    }
    
    @ViewBuilder
    private func emailText(_ email: String?) -> some View {
        Text(email ?? "")
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(alignment: .leading, spacing: variant == .compact ? 4 : 6) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.tertiary.opacity(0.5))
                .frame(width: 100, height: variant == .compact ? 12 : 14)
            
            if variant == .expanded || variant == .plain {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary.opacity(0.5))
                    .frame(width: 140, height: 12)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func userInitial(from name: String?) -> String {
        guard let name = name, !name.isEmpty else { return "U" }
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


