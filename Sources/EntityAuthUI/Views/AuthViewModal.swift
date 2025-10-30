import SwiftUI
import EntityAuthDomain

/// Convenience wrapper that renders a button which, when tapped/clicked,
/// presents `AuthView` inside a modal sheet. This keeps consumer apps to a
/// single-line API when they want a modal-based auth experience.
public struct AuthViewModal<Label: View>: View {
    @Environment(\.entityAuthProvider) private var provider
    // Presentation
    @State private var isPresented: Bool = false

    // AuthView state (kept internal for convenience defaults)
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorText: String?

    // Callbacks forwarded to AuthView
    public var onGoogleSignIn: (() async -> Void)?
    public var onGitHubSignIn: (() async -> Void)?
    public var onPasskeySignIn: (() async -> Void)?
    public var onPasskeySignUp: ((String) async -> Void)?
    public var onEmailSignIn: ((String, String) async -> Void)?
    public var onEmailRegister: ((String, String) async -> Void)?

    private let label: () -> Label
    private let useDefaultGlassStyle: Bool

    /// Create a modal-based auth experience with a custom button label.
    /// - Parameter label: Content for the trigger button (e.g. "Sign in").
    /// - Other parameters are forwarded to `AuthView`.
    public init(
        onGoogleSignIn: (() async -> Void)? = nil,
        onGitHubSignIn: (() async -> Void)? = nil,
        onPasskeySignIn: (() async -> Void)? = nil,
        onPasskeySignUp: ((String) async -> Void)? = nil,
        onEmailSignIn: ((String, String) async -> Void)? = nil,
        onEmailRegister: ((String, String) async -> Void)? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.onGoogleSignIn = onGoogleSignIn
        self.onGitHubSignIn = onGitHubSignIn
        self.onPasskeySignIn = onPasskeySignIn
        self.onPasskeySignUp = onPasskeySignUp
        self.onEmailSignIn = onEmailSignIn
        self.onEmailRegister = onEmailRegister
        self.label = label
        self.useDefaultGlassStyle = false
    }

    /// Convenience initializer with a default "Sign in" button label.
    public init(
        title: String = "Sign in",
        onGoogleSignIn: (() async -> Void)? = nil,
        onGitHubSignIn: (() async -> Void)? = nil,
        onPasskeySignIn: (() async -> Void)? = nil,
        onPasskeySignUp: ((String) async -> Void)? = nil,
        onEmailSignIn: ((String, String) async -> Void)? = nil,
        onEmailRegister: ((String, String) async -> Void)? = nil
    ) where Label == Text {
        self.onGoogleSignIn = onGoogleSignIn
        self.onGitHubSignIn = onGitHubSignIn
        self.onPasskeySignIn = onPasskeySignIn
        self.onPasskeySignUp = onPasskeySignUp
        self.onEmailSignIn = onEmailSignIn
        self.onEmailRegister = onEmailRegister
        self.label = { Text(title) }
        self.useDefaultGlassStyle = true
    }

    public var body: some View {
        Button(action: { isPresented = true }) {
            if useDefaultGlassStyle {
                let base = label()
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minWidth: 120)

                #if os(iOS)
                if #available(iOS 26.0, *) {
                    base
                        .glassEffect(.regular.interactive(true), in: .capsule)
                } else {
                    base
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 10)
                }
                #elseif os(macOS)
                if #available(macOS 15.0, *) {
                    base
                        .glassEffect(.regular.interactive(true), in: .capsule)
                } else {
                    base
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 10)
                }
                #else
                base
                #endif
            } else {
                label()
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            #if os(iOS)
            NavigationView {
                AuthView(
                    email: $email,
                    password: $password,
                    errorText: $errorText,
                    onGoogleSignIn: onGoogleSignIn ?? AuthDefaultActions.makeGoogleSignIn(provider: provider, errorText: $errorText),
                    onGitHubSignIn: onGitHubSignIn ?? AuthDefaultActions.makeGitHubSignIn(provider: provider, errorText: $errorText),
                    onPasskeySignIn: onPasskeySignIn ?? AuthDefaultActions.makePasskeySignIn(provider: provider, errorText: $errorText),
                    onPasskeySignUp: onPasskeySignUp ?? AuthDefaultActions.makePasskeySignUp(provider: provider, errorText: $errorText),
                    onEmailSignIn: onEmailSignIn ?? AuthDefaultActions.makeEmailSignIn(provider: provider, errorText: $errorText),
                    onEmailRegister: onEmailRegister ?? AuthDefaultActions.makeEmailRegister(provider: provider, errorText: $errorText)
                )
                .padding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { isPresented = false }
                    }
                }
            }
            .modifier(IOSSheetDetents())
            #else
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Close") { isPresented = false }
                }
                .padding([.top, .horizontal])
                Spacer(minLength: 8)
                AuthView(
                    email: $email,
                    password: $password,
                    errorText: $errorText,
                    onGoogleSignIn: onGoogleSignIn ?? AuthDefaultActions.makeGoogleSignIn(provider: provider, errorText: $errorText),
                    onGitHubSignIn: onGitHubSignIn ?? AuthDefaultActions.makeGitHubSignIn(provider: provider, errorText: $errorText),
                    onPasskeySignIn: onPasskeySignIn ?? AuthDefaultActions.makePasskeySignIn(provider: provider, errorText: $errorText),
                    onPasskeySignUp: onPasskeySignUp ?? AuthDefaultActions.makePasskeySignUp(provider: provider, errorText: $errorText),
                    onEmailSignIn: onEmailSignIn ?? AuthDefaultActions.makeEmailSignIn(provider: provider, errorText: $errorText),
                    onEmailRegister: onEmailRegister ?? AuthDefaultActions.makeEmailRegister(provider: provider, errorText: $errorText)
                )
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 16)
            }
            .padding(.bottom, 12)
            .frame(minWidth: 560, minHeight: 560)
            #endif
        }
    }

    // Defaults moved to AuthDefaultActions
}

// iOS-only sheet detents modifier
private struct IOSSheetDetents: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
        #else
        content
        #endif
    }
}


