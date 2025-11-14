import SwiftUI

struct DeleteAccountContent: View {
    @Environment(\.entityAuthProvider) private var provider
    @State private var isDeleting = false
    @State private var showConfirmation = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Warning message
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.red)
                    
                    Text("Warning")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.red)
                }
                
                Text("This will permanently delete your account, including all your data, organizations, and settings. This action is irreversible.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.red.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.red.opacity(0.3), lineWidth: 1)
            )
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            
            // Delete button
            Button(action: {
                showConfirmation = true
            }) {
                HStack(spacing: 12) {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image("DeleteX", bundle: .module)
                            .resizable()
                            .renderingMode(.original)
                            .frame(width: 18, height: 18)
                    }
                    
                    Text(isDeleting ? "Deleting..." : "Delete My Account")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(.red.gradient)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .alert("Delete Account", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("Are you absolutely sure? This action cannot be undone. This will permanently delete your account and remove all of your data from our servers.")
        }
    }
    
    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil
        
        do {
            try await provider.deleteAccount()
            // Account deletion succeeded - auth state is cleared by the facade
            // The UI should automatically transition to unauthenticated state
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            isDeleting = false
        }
    }
}

