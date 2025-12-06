import SwiftUI
import EntityAuthDomain

/// Simple modal auth component - shows a button that opens authentication in a sheet.
/// This is a clean 1-line API for auth - no TabView, no complexity.
public struct AuthViewModal: View {
    let title: String
    let authMethods: AuthMethods
    @State private var isPresented = false
    @Environment(\.colorScheme) private var colorScheme
    
    public init(title: String = "Sign in", authMethods: AuthMethods = AuthMethods()) {
        self.title = title
        self.authMethods = authMethods
    }
    
    public var body: some View {
        Button(action: { isPresented = true }) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .frame(minWidth: 160)
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
        .sheet(isPresented: $isPresented) {
            modalContent
        }
    }
    
    private var modalContent: some View {
        #if os(iOS)
        NavigationView {
            AuthGate(authMethods: authMethods, isModal: true)
                .padding()
                .navigationTitle("Sign In")
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #else
        VStack(spacing: 0) {
            // Navigation-style header
            HStack {
                Spacer()
                Text("Sign In")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            AuthGate(authMethods: authMethods, isModal: true)
        }
        .presentationSizing(.fitted)
        #endif
    }
}

