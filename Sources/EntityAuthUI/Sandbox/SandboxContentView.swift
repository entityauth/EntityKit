//
//  SandboxContentView.swift
//  EntityKit Sandbox
//
//  Shared entry point for both iOS and macOS sandbox apps
//

import SwiftUI

public struct SandboxContentView: View {
    public init() {}
    
    public var body: some View {
        SandboxRootView()
            .entityTheme(.default)
            .entityAuthProvider(.preview(name: "John Appleseed", email: "john@example.com"))
    }
}

#Preview {
    SandboxContentView()
}

