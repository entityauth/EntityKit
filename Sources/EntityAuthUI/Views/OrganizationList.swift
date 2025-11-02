import SwiftUI
import EntityAuthDomain

/// Reusable organization list component - shared between OrganizationSwitcherView and UserProfile
public struct OrganizationList: View {
    @Environment(\.entityAuthProvider) private var ea
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading: Bool = false
    @State private var error: String?
    @State private var organizations: [OrganizationSummary] = []
    @State private var activeOrgId: String? = nil
    @State private var newOrgName: String = ""
    @State private var newOrgSlug: String = ""
    @State private var creating: Bool = false
    @State private var showingCreateForm: Bool = false
    
    public var onDismiss: (() -> Void)?
    
    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header - Create button only
            HStack {
                Spacer()
                
                // Create button
                Button(action: { showingCreateForm.toggle() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // Content
            if showingCreateForm {
                createOrgForm
            } else {
                if organizations.isEmpty && !isLoading {
                    emptyStateView
                } else {
                    organizationsList
                }
            }
        }
        .onAppear { Task { await load() } }
    }
    
    // MARK: - Organizations List
    
    private var organizationsList: some View {
        VStack(spacing: 12) {
            ForEach(organizations, id: \.orgId) { org in
                organizationMenuItem(org: org)
            }
        }
    }
    
    @ViewBuilder
    private func organizationMenuItem(org: OrganizationSummary) -> some View {
        Button(action: {
            guard activeOrgId != org.orgId else { return }
            Task { 
                await switchTo(orgId: org.orgId)
                onDismiss?()
            }
        }) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(activeOrgId == org.orgId ? AnyShapeStyle(.blue.gradient) : AnyShapeStyle(.secondary.opacity(0.2)))
                        .frame(width: 40, height: 40)
                    
                    Text((org.name ?? org.slug ?? org.orgId).prefix(1).uppercased())
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(activeOrgId == org.orgId ? .white : .secondary)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(org.name ?? org.slug ?? org.orgId)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(org.role.capitalized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Active Badge
                if activeOrgId == org.orgId {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Group {
                    #if os(iOS)
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(activeOrgId == org.orgId ? .blue.opacity(0.1) : .clear)
                            .overlay(
                                Capsule()
                                    .strokeBorder(activeOrgId == org.orgId ? .blue.opacity(0.3) : .clear, lineWidth: 1)
                            )
                    } else {
                        Capsule()
                            .fill(activeOrgId == org.orgId ? .blue.opacity(0.1) : .clear)
                    }
                    #elseif os(macOS)
                    if #available(macOS 15.0, *) {
                        Capsule()
                            .fill(activeOrgId == org.orgId ? .blue.opacity(0.1) : .clear)
                            .overlay(
                                Capsule()
                                    .strokeBorder(activeOrgId == org.orgId ? .blue.opacity(0.3) : .clear, lineWidth: 1)
                            )
                    } else {
                        Capsule()
                            .fill(activeOrgId == org.orgId ? .blue.opacity(0.1) : .clear)
                    }
                    #else
                    Capsule()
                        .fill(activeOrgId == org.orgId ? .blue.opacity(0.1) : .clear)
                    #endif
                }
            )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!(isLoading || activeOrgId == org.orgId))
        .opacity(isLoading ? 0.5 : 1.0)
    }
    
    // MARK: - Create Organization Form
    
    private var createOrgForm: some View {
        VStack(spacing: 16) {
            HStack {
                Text("New Organization")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                
                Spacer()
                
                Button("Cancel") {
                    showingCreateForm = false
                    newOrgName = ""
                    newOrgSlug = ""
                }
                .font(.system(.subheadline, design: .rounded))
            }
            
            #if os(iOS)
            TextField("", text: $newOrgName, prompt: Text("Organization name"))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                )
                .autocapitalization(.words)
                .disabled(creating)
            
            TextField("", text: $newOrgSlug, prompt: Text("Slug"))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                )
                .autocapitalization(.none)
                .disabled(creating)
            #else
            TextField("", text: $newOrgName, prompt: Text("Organization name"))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                )
                .disabled(creating)
            
            TextField("", text: $newOrgSlug, prompt: Text("Slug"))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                )
                .disabled(creating)
            #endif
            
            Button(action: {
                Task {
                    await createOrg()
                    showingCreateForm = false
                }
            }) {
                HStack(spacing: 8) {
                    if creating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Create Organization")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Group {
                        #if os(iOS)
                        if #available(iOS 26.0, *) {
                            Capsule()
                                .fill(.blue.gradient)
                                .glassEffect(.regular.interactive(true), in: .capsule)
                        } else {
                            Capsule()
                                .fill(.blue.gradient)
                        }
                        #elseif os(macOS)
                        if #available(macOS 15.0, *) {
                            Capsule()
                                .fill(.blue.gradient)
                                .glassEffect(.regular.interactive(true), in: .capsule)
                        } else {
                            Capsule()
                                .fill(.blue.gradient)
                        }
                        #else
                        Capsule()
                            .fill(.blue.gradient)
                        #endif
                    }
                )
            }
            .buttonStyle(.plain)
            .disabled(newOrgName.trimmingCharacters(in: .whitespaces).isEmpty || newOrgSlug.trimmingCharacters(in: .whitespaces).isEmpty || creating)
            .opacity((newOrgName.trimmingCharacters(in: .whitespaces).isEmpty || newOrgSlug.trimmingCharacters(in: .whitespaces).isEmpty || creating) ? 0.5 : 1.0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("No organizations")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("Create your first organization to get started")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Data Operations
    
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snap = await ea.currentSnapshot()
            let orgs = try await ea.organizations()
            organizations = orgs
            let derivedActive = try await ea.activeOrganization()?.orgId ?? snap.activeOrganization?.orgId
            if let derivedActive { activeOrgId = derivedActive }
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
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func createOrg() async {
        guard let userId = (await ea.currentSnapshot()).userId else { return }
        creating = true
        defer { creating = false }
        do {
            let name = newOrgName.trimmingCharacters(in: .whitespacesAndNewlines)
            let slug = newOrgSlug.trimmingCharacters(in: .whitespacesAndNewlines)
            try await ea.createOrganization(name: name, slug: slug, ownerId: userId)
            newOrgName = ""
            newOrgSlug = ""
            try? await load()
            if let created = organizations.first(where: { ($0.slug ?? "") == slug })?.orgId {
                await switchTo(orgId: created)
            } else if let first = organizations.first?.orgId {
                await switchTo(orgId: first)
            }
        } catch {
            self.error = error.localizedDescription
        }
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

