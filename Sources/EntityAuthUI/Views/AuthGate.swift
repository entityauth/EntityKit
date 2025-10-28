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

    public init() {}

    public var body: some View {
        AuthView(
            email: $email,
            password: $password,
            errorText: $errorText,
            onSSOSignIn: signInSSO,
            onEmailSignIn: signInWithEmail
        )
    }
    
    // MARK: - Business Logic Delegates to EntityAuthDomain
    
    /// SSO sign-in logic - delegates to EntityAuthSSO
    private func signInSSO() async {
        guard let tenant = provider.workspaceTenantId() else {
            errorText = "Missing tenant id"
            return
        }
        
        let base = provider.baseURL()
        let sso = EntityAuthSSO(baseURL: base)
        #if os(iOS)
        let callback = provider.ssoCallbackURL() ?? URL(string: "entityauth-demo://sso")!
        #else
        let callback = provider.ssoCallbackURL() ?? URL(string: "entityauth-demo-mac://sso")!
        #endif
        
        do {
            EntityAuthDebugLog.log("[AuthGate] signInSSO begin tenant=\(tenant) base=\(base.absoluteString) callback=\(callback.absoluteString)")
            let result = try await sso.signIn(provider: "google", returnTo: callback, workspaceTenantId: tenant)
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
    
    /// Email/password sign-in logic
    private func signInWithEmail(email: String, password: String) async {
        // TODO: Implement email/password authentication
        // This would call provider or EntityAuthDomain logic
        EntityAuthDebugLog.log("[AuthGate] Email/password sign-in not implemented yet")
        errorText = "Email/password authentication coming soon"
    }
}


