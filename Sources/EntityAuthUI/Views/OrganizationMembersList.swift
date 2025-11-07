import SwiftUI
import EntityAuthDomain

public struct OrganizationMembersList: View {
    @Environment(\.entityAuthProvider) private var ea
    @Environment(\.colorScheme) private var colorScheme

    private let orgId: String
    private let canManage: Bool
    private let currentUserId: String?

    @State private var loading = false
    @State private var members: [OrgMemberDTO] = []
    @State private var error: String?

    public init(orgId: String, canManage: Bool, currentUserId: String?) {
        self.orgId = orgId
        self.canManage = canManage
        self.currentUserId = currentUserId
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
                if let me = currentUserId {
                    Button("Leave") { Task { await leave(userId: me) } }
                        .buttonStyle(.bordered)
                }
            }
            if loading {
                ProgressView().padding(.vertical, 12)
            } else if members.isEmpty {
                roundedInfo("No members yet")
            } else {
                ForEach(members, id: \.userId) { m in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.userId)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Text("Role: \(m.role)")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if canManage, m.userId != (currentUserId ?? "") {
                            Button("Remove") { Task { await remove(userId: m.userId) } }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
            }
            if let error {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .onAppear { Task { await refresh() } }
    }

    @ViewBuilder
    private func roundedInfo(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
            )
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        do {
            members = try await ea.listMembers(orgId: orgId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func leave(userId: String) async {
        await remove(userId: userId)
    }

    private func remove(userId: String) async {
        do {
            try await ea.removeMember(orgId: orgId, userId: userId)
            try? await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
}


