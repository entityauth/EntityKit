import SwiftUI

/// A modern user display component with Liquid Glass design matching AuthView and OrganizationSwitcher.
/// Shows user avatar, name, and email in a glassmorphic capsule container.
public struct UserDisplay: View {
    @StateObject private var viewModel: UserDisplayViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    /// Display variant - compact for inline use, expanded for standalone display
    public enum Variant {
        case compact    // Avatar + name only, smaller
        case expanded   // Avatar + name + email, larger
    }
    
    private let variant: Variant
    
    /// Explicit provider injection so SwiftUI can observe the view model with @StateObject.
    public init(provider: AnyEntityAuthProvider, variant: Variant = .expanded) {
        _viewModel = StateObject(wrappedValue: UserDisplayViewModel(provider: provider))
        self.variant = variant
    }

    public var body: some View {
        let out = viewModel.output as UserDisplayViewModel.Output?
        
        HStack(spacing: variant == .compact ? 10 : 12) {
            // User Avatar
            avatarView(for: out)
            
            // User Info
            VStack(alignment: .leading, spacing: variant == .compact ? 2 : 4) {
                if out == nil || out!.isLoading {
                    loadingView
                } else {
                    nameText(out!.name)
                    if variant == .expanded {
                        emailText(out!.email)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, variant == .compact ? 12 : 16)
        .padding(.vertical, variant == .compact ? 8 : 12)
        .frame(maxWidth: variant == .compact ? 240 : 320)
        .background(backgroundView)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Avatar View
    
    @ViewBuilder
    private func avatarView(for output: UserDisplayViewModel.Output?) -> some View {
        let size: CGFloat = variant == .compact ? 32 : 40
        
        if output == nil || output!.isLoading {
            // Loading skeleton
            Circle()
                .fill(.tertiary.opacity(0.5))
                .frame(width: size, height: size)
                .overlay {
                    ProgressView()
                        .scaleEffect(0.7)
                }
        } else {
            // User avatar with initial
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: size, height: size)
                
                Text(userInitial(from: output!.name))
                    .font(.system(variant == .compact ? .caption : .body, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
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
            
            if variant == .expanded {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary.opacity(0.5))
                    .frame(width: 140, height: 12)
            }
        }
    }
    
    // MARK: - Background View
    
    @ViewBuilder
    private var backgroundView: some View {
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
    
    // MARK: - Helpers
    
    private func userInitial(from name: String?) -> String {
        guard let name = name, !name.isEmpty else { return "U" }
        return String(name.prefix(1).uppercased())
    }
}


