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
        GeometryReader { geometry in
            HStack {
                Spacer()
                VStack(spacing: 24) {
                    // Header - OUTSIDE the card
                    VStack(spacing: 8) {
                        // Entity Auth branding
                        Text("Entity Auth")
                            .font(.largeTitle)
                            .bold()
                        
                        Text(selectedTab == .signIn ? "Sign in to your dashboard" : "Create account")
                            .foregroundStyle(.secondary)
                        
                        if let errorText {
                            Text(errorText)
                                .foregroundStyle(.red)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: 448)
                    
                    // Card - Contains Tab Picker and Forms
                    VStack(spacing: 12) {
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
                    .background(
                        ConcentricRectangle()
                            .fill(.regularMaterial)
                    )
                    .clipShape(ConcentricRectangle())
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .containerShape(.rect(cornerRadius: theme.design.cornerRadius))
                    .frame(maxWidth: 448)
                    
                    // Back link - OUTSIDE the card
                    Button(action: {
                        // Navigation could be added here if needed
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                            Text("Back to Entity Auth")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 448)
                }
                .frame(maxWidth: 448)
                Spacer()
            }
        }
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
                .clipShape(.capsule)
            #else
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
                .clipShape(.capsule)
            #endif
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
                .clipShape(.capsule)
            
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
            .clipShape(.capsule)
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .tint(theme.colors.primary)
            
            // SSO & Passkey Buttons (icon-only in a row)
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        isLoading = true
                        await onGoogleSignIn?()
                        isLoading = false
                    }
                }) {
                    Image("Google")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 20, height: 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .clipShape(.capsule)
                .disabled(isLoading)
                
                Button(action: {
                    Task {
                        isLoading = true
                        await onGitHubSignIn?()
                        isLoading = false
                    }
                }) {
                    Image("GithubLight")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 20, height: 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .clipShape(.capsule)
                .disabled(isLoading)
                
                Button(action: {
                    Task {
                        isLoading = true
                        await onPasskeySignIn?()
                        isLoading = false
                    }
                }) {
                    Image("PasskeyLight")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 20, height: 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .clipShape(.capsule)
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
                .clipShape(.capsule)
            #else
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
                .clipShape(.capsule)
            #endif
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
                .clipShape(.capsule)
            
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
            .clipShape(.capsule)
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .tint(theme.colors.primary)
            
            // SSO & Passkey Buttons (icon-only in a row)
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        isLoading = true
                        await onGoogleSignIn?()
                        isLoading = false
                    }
                }) {
                    Image("Google")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 20, height: 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .clipShape(.capsule)
                .disabled(isLoading)
                
                Button(action: {
                    Task {
                        isLoading = true
                        await onGitHubSignIn?()
                        isLoading = false
                    }
                }) {
                    Image("GithubLight")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 20, height: 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .clipShape(.capsule)
                .disabled(isLoading)
                
                Button(action: {
                    showPasskeySignUpSheet = true
                }) {
                    Image("PasskeyLight")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .clipShape(.capsule)
                .disabled(isLoading)
            }
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
                    .clipShape(.capsule)
                #else
                TextField("Email", text: $passkeySignUpEmail)
                    .textFieldStyle(.roundedBorder)
                    .clipShape(.capsule)
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
                .clipShape(.capsule)
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


