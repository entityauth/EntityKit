import SwiftUI

// MARK: - Shared Auth Tab Type

internal enum AuthTab {
    case signIn
    case register
}

// MARK: - Custom Tab Picker

internal struct CustomTabPicker: View {
    @Binding var selection: AuthTab
    
    var body: some View {
        HStack(spacing: 0) {
            // Sign In Tab
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = .signIn 
                }
            }) {
                Text("Sign in")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(selection == .signIn ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background {
                if selection == .signIn {
                    if #available(iOS 26, *) {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.regularMaterial)
                    }
                }
            }
            
            // Create Account Tab
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = .register 
                }
            }) {
                Text("Create account")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(selection == .register ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background {
                if selection == .register {
                    if #available(iOS 26, *) {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.regularMaterial)
                    }
                }
            }
        }
        .padding(2)
        .background {
            Capsule()
                .fill(.tertiary.opacity(0.5))
        }
    }
}

