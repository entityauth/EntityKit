//
//  ContentView.swift
//  EntityKitSandbox
//
//  Created by naaiyy on 10/20/25.
//

import SwiftUI
import EntityAuthUI
import EntityAuthDomain

struct ContentView: View {
    var body: some View {
        let config = EntityAuthConfig(
            environment: .custom(URL(string: "https://past-496129-8lrv74.entity-auth.com")!),   
            workspaceTenantId: "past-496129"
        )
        let facade = EntityAuthFacade(config: config)
        let provider = AnyEntityAuthProvider.live(facade: facade, config: config)
        return SandboxRootView()
            .entityAuthProvider(provider)
            .entityTheme(.default)
            .onAppear {
                print("[Sandbox] Using baseURL=\(config.baseURL.absoluteString) tenant=\(config.workspaceTenantId ?? "nil") env=\(config.environment)")
            }
    }
}

#Preview {
    ContentView()
}
