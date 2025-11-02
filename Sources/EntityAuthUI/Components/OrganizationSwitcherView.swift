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
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    Text("Active")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.green.opacity(0.85)))
                                }
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
            print("[OrgSwitcher] load(): begin")
            let snap = await ea.currentSnapshot()
            let orgs = try await ea.organizations()
            organizations = orgs
            // Derive from provider if possible, otherwise preserve current
            let derivedActive = try await ea.activeOrganization()?.orgId ?? snap.activeOrganization?.orgId
            if let derivedActive { activeOrgId = derivedActive }
            print("[OrgSwitcher] load(): orgs=\(orgs.map{ $0.orgId }) active=\(activeOrgId ?? "nil") (derived=\(derivedActive ?? "nil"))")
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func switchTo(orgId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            print("[OrgSwitcher] switchTo(): switching to \(orgId)")
            try await ea.switchOrganization(id: orgId)
            activeOrgId = orgId
            print("[OrgSwitcher] switchTo(): switched, reloading")
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
            print("[OrgSwitcher] createOrg(): name=\(name) slug=\(slug)")
            try await ea.createOrganization(name: name, slug: slug, ownerId: userId)
            newOrgName = ""
            try? await load()
            // Prefer switching to the org we just created by slug fallback to first
            if let created = organizations.first(where: { ($0.slug ?? "") == slug })?.orgId {
                print("[OrgSwitcher] createOrg(): switching to created org id=\(created)")
                await switchTo(orgId: created)
            } else if let first = organizations.first?.orgId {
                print("[OrgSwitcher] createOrg(): created org not found, switching to first=\(first)")
                await switchTo(orgId: first)
            } else {
                print("[OrgSwitcher] createOrg(): no organizations found after creation")
            }
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


