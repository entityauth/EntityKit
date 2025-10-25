import SwiftUI
import EntityAuthDomain

public struct AuthGate: View {
    @Environment(\.entityAuthProvider) private var provider
    @State private var isSigningIn = false
    @State private var errorText: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Sign in to continue").font(.title3).bold()
            if let errorText { Text(errorText).foregroundStyle(.red).font(.footnote) }
            Button(action: { Task { await signInSSO() } }) {
                HStack {
                    Image(systemName: "globe")
                    Text(isSigningIn ? "Signing in..." : "Sign in with SSO")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSigningIn)
        }
        .padding(24)
    }

    private func signInSSO() async {
        guard let tenant = provider.workspaceTenantId() else { errorText = "Missing tenant id"; return }
        isSigningIn = true
        defer { isSigningIn = false }
        let base = provider.baseURL()
        let sso = EntityAuthSSO(baseURL: base)
        #if os(iOS)
        let callback = URL(string: "entityauth-demo://sso")!
        #else
        let callback = URL(string: "entityauth-demo-mac://sso")!
        #endif
        do {
            let result = try await sso.signIn(provider: "google", returnTo: callback, workspaceTenantId: tenant)
            try await provider.applyTokens(access: result.accessToken, refresh: result.refreshToken, sessionId: result.sessionId, userId: result.userId)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}


