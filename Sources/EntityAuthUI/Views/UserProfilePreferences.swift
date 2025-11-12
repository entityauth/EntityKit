import SwiftUI

struct PreferencesSectionView: View {
    var showsHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsHeader {
                Text("Preferences")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
            }

            PreferencesContent()
        }
    }
}

private struct PreferencesContent: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            HStack(spacing: 12) {
                themeButton(title: "Light", icon: "sun.max.fill", isSelected: false)
                themeButton(title: "Dark", icon: "moon.fill", isSelected: true)
                themeButton(title: "Auto", icon: "circle.lefthalf.filled", isSelected: false)
            }
        }
    }

    @ViewBuilder
    private func themeButton(title: String, icon: String, isSelected: Bool) -> some View {
        Button(action: {
            // TODO: Implement theme switching
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

