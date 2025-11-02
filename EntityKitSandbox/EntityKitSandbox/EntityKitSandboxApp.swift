//
//  EntityKitSandboxApp.swift
//  EntityKitSandbox
//
//  Created by naaiyy on 10/20/25.
//

import SwiftUI
import EntityAuthUI

#if os(macOS)
import AppKit
#endif

@main
struct EntityKitSandboxApp: App {
    var body: some Scene {
        WindowGroup {
            SandboxRootView.withMockAuth()
                #if os(macOS)
                .glassWindowConfigurator()
                .glassBackground()
                .ignoresSafeArea(.all)
                #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
}

#if os(macOS)
// MARK: - Glass Background
struct LiquidGlassBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.autoresizingMask = [.width, .height]
        view.blendingMode = .behindWindow
        view.material = .underWindowBackground
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .underWindowBackground
        nsView.state = .active
    }
}

// MARK: - Glass Window Configurator
private struct GlassWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                configure(window)
            }
        }
    }

    private func configure(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
        if #available(macOS 12.0, *) {
            window.titlebarSeparatorStyle = .none
        }
    }
}

// MARK: - View Extensions
extension View {
    func glassBackground() -> some View {
        self.background(LiquidGlassBackgroundView().ignoresSafeArea())
    }

    func glassWindowConfigurator() -> some View {
        self.background(GlassWindowConfigurator())
    }
}
#endif
