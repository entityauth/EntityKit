import SwiftUI

struct DeleteAccountContent: View {
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
            
            // Delete button
            Button(action: {
                // TODO: Implement delete account flow
            }) {
                HStack(spacing: 12) {
                    Image("DeleteX", bundle: .module)
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 18, height: 18)
                    
                    Text("Delete My Account")
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
            .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

