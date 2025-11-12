import SwiftUI
import EntityAuthDomain

struct AccountSectionView: View {
    let provider: AnyEntityAuthProvider
    @Binding var isEditing: Bool
    let onSave: (String, String) -> Void
    let onImageSelected: (Data) -> Void
    var showsHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsHeader {
                header
            }

            content
        }
    }

    private var header: some View {
        HStack {
            Text("Account")
                .font(.system(.title2, design: .rounded, weight: .semibold))

            Spacer()

            Button(action: { isEditing.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: isEditing ? "xmark.circle.fill" : "pencil.circle.fill")
                        .font(.system(size: 16, weight: .semibold))

                    Text(isEditing ? "Cancel" : "Edit")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(isEditing ? Color.secondary : Color.blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(editButtonBackground)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var editButtonBackground: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(.regularMaterial)
                .glassEffect(.regular.interactive(true), in: .capsule)
        } else {
            Capsule()
                .fill(.quaternary)
        }
        #elseif os(macOS)
        if #available(macOS 15.0, *) {
            Capsule()
                .fill(.regularMaterial)
                .glassEffect(.regular.interactive(true), in: .capsule)
        } else {
            Capsule()
                .fill(.quaternary)
        }
        #else
        Capsule()
            .fill(.quaternary)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if isEditing {
            UserDisplayEditable(
                provider: provider,
                onSave: onSave,
                onCancel: { isEditing = false },
                onImageSelected: onImageSelected
            )
        } else {
            UserDisplay(provider: provider, variant: .plain)
        }
    }
}

