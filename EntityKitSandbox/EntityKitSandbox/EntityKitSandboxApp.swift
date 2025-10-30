//
//  EntityKitSandboxApp.swift
//  EntityKitSandbox
//
//  Created by naaiyy on 10/20/25.
//

import SwiftUI
import EntityAuthUI

@main
struct EntityKitSandboxApp: App {
    var body: some Scene {
        WindowGroup {
            SandboxRootView.withMockAuth()
        }
    }
}
