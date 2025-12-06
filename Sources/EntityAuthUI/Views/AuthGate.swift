import SwiftUI
import EntityAuthDomain
import EntityAuthCore

/// Orchestrates UI (AuthView) + Logic (EntityAuthDomain).
/// Connects pure UI components to business logic.
public struct AuthGate: View {
    @Environment(\.entityAuthProvider) private var provider
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorText: String?
    
    private var authMethods: AuthMethods
    private var isModal: Bool

    public init(authMethods: AuthMethods = AuthMethods(), isModal: Bool = false) {
        self.authMethods = authMethods
        self.isModal = isModal
    }

    public var body: some View {
        AuthFormContent(
            email: $email,
            password: $password,
            errorText: $errorText,
            authMethods: authMethods,
            isModal: isModal,
            onGoogleSignIn: signInWithGoogle,
            onGitHubSignIn: signInWithGitHub,
            onPasskeySignIn: signInWithPasskey,
            onPasskeySignUp: signUpWithPasskey,
            onEmailSignIn: signInWithEmail,
            onEmailRegister: registerWithEmail
        )
    }
    
    // MARK: - Business Logic Delegates to EntityAuthDomain
    
    /// Google SSO sign-in logic
    private func signInWithGoogle() async {
        await signInSSO(provider: "google")
    }
    
    /// GitHub SSO sign-in logic
    private func signInWithGitHub() async {
        await signInSSO(provider: "github")
    }
    
    /// Generic SSO sign-in logic - delegates to EntityAuthSSO
    private func signInSSO(provider providerName: String) async {
        guard provider.workspaceTenantId() != nil else {
            errorText = "Missing tenant id"
            return
        }
        let tenant = provider.workspaceTenantId()!
        
        let base = provider.baseURL()
        let sso = EntityAuthSSO(baseURL: base)
        #if os(iOS)
        let callback = provider.ssoCallbackURL() ?? URL(string: "entityauth://sso")!
        #else
        let callback = provider.ssoCallbackURL() ?? URL(string: "entityauth://sso")!
        #endif
        
        do {
            EntityAuthDebugLog.log("[AuthGate] signInSSO begin provider=\(providerName) tenant=\(tenant) base=\(base.absoluteString) callback=\(callback.absoluteString)")
            let result = try await sso.signIn(provider: providerName, returnTo: callback, workspaceTenantId: tenant)
            try await provider.applyTokens(
                access: result.accessToken,
                refresh: result.refreshToken,
                sessionId: result.sessionId,
                userId: result.userId
            )
            EntityAuthDebugLog.log("[AuthGate] signInSSO success userId=\(result.userId)")
            errorText = nil
        } catch {
            EntityAuthDebugLog.log("[AuthGate] signInSSO error:", error.localizedDescription)
            errorText = error.localizedDescription
        }
    }
    
    /// Passkey sign-in logic
    private func signInWithPasskey() async {
        guard provider.workspaceTenantId() != nil else {
            errorText = "Missing tenant id"
            return
        }
        
        do {
            EntityAuthDebugLog.log("[AuthGate] signInWithPasskey begin")
            
            // Use rpId and origins from provider if available, otherwise use sensible defaults
            let rpId = provider.rpId() ?? "entityauth.com"
            let origins = provider.origins() ?? ["https://entityauth.com"]
            
            let result = try await provider.passkeySignIn(rpId: rpId, origins: origins)
            try await provider.applyTokens(
                access: result.accessToken,
                refresh: result.refreshToken ?? "",
                sessionId: result.sessionId,
                userId: result.userId
            )
            EntityAuthDebugLog.log("[AuthGate] signInWithPasskey success userId=\(result.userId)")
            errorText = nil
        } catch {
            EntityAuthDebugLog.log("[AuthGate] signInWithPasskey error:", error.localizedDescription)
            errorText = error.localizedDescription
        }
    }
    
    /// Passkey sign-up logic
    private func signUpWithPasskey(email: String) async {
        guard provider.workspaceTenantId() != nil else {
            errorText = "Missing tenant id"
            return
        }
        
        do {
            EntityAuthDebugLog.log("[AuthGate] signUpWithPasskey begin email=\(email)")
            
            // Use rpId and origins from provider if available, otherwise use sensible defaults
            let rpId = provider.rpId() ?? "entityauth.com"
            let origins = provider.origins() ?? ["https://entityauth.com"]
            
            let result = try await provider.passkeySignUp(email: email, rpId: rpId, origins: origins)
            try await provider.applyTokens(
                access: result.accessToken,
                refresh: result.refreshToken ?? "",
                sessionId: result.sessionId,
                userId: result.userId
            )
            EntityAuthDebugLog.log("[AuthGate] signUpWithPasskey success userId=\(result.userId)")
            errorText = nil
        } catch {
            EntityAuthDebugLog.log("[AuthGate] signUpWithPasskey error:", error.localizedDescription)
            errorText = error.localizedDescription
        }
    }
    
    /// Email/password sign-in logic
    private func signInWithEmail(email: String, password: String) async {
        guard let tenant = provider.workspaceTenantId() else {
            errorText = "Missing tenant id"
            return
        }
        
        do {
            EntityAuthDebugLog.log("[AuthGate] signInWithEmail begin email=\(email)")
            let request = LoginRequest(email: email, password: password, workspaceTenantId: tenant)
            try await provider.login(request: request)
            EntityAuthDebugLog.log("[AuthGate] signInWithEmail success")
            errorText = nil
        } catch {
            EntityAuthDebugLog.log("[AuthGate] signInWithEmail error:", error.localizedDescription)
            errorText = error.localizedDescription
        }
    }
    
    /// Email/password registration logic
    private func registerWithEmail(email: String, password: String) async {
        guard let tenant = provider.workspaceTenantId() else {
            errorText = "Missing tenant id"
            return
        }
        
        do {
            EntityAuthDebugLog.log("[AuthGate] registerWithEmail begin email=\(email)")
            
            // Register the user
            let registerRequest = RegisterRequest(
                email: email,
                password: password,
                workspaceTenantId: tenant,
                defaultWorkspaceRole: .owner
            )
            try await provider.register(request: registerRequest)
            EntityAuthDebugLog.log("[AuthGate] registerWithEmail registration success, now logging in")
            
            // Automatically log in after registration
            let loginRequest = LoginRequest(email: email, password: password, workspaceTenantId: tenant)
            try await provider.login(request: loginRequest)
            EntityAuthDebugLog.log("[AuthGate] registerWithEmail login success")
            errorText = nil
        } catch {
            EntityAuthDebugLog.log("[AuthGate] registerWithEmail error:", error.localizedDescription)
            errorText = error.localizedDescription
        }
    }
}


