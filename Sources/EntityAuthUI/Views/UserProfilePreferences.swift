import SwiftUI

struct PreferencesSectionView: View {
    @Environment(\.appPreferencesContext) private var prefs
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
    @Environment(\.appPreferencesContext) private var prefs

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feature Preferences")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            if prefs.isLoading || prefs.value == nil {
                ProgressView().padding(.vertical, 8)
                    .onAppear {
                        print("[EntityKit][Preferences] Loading… isLoading=\(prefs.isLoading) valueIsNil=\(prefs.value == nil) hasOnChange=\(prefs.onChange != nil) hasOnSave=\(prefs.onSave != nil)")
                    }
            } else if let value = prefs.value {
                preferenceRow(title: "Chat", subtitle: "Conversations and messaging", isOn: value.chat) { newVal in
                    print("[EntityKit][Preferences] Toggle chat -> \(newVal)")
                    var v = value; v.chat = newVal; prefs.onChange?(v)
                }
                preferenceRow(title: "Notes", subtitle: "Create and organize notes", isOn: value.notes) { newVal in
                    print("[EntityKit][Preferences] Toggle notes -> \(newVal)")
                    var v = value; v.notes = newVal; prefs.onChange?(v)
                }
                preferenceRow(title: "Tasks", subtitle: "Task management and tracking", isOn: value.tasks) { newVal in
                    print("[EntityKit][Preferences] Toggle tasks -> \(newVal)")
                    var v = value; v.tasks = newVal; prefs.onChange?(v)
                }
                preferenceRow(title: "Feed", subtitle: "Activity feed and updates", isOn: value.feed) { newVal in
                    print("[EntityKit][Preferences] Toggle feed -> \(newVal)")
                    var v = value; v.feed = newVal; prefs.onChange?(v)
                }

                Divider().padding(.vertical, 6)

                Text("View Options")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                preferenceRow(title: "Global \"All\" View", subtitle: "Aggregate content across workspaces and personal space", isOn: value.globalViewEnabled) { newVal in
                    print("[EntityKit][Preferences] Toggle globalViewEnabled -> \(newVal)")
                    var v = value; v.globalViewEnabled = newVal; prefs.onChange?(v)
                }

                HStack {
                    Spacer()
                    Button(action: {
                        print("[EntityKit][Preferences] Save tapped (isSaving=\(prefs.isSaving))")
                        Task { await prefs.onSave?() }
                    }) {
                        Text(prefs.isSaving ? "Saving…" : "Save Changes")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .disabled(prefs.isSaving)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func preferenceRow(title: String, subtitle: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.body, design: .rounded, weight: .semibold))
                Text(subtitle).font(.system(.footnote, design: .rounded)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: onToggle))
                .labelsHidden()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}
