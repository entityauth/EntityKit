//
//  EntityKitSandboxiOSApp.swift
//  EntityKitSandboxiOS
//
//  Created by naaiyy on 10/20/25.
//

import SwiftUI
import EntityAuthUI

@main
struct EntityKitSandboxiOSApp: App {
    var body: some Scene {
        WindowGroup {
            SandboxRootView.withMockAuth()
        }
    }
}
