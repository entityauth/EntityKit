import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Pure UI component for authentication - displays SSO buttons, passkey, and email/password form.
/// Takes callbacks for actions. NO business logic.
public struct AuthView: View {
    // UI State - Pure state management
    @Binding public var email: String
    @Binding public var password: String
    @State private var selectedTab: AuthTab = .signIn
    @State private var isLoading: Bool = false
    @State private var showPasskeySignUpSheet: Bool = false
    @State private var passkeySignUpEmail: String = ""
    
    // Error state
    @Binding public var errorText: String?
    
    // Callbacks - NO LOGIC, just callbacks
    public var onGoogleSignIn: (() async -> Void)?
    public var onGitHubSignIn: (() async -> Void)?
    public var onPasskeySignIn: (() async -> Void)?
    public var onPasskeySignUp: ((String) async -> Void)?
    public var onEmailSignIn: ((String, String) async -> Void)?
    public var onEmailRegister: ((String, String) async -> Void)?
    
    @Environment(\.entityTheme) private var theme
    
    public enum AuthTab {
        case signIn
        case register
    }
    
    public init(
        email: Binding<String> = .constant(""),
        password: Binding<String> = .constant(""),
        errorText: Binding<String?> = .constant(nil),
        onGoogleSignIn: (() async -> Void)? = nil,
        onGitHubSignIn: (() async -> Void)? = nil,
        onPasskeySignIn: (() async -> Void)? = nil,
        onPasskeySignUp: ((String) async -> Void)? = nil,
        onEmailSignIn: ((String, String) async -> Void)? = nil,
        onEmailRegister: ((String, String) async -> Void)? = nil
    ) {
        self._email = email
        self._password = password
        self._errorText = errorText
        self.onGoogleSignIn = onGoogleSignIn
        self.onGitHubSignIn = onGitHubSignIn
        self.onPasskeySignIn = onPasskeySignIn
        self.onPasskeySignUp = onPasskeySignUp
        self.onEmailSignIn = onEmailSignIn
        self.onEmailRegister = onEmailRegister
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text(selectedTab == .signIn ? "Sign in to your dashboard" : "Create account")
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
            
            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Sign in").tag(AuthTab.signIn)
                Text("Create account").tag(AuthTab.register)
            }
            .pickerStyle(.segmented)
            
            if selectedTab == .signIn {
                signInView
            } else {
                registerView
            }
        }
        .padding(24)
        .background(theme.colors.background)
        .clipShape(RoundedRectangle(cornerRadius: theme.design.cornerRadius))
        .sheet(isPresented: $showPasskeySignUpSheet) {
            passkeySignUpSheet
        }
    }
    
    // MARK: - Sign In View
    
    private var signInView: some View {
        VStack(spacing: 12) {
            // Email/Password Form
            #if os(iOS)
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .disabled(isLoading)
            #else
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
            #endif
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
            
            Button(action: {
                Task {
                    isLoading = true
                    await onEmailSignIn?(email, password)
                    isLoading = false
                }
            }) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign in")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .tint(theme.colors.primary)
            
            // SSO & Passkey Buttons
            VStack(spacing: 8) {
                Button(action: {
                    Task {
                        isLoading = true
                        await onGoogleSignIn?()
                        isLoading = false
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Continue with Google")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                Button(action: {
                    Task {
                        isLoading = true
                        await onGitHubSignIn?()
                        isLoading = false
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("Continue with GitHub")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                Button(action: {
                    Task {
                        isLoading = true
                        await onPasskeySignIn?()
                        isLoading = false
                    }
                }) {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Sign in with Passkey")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
        }
    }
    
    // MARK: - Register View
    
    private var registerView: some View {
        VStack(spacing: 12) {
            // Email/Password Form
            #if os(iOS)
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .disabled(isLoading)
            #else
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
            #endif
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
            
            Button(action: {
                Task {
                    isLoading = true
                    await onEmailRegister?(email, password)
                    isLoading = false
                }
            }) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .tint(theme.colors.primary)
            
            // Passkey Sign Up Button
            Button(action: {
                showPasskeySignUpSheet = true
            }) {
                HStack {
                    Image(systemName: "key.fill")
                    Text("Sign up with Passkey")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
        }
    }
    
    // MARK: - Passkey Sign Up Sheet
    
    private var passkeySignUpSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Sign up with Passkey")
                    .font(.headline)
                
                #if os(iOS)
                TextField("Email", text: $passkeySignUpEmail)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                #else
                TextField("Email", text: $passkeySignUpEmail)
                    .textFieldStyle(.roundedBorder)
                #endif
                
                Button(action: {
                    Task {
                        isLoading = true
                        await onPasskeySignUp?(passkeySignUpEmail)
                        isLoading = false
                        showPasskeySignUpSheet = false
                        passkeySignUpEmail = ""
                    }
                }) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Confirm")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(passkeySignUpEmail.isEmpty || isLoading)
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showPasskeySignUpSheet = false
                        passkeySignUpEmail = ""
                    }
                }
            }
        }
    }
}


