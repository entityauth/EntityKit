import SwiftUI
import EntityAuthDomain

struct OrganizationsSectionView: View {
    var onDismiss: (() -> Void)?
    var showsHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsHeader {
                Text("Organizations")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
            }

            OrganizationList(onDismiss: onDismiss)

            ActiveOrgMembersSection()
        }
    }
}

private struct ActiveOrgMembersSection: View {
    @Environment(\.entityAuthProvider) private var ea
    @State private var activeOrgId: String?
    @State private var canManage: Bool = false
    @State private var meId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let orgId = activeOrgId {
                OrganizationMembersList(
                    orgId: orgId,
                    canManage: canManage,
                    currentUserId: meId
                )
            }
        }
        .task {
            await loadActive()
        }
    }

    private func loadActive() async {
        do {
            let snapshot = await ea.currentSnapshot()
            meId = snapshot.userId
            if let active = try await ea.activeOrganization() {
                activeOrgId = active.orgId
                canManage = (active.role.lowercased() == "owner" || active.role.lowercased() == "admin")
            } else {
                activeOrgId = nil
                canManage = false
            }
        } catch {
            activeOrgId = nil
            canManage = false
        }
    }
}

