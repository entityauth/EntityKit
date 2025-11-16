import Foundation
import SwiftUI
import EntityAuthDomain

enum AuthDefaultActions {
    static func makeGoogleSignIn(provider: AnyEntityAuthProvider, errorText: Binding<String?>) -> (() async -> Void) {
        { await signInSSO(providerName: "google", provider: provider, errorText: errorText) }
    }

    static func makeGitHubSignIn(provider: AnyEntityAuthProvider, errorText: Binding<String?>) -> (() async -> Void) {
        { await signInSSO(providerName: "github", provider: provider, errorText: errorText) }
    }

    static func makePasskeySignIn(provider: AnyEntityAuthProvider, errorText: Binding<String?>) -> (() async -> Void) {
        { await signInWithPasskey(provider: provider, errorText: errorText) }
    }

    static func makePasskeySignUp(provider: AnyEntityAuthProvider, errorText: Binding<String?>) -> ((String) async -> Void) {
        { email in await signUpWithPasskey(email: email, provider: provider, errorText: errorText) }
    }

    static func makeEmailSignIn(provider: AnyEntityAuthProvider, errorText: Binding<String?>) -> ((String, String) async -> Void) {
        { email, password in await signInWithEmail(email: email, password: password, provider: provider, errorText: errorText) }
    }

    static func makeEmailRegister(provider: AnyEntityAuthProvider, errorText: Binding<String?>) -> ((String, String) async -> Void) {
        { email, password in await registerWithEmail(email: email, password: password, provider: provider, errorText: errorText) }
    }
}

// MARK: - Private helpers

private extension AuthDefaultActions {
    static func signInSSO(providerName: String, provider: AnyEntityAuthProvider, errorText: Binding<String?>) async {
        guard let tenant = provider.workspaceTenantId() else {
            await MainActor.run { errorText.wrappedValue = "Missing tenant id" }
            return
        }
        let base = provider.baseURL()
        let sso = await MainActor.run { EntityAuthSSO(baseURL: base) }
        #if os(iOS)
        let callback = provider.ssoCallbackURL() ?? URL(string: "entityauth://sso")!
        #else
        let callback = provider.ssoCallbackURL() ?? URL(string: "entityauth://sso")!
        #endif
        do {
            let result = try await sso.signIn(provider: providerName, returnTo: callback, workspaceTenantId: tenant)
            try await provider.applyTokens(access: result.accessToken, refresh: result.refreshToken, sessionId: result.sessionId, userId: result.userId)
            await MainActor.run { errorText.wrappedValue = nil }
        } catch {
            await MainActor.run { errorText.wrappedValue = error.localizedDescription }
        }
    }

    static func signInWithPasskey(provider: AnyEntityAuthProvider, errorText: Binding<String?>) async {
        guard provider.workspaceTenantId() != nil else {
            await MainActor.run { errorText.wrappedValue = "Missing tenant id" }
            return
        }
        do {
            let rpId = provider.rpId() ?? "entityauth.com"
            let origins = provider.origins() ?? ["https://entityauth.com"]
            let result = try await provider.passkeySignIn(rpId: rpId, origins: origins)
            try await provider.applyTokens(access: result.accessToken, refresh: result.refreshToken, sessionId: result.sessionId, userId: result.userId)
            await MainActor.run { errorText.wrappedValue = nil }
        } catch {
            await MainActor.run { errorText.wrappedValue = error.localizedDescription }
        }
    }

    static func signUpWithPasskey(email: String, provider: AnyEntityAuthProvider, errorText: Binding<String?>) async {
        guard provider.workspaceTenantId() != nil else {
            await MainActor.run { errorText.wrappedValue = "Missing tenant id" }
            return
        }
        do {
            let rpId = provider.rpId() ?? "entityauth.com"
            let origins = provider.origins() ?? ["https://entityauth.com"]
            let result = try await provider.passkeySignUp(email: email, rpId: rpId, origins: origins)
            try await provider.applyTokens(access: result.accessToken, refresh: result.refreshToken, sessionId: result.sessionId, userId: result.userId)
            await MainActor.run { errorText.wrappedValue = nil }
        } catch {
            await MainActor.run { errorText.wrappedValue = error.localizedDescription }
        }
    }

    static func signInWithEmail(email: String, password: String, provider: AnyEntityAuthProvider, errorText: Binding<String?>) async {
        guard let tenant = provider.workspaceTenantId() else {
            await MainActor.run { errorText.wrappedValue = "Missing tenant id" }
            return
        }
        do {
            let req = LoginRequest(email: email, password: password, workspaceTenantId: tenant)
            try await provider.login(request: req)
            await MainActor.run { errorText.wrappedValue = nil }
        } catch {
            await MainActor.run { errorText.wrappedValue = error.localizedDescription }
        }
    }

    static func registerWithEmail(email: String, password: String, provider: AnyEntityAuthProvider, errorText: Binding<String?>) async {
        guard let tenant = provider.workspaceTenantId() else {
            await MainActor.run { errorText.wrappedValue = "Missing tenant id" }
            return
        }
        do {
            let registerReq = RegisterRequest(email: email, password: password, workspaceTenantId: tenant, defaultWorkspaceRole: .owner)
            try await provider.register(request: registerReq)
            let loginReq = LoginRequest(email: email, password: password, workspaceTenantId: tenant)
            try await provider.login(request: loginReq)
            await MainActor.run { errorText.wrappedValue = nil }
        } catch {
            await MainActor.run { errorText.wrappedValue = error.localizedDescription }
        }
    }
}


