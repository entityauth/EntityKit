import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import EntityAuthDomain

/// Pure UI component for authentication - displays SSO buttons, passkey, and email/password form.
/// Takes callbacks for actions. NO business logic.
/// Supports both embedded and modal presentation variants via tab navigation.
public struct AuthView: View {
    // UI State - Pure state management
    @Binding public var email: String
    @Binding public var password: String
    @State private var selectedAuthTab: AuthTab = .signIn
    @State private var selectedVariantTab: VariantTab = .embedded
    @State private var isLoading: Bool = false
    @State private var showPasskeySignUpSheet: Bool = false
    @State private var passkeySignUpEmail: String = ""
    @State private var isModalPresented: Bool = false
    
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
    @Environment(\.entityAuthProvider) private var provider
    @Environment(\.colorScheme) private var colorScheme
    
    public enum AuthTab {
        case signIn
        case register
    }
    
    public enum VariantTab: String, CaseIterable {
        case embedded = "Embedded View"
        case modal = "Modal View"
        
        var icon: String {
            switch self {
            case .embedded: return "rectangle.fill"
            case .modal: return "macwindow"
            }
        }
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
        #if os(iOS)
        // iOS: Use standard bottom tab bar
        TabView(selection: $selectedVariantTab) {
            embeddedVariantView
                .tabItem {
                    Label(VariantTab.embedded.rawValue, systemImage: VariantTab.embedded.icon)
                }
                .tag(VariantTab.embedded)
            
            modalVariantView
                .tabItem {
                    Label(VariantTab.modal.rawValue, systemImage: VariantTab.modal.icon)
                }
                .tag(VariantTab.modal)
        }
        .sheet(isPresented: $showPasskeySignUpSheet) {
            passkeySignUpSheet
        }
        .sheet(isPresented: $isModalPresented) {
            modalSheetContent
        }
        #else
        // macOS: Content without VStack wrapper, tab bar goes in toolbar
        Group {
            switch selectedVariantTab {
            case .embedded:
                embeddedVariantView
            case .modal:
                modalVariantView
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selectedVariantTab) {
                    ForEach(VariantTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .sheet(isPresented: $showPasskeySignUpSheet) {
            passkeySignUpSheet
        }
        .sheet(isPresented: $isModalPresented) {
            modalSheetContent
        }
        #endif
    }
    
    // MARK: - Embedded Variant View
    
    private var embeddedVariantView: some View {
        #if os(iOS)
        let maxWidth: CGFloat = 380
        #else
        let maxWidth: CGFloat = 448
        #endif
        
        return HStack {
            Spacer()
            VStack(spacing: 24) {
                // Header - OUTSIDE the card
                VStack(spacing: 8) {
                    // Entity Auth branding
                    Text("Entity Auth")
                        .font(.system(.title, design: .rounded, weight: .semibold))
                    
                    if let errorText {
                        Text(errorText)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .frame(maxWidth: maxWidth)
                
                // Card - Contains Tab Picker and Forms
                VStack(spacing: 0) {
                    // Tab Picker
                    CustomTabPicker(selection: $selectedAuthTab)
                        .padding(.bottom, 4)
                    
                    if selectedAuthTab == .signIn {
                        signInView
                    } else {
                        registerView
                    }
                }
                .padding(24)
                .background(
                    Group {
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
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.08 : 0.12), radius: 16, x: 0, y: 4)
                .frame(maxWidth: maxWidth)
            }
            .frame(maxWidth: maxWidth)
            .padding(.horizontal, 24)
            Spacer()
        }
    }
    
    // MARK: - Modal Variant View
    
    private var modalVariantView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Modal trigger button with Liquid Glass styling
            Button(action: { isModalPresented = true }) {
                Text("Sign in")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(minWidth: 140)
                    .background(
                        Group {
                            #if os(iOS)
                            if #available(iOS 26.0, *) {
                                Capsule()
                                    .fill(.regularMaterial)
                                    .glassEffect(.regular.interactive(true), in: .capsule)
                            } else {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                            }
                            #elseif os(macOS)
                            if #available(macOS 15.0, *) {
                                Capsule()
                                    .fill(.regularMaterial)
                                    .glassEffect(.regular.interactive(true), in: .capsule)
                            } else {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                            }
                            #else
                            Capsule()
                                .fill(.ultraThinMaterial)
                            #endif
                        }
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Modal Sheet Content
    
    private var modalSheetContent: some View {
        #if os(iOS)
        NavigationView {
            embeddedAuthForm
                .padding()
                .navigationTitle("Entity Auth")
                .navigationBarTitleDisplayMode(.inline)
        }
        .modifier(IOSSheetDetents())
        #else
        VStack(spacing: 0) {
            // Navigation-style header
            HStack {
                Spacer()
                Text("Entity Auth")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button {
                    isModalPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            embeddedAuthForm
                .padding(.horizontal)
        }
        .padding(.bottom)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 20))
        }
        .presentationSizing(.fitted)
        #endif
    }
    
    // MARK: - Embedded Auth Form (for modal)
    
    private var embeddedAuthForm: some View {
        #if os(iOS)
        let idealWidth: CGFloat = 380
        #else
        let idealWidth: CGFloat = 480
        #endif
        
        return VStack(spacing: 0) {
            // Header (error only in modal, title shown in navigation)
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
                // Tab Picker
                CustomTabPicker(selection: $selectedAuthTab)
                    .padding(.bottom, 4)
                
                if selectedAuthTab == .signIn {
                    signInView
                } else {
                    registerView
                }
            }
            .padding(24)
            .background(
                Group {
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
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.08 : 0.12), radius: 16, x: 0, y: 4)
        }
        .frame(idealWidth: idealWidth)
        .padding()
    }
    
    // MARK: - Sign In View
    
    private var signInView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 4)
            
            VStack(spacing: 12) {
            // Email/Password Form
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
            
            // SSO & Passkey Buttons (icon-only in a row)
            HStack(spacing: 12) {
                Button(action: {
                    let action = onGoogleSignIn ?? AuthDefaultActions.makeGoogleSignIn(provider: provider, errorText: $errorText)
                    Task {
                        isLoading = true
                        await action()
                        isLoading = false
                    }
                }) {
                    Image("Google", bundle: .module)
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
                
                Button(action: {
                    let action = onGitHubSignIn ?? AuthDefaultActions.makeGitHubSignIn(provider: provider, errorText: $errorText)
                    Task {
                        isLoading = true
                        await action()
                        isLoading = false
                    }
                }) {
                    Image("Github", bundle: .module)
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
                
                Button(action: {
                    let action = onPasskeySignIn ?? AuthDefaultActions.makePasskeySignIn(provider: provider, errorText: $errorText)
                    Task {
                        isLoading = true
                        await action()
                        isLoading = false
                    }
                }) {
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
    
    // MARK: - Register View
    
    private var registerView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 4)
            
            VStack(spacing: 12) {
            // Email/Password Form
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
            
            // SSO & Passkey Buttons (icon-only in a row)
            HStack(spacing: 12) {
                Button(action: {
                    let action = onGoogleSignIn ?? AuthDefaultActions.makeGoogleSignIn(provider: provider, errorText: $errorText)
                    Task {
                        isLoading = true
                        await action()
                        isLoading = false
                    }
                }) {
                    Image("Google", bundle: .module)
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
                
                Button(action: {
                    let action = onGitHubSignIn ?? AuthDefaultActions.makeGitHubSignIn(provider: provider, errorText: $errorText)
                    Task {
                        isLoading = true
                        await action()
                        isLoading = false
                    }
                }) {
                    Image("Github", bundle: .module)
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
                
                Button(action: {
                    showPasskeySignUpSheet = true
                }) {
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
    
    // MARK: - Passkey Sign Up Sheet
    
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
                .disabled(passkeySignUpEmail.isEmpty || isLoading)
                .opacity((passkeySignUpEmail.isEmpty || isLoading) ? 0.5 : 1.0)
                
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

// MARK: - Custom Tab Picker

/// Custom tab picker that mimics the toolbar variant switcher style using Liquid Glass
private struct CustomTabPicker: View {
    @Binding var selection: AuthView.AuthTab
    
    var body: some View {
        HStack(spacing: 0) {
            // Sign In Tab
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = .signIn 
                }
            }) {
                Text("Sign in")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(selection == .signIn ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background {
                if selection == .signIn {
                    Capsule()
                        .fill(.regularMaterial)
                        .glassEffect(.regular.interactive(true), in: .capsule)
                }
            }
            
            // Create Account Tab
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = .register 
                }
            }) {
                Text("Create account")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(selection == .register ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background {
                if selection == .register {
                    Capsule()
                        .fill(.regularMaterial)
                        .glassEffect(.regular.interactive(true), in: .capsule)
                }
            }
        }
        .padding(2)
        .background {
            Capsule()
                .fill(.tertiary.opacity(0.5))
        }
    }
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


