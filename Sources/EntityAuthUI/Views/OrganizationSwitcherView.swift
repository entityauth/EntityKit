import SwiftUI
import Combine
import EntityAuthDomain

public struct OrganizationSwitcherView: View {
    @Environment(\.entityAuthProvider) private var ea
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedVariantTab: VariantTab = .list
    @State private var showOrgSheet: Bool = false

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
            ScrollView {
                OrganizationList()
                    .padding()
            }
            #if os(iOS)
            .frame(maxWidth: min(geometry.size.width - 32, 600))
            .frame(maxWidth: .infinity)
            #else
            .frame(maxWidth: min(geometry.size.width - 64, 600))
            .frame(maxWidth: .infinity)
            #endif
        }
    }
    
    // MARK: - Popover Variant View
    
    private var popoverVariantView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            organizationSwitcherButton
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Organization Switcher Button (The actual component users will use)
    
    private var organizationSwitcherButton: some View {
        Button(action: { showOrgSheet = true }) {
            OrganizationSwitcherButtonContent()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showOrgSheet) {
            NavigationStack {
                OrganizationList(onDismiss: { showOrgSheet = false })
                    .padding()
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
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
    }
}

// MARK: - Organization Switcher Button Content

private struct OrganizationSwitcherButtonContent: View {
    @Environment(\.entityAuthProvider) private var ea
    @State private var activeOrg: OrganizationSummary?
    
    var body: some View {
        HStack(spacing: 10) {
            // Active Org Avatar
            if let activeOrg = activeOrg {
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
        .task {
            await loadActiveOrg()
        }
    }
    
    private func loadActiveOrg() async {
        do {
            let orgs = try await ea.organizations()
            let activeOrgId = try await ea.activeOrganization()?.orgId
            activeOrg = orgs.first(where: { $0.orgId == activeOrgId })
        } catch {
            // Silently fail - button will show "Select Organization"
        }
    }
}


