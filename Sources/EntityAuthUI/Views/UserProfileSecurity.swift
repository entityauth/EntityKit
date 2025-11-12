import SwiftUI

struct SecuritySectionView: View {
    var showsHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsHeader {
                Text("Security")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
            }

            SecurityContent()
        }
    }
}

// MARK: - Security Content (Shared)
private struct SecurityContent: View {
    var body: some View {
        VStack(spacing: 12) {
            securityOption(title: "Change Password", icon: "key.fill")
            securityOption(title: "Two-Factor Authentication", icon: "shield.checkered")
            securityOption(title: "Passkeys", icon: "person.badge.key.fill")
            securityOption(title: "Active Sessions", icon: "laptopcomputer.and.iphone")
        }
    }
    
    @ViewBuilder
    private func securityOption(title: String, icon: String) -> some View {
        Button(action: {
            // TODO: Implement security actions
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

