import SwiftUI
import EntityAuthDomain

/// A gallery view showcasing all OrganizationDisplay component variants
public struct OrganizationDisplayGallery: View {
    @Environment(\.entityAuthProvider) private var provider
    @State private var selectedVariantTab: VariantTab = .display
    
    // Mock organizations for display
    private let mockOrganizations: [OrganizationSummary] = [
        OrganizationSummary(
            orgId: "org_acme",
            name: "Acme Corporation",
            slug: "acme",
            memberCount: 42,
            role: "owner",
            joinedAt: Date().timeIntervalSince1970,
            workspaceTenantId: "demo"
        ),
        OrganizationSummary(
            orgId: "org_tech",
            name: "Tech Innovators",
            slug: "tech-innovators",
            memberCount: 15,
            role: "admin",
            joinedAt: Date().timeIntervalSince1970,
            workspaceTenantId: "demo"
        ),
        OrganizationSummary(
            orgId: "org_design",
            name: "Design Studio",
            slug: "design-studio",
            memberCount: 8,
            role: "member",
            joinedAt: Date().timeIntervalSince1970,
            workspaceTenantId: "demo"
        )
    ]
    
    public enum VariantTab: String, CaseIterable {
        case display = "Display Variants"
        case context = "In Context"
        
        var icon: String {
            switch self {
            case .display: return "building.2"
            case .context: return "rectangle.stack"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        #if os(iOS)
        // iOS: Use standard bottom tab bar
        TabView(selection: $selectedVariantTab) {
            displayVariantView
                .tabItem {
                    Label(VariantTab.display.rawValue, systemImage: VariantTab.display.icon)
                }
                .tag(VariantTab.display)
            
            contextVariantView
                .tabItem {
                    Label(VariantTab.context.rawValue, systemImage: VariantTab.context.icon)
                }
                .tag(VariantTab.context)
        }
        #else
        // macOS: Content with toolbar picker
        Group {
            switch selectedVariantTab {
            case .display:
                displayVariantView
            case .context:
                contextVariantView
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
    
    // MARK: - Display Variant View
    
    private var displayVariantView: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 24) {
                    // Expanded variant
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expanded (Glass Container)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        OrganizationDisplay(organization: mockOrganizations[0], variant: .expanded)
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // Compact variant
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compact (Glass Container)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        OrganizationDisplay(organization: mockOrganizations[1], variant: .compact)
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // Plain variant (no container)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plain (No Container)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        OrganizationDisplay(organization: mockOrganizations[2], variant: .plain)
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // Avatar only variant
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Avatar Only")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(mockOrganizations, id: \.orgId) { org in
                                OrganizationDisplay(organization: org, variant: .avatarOnly)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer(minLength: 40)
            }
        }
    }
    
    // MARK: - Context Variant View
    
    private var contextVariantView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Organization List Example
                mockOrganizationList
                
                // Organization Card Example
                mockOrganizationCard
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }
    
    // MARK: - Mock UI Examples
    
    private var mockOrganizationList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Organization List Example")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            VStack(spacing: 12) {
                ForEach(mockOrganizations, id: \.orgId) { org in
                    HStack {
                        OrganizationDisplay(organization: org, variant: .compact)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.tertiary.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var mockOrganizationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Organization Card Example")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Active Organization")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    Spacer()
                }
                
                // Organization Display
                OrganizationDisplay(organization: mockOrganizations[0], variant: .expanded)
                
                Divider()
                
                // Mock stats
                HStack(spacing: 24) {
                    statItem(title: "Projects", value: "12")
                    statItem(title: "Members", value: "42")
                    statItem(title: "Active", value: "8")
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.tertiary.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

