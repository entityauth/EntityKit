import SwiftUI
import Combine
import EntityAuthDomain

public struct OrganizationSwitcherView: View {
    @Environment(\.entityAuthProvider) private var ea
    @State private var isLoading: Bool = false
    @State private var error: String?
    @State private var organizations: [OrganizationSummary] = []
    @State private var activeOrgId: String? = nil
    @State private var newOrgName: String = ""
    @State private var creating: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            if let error = error {
                Text(error).foregroundColor(.red).font(.caption)
            }
            List {
                Section("Your Organizations") {
                    ForEach(organizations, id: \.orgId) { org in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(org.name ?? org.slug ?? org.orgId).font(.body)
                                Text(org.role.capitalized).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if activeOrgId == org.orgId {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            } else {
                                Button(action: { Task { await switchTo(orgId: org.orgId) } }) {
                                    Text("Switch")
                                }.disabled(isLoading)
                            }
                        }
                    }
                }
                Section("Create Organization") {
                    HStack {
                        TextField("Name", text: $newOrgName)
                        Button(action: { Task { await createOrg() } }) {
                            if creating { ProgressView() } else { Text("Create") }
                        }.disabled(newOrgName.trimmingCharacters(in: .whitespaces).isEmpty || creating)
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
        }
        .onAppear { Task { await load() } }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snap = await ea.currentSnapshot()
            let orgs = try await ea.organizations()
            organizations = orgs
            activeOrgId = try await ea.activeOrganization()?.orgId
            if activeOrgId == nil { activeOrgId = snap.activeOrganization?.orgId }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func switchTo(orgId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await ea.switchOrganization(id: orgId)
            activeOrgId = orgId
            try? await load()
        } catch { self.error = error.localizedDescription }
    }

    private func createOrg() async {
        guard let userId = (await ea.currentSnapshot()).userId else { return }
        creating = true
        defer { creating = false }
        do {
            let name = newOrgName.trimmingCharacters(in: .whitespacesAndNewlines)
            let slug = makeSlug(name)
            try await ea.createOrganization(name: name, slug: slug, ownerId: userId)
            newOrgName = ""
            try? await load()
            if let first = organizations.first?.orgId { await switchTo(orgId: first) }
        } catch { self.error = error.localizedDescription }
    }

    private func makeSlug(_ input: String) -> String {
        let lowered = input.lowercased()
        let replaced = lowered
            .replacingOccurrences(of: "'s", with: "")
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: " ", with: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let filtered = replaced.unicodeScalars.filter { allowed.contains($0) }
        var result = String(String.UnicodeScalarView(filtered))
        while result.contains("--") { result = result.replacingOccurrences(of: "--", with: "-") }
        if result.hasPrefix("-") { result.removeFirst() }
        if result.hasSuffix("-") { result.removeLast() }
        return result.isEmpty ? "org" : result
    }
}


