import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Pure UI component for authentication - displays SSO button and email/password form.
/// Takes callbacks for actions. NO business logic.
public struct AuthView: View {
    // UI State - Pure state management
    @Binding public var email: String
    @Binding public var password: String
    @State private var isSigningInWithSSO: Bool = false
    @State private var isSigningInEmail: Bool = false
    
    // Error state
    @Binding public var errorText: String?
    
    // Callbacks - NO LOGIC, just callbacks
    public var onSSOSignIn: (() async -> Void)?
    public var onEmailSignIn: ((String, String) async -> Void)?
    
    @Environment(\.entityTheme) private var theme
    
    public init(
        email: Binding<String> = .constant(""),
        password: Binding<String> = .constant(""),
        errorText: Binding<String?> = .constant(nil),
        onSSOSignIn: (() async -> Void)? = nil,
        onEmailSignIn: ((String, String) async -> Void)? = nil
    ) {
        self._email = email
        self._password = password
        self._errorText = errorText
        self.onSSOSignIn = onSSOSignIn
        self.onEmailSignIn = onEmailSignIn
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Sign in to continue")
                    .font(.title3)
                    .bold()
                
                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            // SSO Button
            Button(action: {
                Task {
                    isSigningInWithSSO = true
                    await onSSOSignIn?()
                    isSigningInWithSSO = false
                }
            }) {
                HStack {
                    Image(systemName: "globe")
                    Text(isSigningInWithSSO ? "Signing in..." : "Sign in with SSO")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSigningInWithSSO || isSigningInEmail)
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }
            
            // Email/Password Form
            VStack(spacing: 12) {
                #if os(iOS)
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disabled(isSigningInWithSSO || isSigningInEmail)
                #else
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isSigningInWithSSO || isSigningInEmail)
                #endif
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isSigningInWithSSO || isSigningInEmail)
                
                Button(action: {
                    Task {
                        isSigningInEmail = true
                        await onEmailSignIn?(email, password)
                        isSigningInEmail = false
                    }
                }) {
                    if isSigningInEmail {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign in with Email")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || isSigningInWithSSO || isSigningInEmail)
                .tint(theme.colors.primary)
            }
        }
        .padding(24)
        .background(theme.colors.background)
        .clipShape(RoundedRectangle(cornerRadius: theme.design.cornerRadius))
    }
}


