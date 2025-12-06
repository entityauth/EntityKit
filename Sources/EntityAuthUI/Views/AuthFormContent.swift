import SwiftUI
import EntityAuthDomain

/// Internal reusable auth form content - NO TabView, just the pure auth UI
/// This is used by AuthGate (production) and AuthView (sandbox demo)
internal struct AuthFormContent: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var errorText: String?
    
    var authMethods: AuthMethods
    var isModal: Bool
    
    var onGoogleSignIn: (() async -> Void)?
    var onGitHubSignIn: (() async -> Void)?
    var onPasskeySignIn: (() async -> Void)?
    var onPasskeySignUp: ((String) async -> Void)?
    var onEmailSignIn: ((String, String) async -> Void)?
    var onEmailRegister: ((String, String) async -> Void)?
    
    @State private var selectedAuthTab: AuthTab = .signIn
    @State private var isLoading: Bool = false
    @State private var showPasskeySignUpSheet: Bool = false
    @State private var passkeySignUpEmail: String = ""
    
    @Environment(\.entityTheme) private var theme
    @Environment(\.entityAuthProvider) private var provider
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        #if os(iOS)
        let idealWidth: CGFloat = 380
        #else
        let idealWidth: CGFloat = 480
        #endif
        
        return VStack(spacing: 0) {
            // Error display
            if let errorText {
                Text(errorText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            
            // Card - Contains Tab Picker and Forms
            VStack(spacing: 0) {
                // Tab Picker (only show if email/password is enabled)
                if authMethods.emailPassword {
                    CustomTabPicker(selection: $selectedAuthTab)
                        .padding(.bottom, 4)
                }
                
                if authMethods.emailPassword {
                    if selectedAuthTab == .signIn {
                        signInView
                    } else {
                        registerView
                    }
                } else {
                    // If email/password is disabled, show only SSO/passkey options
                    ssoAndPasskeyOnlyView
                }
            }
            .padding(24)
            .background(
                Group {
                    // Don't show background in modal (modal already has bg)
                    if !isModal {
                        #if os(iOS)
                        if #available(iOS 26.0, *) {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.regularMaterial)
                                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 24))
                        } else {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                        }
                        #elseif os(macOS)
                        if #available(macOS 15.0, *) {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.regularMaterial)
                                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 24))
                        } else {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                        }
                        #else
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                        #endif
                    }
                }
            )
            .overlay(
                Group {
                    if !isModal {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.15), lineWidth: 1)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: isModal ? .clear : .black.opacity(colorScheme == .dark ? 0.08 : 0.12), radius: isModal ? 0 : 16, x: 0, y: isModal ? 0 : 4)
        }
        .frame(idealWidth: idealWidth)
        .padding()
        .sheet(isPresented: $showPasskeySignUpSheet) {
            passkeySignUpSheet
        }
    }
    
    // MARK: - Sign In View (copied from AuthView)
    
    private var signInView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 4)
            
            VStack(spacing: 12) {
            // Email/Password Form (only if enabled)
            if authMethods.emailPassword {
            #if os(iOS)
            TextField("", text: $email, prompt: Text("Email"))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.trailing, 40)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                )
                .overlay(alignment: .trailing) {
                    Image("AtSign", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .padding(.trailing, 16)
                }
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .disabled(isLoading)
            #else
            TextField("", text: $email, prompt: Text("Email"))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.trailing, 40)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                )
                .overlay(alignment: .trailing) {
                    Image("AtSign", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .padding(.trailing, 16)
                }
                .disabled(isLoading)
            #endif
            
            SecureField("", text: $password, prompt: Text("••••••••"))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.trailing, 40)
                .padding(.vertical, 12)
                .background(
                    Group {
                        #if os(iOS)
                        Capsule()
                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                        #else
                        Capsule()
                            .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                        #endif
                    }
                )
                .overlay(alignment: .trailing) {
                    Image("Password", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .padding(.trailing, 16)
                }
                .disabled(isLoading)
            
                    Button(action: {
                        let action = onEmailSignIn ?? AuthDefaultActions.makeEmailSignIn(provider: provider, errorText: $errorText)
                        Task {
                            isLoading = true
                            await action(email, password)
                            isLoading = false
                        }
                    }) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                } else {
                    Text("Sign in")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .background(
                Group {
                    #if os(iOS)
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(theme.colors.primary.gradient)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(theme.colors.primary.gradient)
                    }
                    #elseif os(macOS)
                    if #available(macOS 15.0, *) {
                        Capsule()
                            .fill(theme.colors.primary.gradient)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(theme.colors.primary.gradient)
                    }
                    #else
                    Capsule()
                        .fill(theme.colors.primary.gradient)
                    #endif
                }
            )
            .buttonStyle(.plain)
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .opacity((email.isEmpty || password.isEmpty || isLoading) ? 0.5 : 1.0)
            }
            
            // SSO & Passkey Buttons
            HStack(spacing: 12) {
                if authMethods.sso.google {
                    ssoButton(icon: "Google", action: onGoogleSignIn ?? AuthDefaultActions.makeGoogleSignIn(provider: provider, errorText: $errorText))
                }
                if authMethods.sso.github {
                    ssoButton(icon: "Github", action: onGitHubSignIn ?? AuthDefaultActions.makeGitHubSignIn(provider: provider, errorText: $errorText))
                }
                if authMethods.passkey {
                    ssoButton(icon: "Passkey", action: onPasskeySignIn ?? AuthDefaultActions.makePasskeySignIn(provider: provider, errorText: $errorText))
                }
            }
            }
        }
    }
    
    // MARK: - SSO and Passkey Only View (when email/password is disabled)
    
    private var ssoAndPasskeyOnlyView: some View {
        VStack(spacing: 24) {
            // SSO & Passkey Buttons - Circular with text labels
            HStack(spacing: 20) {
                if authMethods.sso.google {
                    circularAuthButton(icon: "Google", label: "Google", action: onGoogleSignIn ?? AuthDefaultActions.makeGoogleSignIn(provider: provider, errorText: $errorText))
                }
                if authMethods.sso.github {
                    circularAuthButton(icon: "Github", label: "GitHub", action: onGitHubSignIn ?? AuthDefaultActions.makeGitHubSignIn(provider: provider, errorText: $errorText))
                }
                if authMethods.passkey {
                    VStack(spacing: 8) {
                        Button(action: {
                            showPasskeySignUpSheet = true
                        }) {
                            Image("Passkey", bundle: .module)
                                .resizable()
                                .renderingMode(.original)
                                .frame(width: 24, height: 24)
                                .frame(width: 56, height: 56)
                                .background(
                                    Group {
                                        #if os(iOS)
                                        if #available(iOS 26.0, *) {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(.regularMaterial)
                                                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 16))
                                        } else {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                                        }
                                        #elseif os(macOS)
                                        if #available(macOS 15.0, *) {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(.regularMaterial)
                                                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 16))
                                        } else {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                                        }
                                        #else
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                                        #endif
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.15), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.5 : 1.0)
                        
                        Text("Passkey")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Squircle Auth Button (for SSO/passkey only mode)
    
    @ViewBuilder
    private func circularAuthButton(icon: String, label: String, action: @escaping () async -> Void) -> some View {
        VStack(spacing: 8) {
            Button(action: {
                Task {
                    isLoading = true
                    await action()
                    isLoading = false
                }
            }) {
                Image(icon, bundle: .module)
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 24, height: 24)
                    .frame(width: 56, height: 56)
                    .background(
                        Group {
                            #if os(iOS)
                            if #available(iOS 26.0, *) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.regularMaterial)
                                    .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 16))
                            } else {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                            }
                            #elseif os(macOS)
                            if #available(macOS 15.0, *) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.regularMaterial)
                                    .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 16))
                            } else {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                            }
                            #else
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                            #endif
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .opacity(isLoading ? 0.5 : 1.0)
            
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Register View
    
    private var registerView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 4)
            
            VStack(spacing: 12) {
            // Email/Password Form (only if enabled)
            if authMethods.emailPassword {
            #if os(iOS)
            TextField("", text: $email, prompt: Text("Email"))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.trailing, 40)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                )
                .overlay(alignment: .trailing) {
                    Image("AtSign", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .padding(.trailing, 16)
                }
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .disabled(isLoading)
            #else
            TextField("", text: $email, prompt: Text("Email"))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.trailing, 40)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                )
                .overlay(alignment: .trailing) {
                    Image("AtSign", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .padding(.trailing, 16)
                }
                .disabled(isLoading)
            #endif
            
            SecureField("", text: $password, prompt: Text("Create a password"))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.trailing, 40)
                .padding(.vertical, 12)
                .background(
                    Group {
                        #if os(iOS)
                        Capsule()
                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                        #else
                        Capsule()
                            .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                        #endif
                    }
                )
                .overlay(alignment: .trailing) {
                    Image("Password", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .padding(.trailing, 16)
                }
                .disabled(isLoading)
            
            Button(action: {
                let action = onEmailRegister ?? AuthDefaultActions.makeEmailRegister(provider: provider, errorText: $errorText)
                Task {
                    isLoading = true
                    await action(email, password)
                    isLoading = false
                }
            }) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                } else {
                    Text("Create account")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .background(
                Group {
                    #if os(iOS)
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(theme.colors.primary.gradient)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(theme.colors.primary.gradient)
                    }
                    #elseif os(macOS)
                    if #available(macOS 15.0, *) {
                        Capsule()
                            .fill(theme.colors.primary.gradient)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(theme.colors.primary.gradient)
                    }
                    #else
                    Capsule()
                        .fill(theme.colors.primary.gradient)
                    #endif
                }
            )
            .buttonStyle(.plain)
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .opacity((email.isEmpty || password.isEmpty || isLoading) ? 0.5 : 1.0)
            }
            
            // SSO & Passkey Buttons
            HStack(spacing: 12) {
                if authMethods.sso.google {
                    ssoButton(icon: "Google", action: onGoogleSignIn ?? AuthDefaultActions.makeGoogleSignIn(provider: provider, errorText: $errorText))
                }
                if authMethods.sso.github {
                    ssoButton(icon: "Github", action: onGitHubSignIn ?? AuthDefaultActions.makeGitHubSignIn(provider: provider, errorText: $errorText))
                }
                if authMethods.passkey {
                    Button(action: { showPasskeySignUpSheet = true }) {
                        Image("Passkey", bundle: .module)
                            .resizable()
                            .renderingMode(.original)
                            .frame(width: 20, height: 20)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Group {
                                    #if os(iOS)
                                    if #available(iOS 26.0, *) {
                                        Capsule()
                                            .fill(.regularMaterial)
                                            .glassEffect(.regular.interactive(true), in: .capsule)
                                    } else {
                                        Capsule()
                                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                                    }
                                    #elseif os(macOS)
                                    if #available(macOS 15.0, *) {
                                        Capsule()
                                            .fill(.regularMaterial)
                                            .glassEffect(.regular.interactive(true), in: .capsule)
                                    } else {
                                        Capsule()
                                            .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                                    }
                                    #else
                                    Capsule()
                                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                                    #endif
                                }
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .opacity(isLoading ? 0.5 : 1.0)
                }
            }
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func ssoButton(icon: String, action: @escaping () async -> Void) -> some View {
        Button(action: {
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        }) {
            Image(icon, bundle: .module)
                .resizable()
                .renderingMode(.original)
                .frame(width: 20, height: 20)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Group {
                        #if os(iOS)
                        if #available(iOS 26.0, *) {
                            Capsule()
                                .fill(.regularMaterial)
                                .glassEffect(.regular.interactive(true), in: .capsule)
                        } else {
                            Capsule()
                                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                        }
                        #elseif os(macOS)
                        if #available(macOS 15.0, *) {
                            Capsule()
                                .fill(.regularMaterial)
                                .glassEffect(.regular.interactive(true), in: .capsule)
                        } else {
                            Capsule()
                                .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                        }
                        #else
                        Capsule()
                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                        #endif
                    }
                )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.5 : 1.0)
    }
    
    private var passkeySignUpSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Sign up with Passkey")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .padding(.top, 8)
                
                #if os(iOS)
                TextField("Email", text: $passkeySignUpEmail)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                    )
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                #else
                TextField("Email", text: $passkeySignUpEmail)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                    )
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
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    } else {
                        Text("Confirm")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .background(
                    Capsule()
                        .fill(theme.colors.primary.gradient)
                )
                .buttonStyle(.plain)
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

