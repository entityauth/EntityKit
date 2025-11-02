import SwiftUI

/// An interactive user button component with Liquid Glass design.
/// Similar to the organization switcher button - designed to trigger a user menu or profile sheet.
/// Matches the design language of AuthView and OrganizationSwitcher.
public struct UserButton: View {
    @StateObject private var viewModel: UserDisplayViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    /// The action to perform when the button is tapped
    private let action: () -> Void
    
    /// Size variant - compact for toolbars, standard for main UI
    public enum Size {
        case compact
        case standard
        
        var avatarSize: CGFloat {
            switch self {
            case .compact: return 28
            case .standard: return 36
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .compact: return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 12)
            case .standard: return EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 16)
            }
        }
        
        var maxWidth: CGFloat {
            switch self {
            case .compact: return 200
            case .standard: return 280
            }
        }
    }
    
    private let size: Size
    
    public init(provider: AnyEntityAuthProvider, size: Size = .standard, action: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: UserDisplayViewModel(provider: provider))
        self.size = size
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            let out = viewModel.output as UserDisplayViewModel.Output?
            
            HStack(spacing: size == .compact ? 8 : 10) {
                // User Avatar
                avatarView(for: out)
                
                // User Info
                if out == nil || out!.isLoading {
                    loadingView
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(out!.name ?? "User")
                            .font(.system(size == .compact ? .caption : .subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        if size == .standard {
                            Text(out!.email ?? "")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer(minLength: 4)
                
                // Chevron indicator
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: size == .compact ? 14 : 16))
                    .foregroundStyle(.tertiary)
            }
            .padding(size.padding)
            .frame(maxWidth: size.maxWidth)
            .background(backgroundView)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Avatar View
    
    @ViewBuilder
    private func avatarView(for output: UserDisplayViewModel.Output?) -> some View {
        let dimension = size.avatarSize
        if output == nil || output!.isLoading {
            // Loading skeleton
            Circle()
                .fill(.tertiary.opacity(0.5))
                .frame(width: dimension, height: dimension)
                .overlay {
                    ProgressView()
                        .scaleEffect(0.6)
                }
        } else if let urlString = output!.imageUrl, let url = URL(string: urlString), !urlString.isEmpty {
            // Load avatar image if available
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Circle()
                        .fill(.tertiary.opacity(0.5))
                        .frame(width: dimension, height: dimension)
                        .overlay { ProgressView().scaleEffect(0.6) }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: dimension, height: dimension)
                        .clipShape(Circle())
                case .failure:
                    ZStack {
                        Circle()
                            .fill(.blue.gradient)
                            .frame(width: dimension, height: dimension)
                        Text(userInitial(from: output!.name))
                            .font(.system(size == .compact ? .caption2 : .caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }
                @unknown default:
                    ZStack {
                        Circle()
                            .fill(.blue.gradient)
                            .frame(width: dimension, height: dimension)
                        Text(userInitial(from: output!.name))
                            .font(.system(size == .compact ? .caption2 : .caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
        } else {
            // Fallback to initial when no image URL
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: dimension, height: dimension)
                
                Text(userInitial(from: output!.name))
                    .font(.system(size == .compact ? .caption2 : .caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(.tertiary.opacity(0.5))
                .frame(width: 80, height: size == .compact ? 10 : 12)
            
            if size == .standard {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary.opacity(0.5))
                    .frame(width: 100, height: 10)
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

