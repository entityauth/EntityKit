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
    @State private var selectedVariantTab: VariantTab = .list
    @State private var showOrgSheet: Bool = false
    @State private var showingCreateFormInSheet: Bool = false

    public enum VariantTab: String, CaseIterable {
        case list = "List View"
        case popover = "Menu"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .popover: return "chevron.down.circle"
            }
        }
    }

    public init() {}

    public var body: some View {
        #if os(iOS)
        // iOS: Use standard bottom tab bar
        TabView(selection: $selectedVariantTab) {
            listVariantView
                .tabItem {
                    Label(VariantTab.list.rawValue, systemImage: VariantTab.list.icon)
                }
                .tag(VariantTab.list)
            
            popoverVariantView
                .tabItem {
                    Label(VariantTab.popover.rawValue, systemImage: VariantTab.popover.icon)
                }
                .tag(VariantTab.popover)
        }
        #else
        // macOS: Content without VStack wrapper, tab bar goes in toolbar
        Group {
            switch selectedVariantTab {
            case .list:
                listVariantView
            case .popover:
                popoverVariantView
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selectedVariantTab) {
                    ForEach(VariantTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        #endif
    }
    
    // MARK: - List Variant View
    
    private var listVariantView: some View {
        GeometryReader { geometry in
            List {
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                ForEach(organizations, id: \.orgId) { org in
                    organizationRow(org: org)
                        #if os(iOS)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        #endif
                        .listRowSeparator(.hidden)
                        .listRowBackground(
                            Group {
                                #if os(iOS)
                                if #available(iOS 26.0, *) {
                                    Capsule()
                                        .fill(.regularMaterial)
                                        .glassEffect(.regular.interactive(true), in: .capsule)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 3)
                                } else {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 3)
                                }
                                #elseif os(macOS)
                                if #available(macOS 15.0, *) {
                                    Capsule()
                                        .fill(.regularMaterial)
                                        .glassEffect(.regular.interactive(true), in: .capsule)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 3)
                                } else {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 3)
                                }
                                #else
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 3)
                                #endif
                            }
                        )
                }
            }
            #if os(iOS)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: min(geometry.size.width - 32, 600))
            .frame(maxWidth: .infinity)
            #else
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: min(geometry.size.width - 64, 600))
            .frame(maxWidth: .infinity)
            #endif
        }
        .toolbar {
            ToolbarItem(placement: {
                #if os(iOS)
                .topBarTrailing
                #else
                .automatic
                #endif
            }()) {
                createOrgButton
            }
        }
        .onAppear { Task { await load() } }
    }
    
    // MARK: - Organization Row
    
    @ViewBuilder
    private func organizationRow(org: OrganizationSummary) -> some View {
        HStack(spacing: 16) {
            // Organization Info
            VStack(alignment: .leading, spacing: 6) {
                Text(org.name ?? org.slug ?? org.orgId)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Text(org.role.capitalized)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Status or Action
            if activeOrgId == org.orgId {
                activeOrgBadge
            } else {
                switchButton(for: org)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Capsule())
    }
    
    // MARK: - Active Org Badge
    
    private var activeOrgBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            
            Text("Active")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Group {
                #if os(iOS)
                if #available(iOS 26.0, *) {
                    Capsule()
                        .fill(.green.gradient)
                        .glassEffect(.regular.interactive(false), in: .capsule)
                } else {
                    Capsule()
                        .fill(.green.gradient)
                        .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                #elseif os(macOS)
                if #available(macOS 15.0, *) {
                    Capsule()
                        .fill(.green.gradient)
                        .glassEffect(.regular.interactive(false), in: .capsule)
                } else {
                    Capsule()
                        .fill(.green.gradient)
                        .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                #else
                Capsule()
                    .fill(.green.gradient)
                #endif
            }
        )
    }
    
    // MARK: - Switch Button
    
    @ViewBuilder
    private func switchButton(for org: OrganizationSummary) -> some View {
        Button(action: { Task { await switchTo(orgId: org.orgId) } }) {
            Text("Switch")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Group {
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
                )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.5 : 1.0)
    }
    
    // MARK: - Popover Variant View
    
    private var popoverVariantView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            organizationSwitcherButton
            
            Spacer()
        }
        .padding()
        .task { await load() }
    }
    
    // MARK: - Organization Switcher Button (The actual component users will use)
    
    private var organizationSwitcherButton: some View {
        Button(action: { showOrgSheet = true }) {
            HStack(spacing: 10) {
                // Active Org Avatar
                if let activeOrg = organizations.first(where: { $0.orgId == activeOrgId }) {
                    ZStack {
                        Circle()
                            .fill(.blue.gradient)
                            .frame(width: 32, height: 32)
                        
                        Text((activeOrg.name ?? activeOrg.slug ?? activeOrg.orgId).prefix(1).uppercased())
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeOrg.name ?? activeOrg.slug ?? activeOrg.orgId)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Text(activeOrg.role.capitalized)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    Text("Select Organization")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 320)
            .background(
                Group {
                    #if os(iOS)
                    if #available(iOS 26.0, *) {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(true), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
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
                        .fill(.ultraThinMaterial)
                    #endif
                }
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showOrgSheet) {
            NavigationStack {
                if showingCreateFormInSheet {
                    createOrgFormContentView
                        .navigationTitle("New Organization")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Back") {
                                    showingCreateFormInSheet = false
                                    newOrgName = ""
                                }
                            }
                        }
                } else {
                    organizationSwitcherContent
                        .navigationTitle("Organizations")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showOrgSheet = false
                                }
                            }
                        }
                }
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
            .onDisappear {
                showingCreateFormInSheet = false
            }
        }
    }
    
    // MARK: - Organization Switcher Content (Shared between sheet/menu)
    
    private var organizationSwitcherContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Organizations List
                VStack(spacing: 12) {
                    ForEach(organizations, id: \.orgId) { org in
                        organizationMenuItem(org: org)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Create Button
                Button(action: { 
                    showingCreateFormInSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Create Organization")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
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
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private func organizationMenuItem(org: OrganizationSummary) -> some View {
        Button(action: {
            guard activeOrgId != org.orgId else { return }
            Task { 
                await switchTo(orgId: org.orgId)
                showOrgSheet = false
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
        .disabled(isLoading || activeOrgId == org.orgId)
        .opacity(isLoading ? 0.5 : 1.0)
    }
    
    
    // MARK: - Create Org Button
    
    private var createOrgButton: some View {
        Button(action: { showingCreateFormInSheet = true }) {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                Circle()
                    .fill(.regularMaterial)
                    .glassEffect(.regular.interactive(true), in: .circle)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
            }
            #elseif os(macOS)
            if #available(macOS 15.0, *) {
                Circle()
                    .fill(.regularMaterial)
                    .glassEffect(.regular.interactive(true), in: .circle)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
            }
            #else
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            #endif
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Create Organization Form Content (shown inline in sheet)
    
    private var createOrgFormContentView: some View {
        VStack(spacing: 20) {
            TextField("Organization Name", text: $newOrgName)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            Button(action: {
                Task {
                    await createOrg()
                    showingCreateFormInSheet = false
                    showOrgSheet = false
                }
            }) {
                if creating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Organization")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(newOrgName.trimmingCharacters(in: .whitespaces).isEmpty || creating)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top)
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


