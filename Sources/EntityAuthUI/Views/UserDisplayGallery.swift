import SwiftUI
import EntityAuthDomain

/// A gallery view showcasing all UserDisplay component variants
/// Similar to AuthView and OrganizationSwitcher, demonstrates different usage patterns
public struct UserDisplayGallery: View {
    @Environment(\.entityAuthProvider) private var provider
    @State private var selectedVariantTab: VariantTab = .display
    @State private var showProfileSheet: Bool = false
    
    public enum VariantTab: String, CaseIterable {
        case display = "Display Variants"
        case button = "Interactive Button"
        case context = "In Context"
        
        var icon: String {
            switch self {
            case .display: return "person.crop.rectangle"
            case .button: return "hand.tap"
            case .context: return "apps.iphone"
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
            
            buttonVariantView
                .tabItem {
                    Label(VariantTab.button.rawValue, systemImage: VariantTab.button.icon)
                }
                .tag(VariantTab.button)
            
            contextVariantView
                .tabItem {
                    Label(VariantTab.context.rawValue, systemImage: VariantTab.context.icon)
                }
                .tag(VariantTab.context)
        }
        .sheet(isPresented: $showProfileSheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("User Profile")
                        .font(.title2.bold())
                    Text("This is where your profile settings would go")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showProfileSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        #else
        // macOS: Content without VStack wrapper, tab bar goes in toolbar
        Group {
            switch selectedVariantTab {
            case .display:
                displayVariantView
            case .button:
                buttonVariantView
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
        .sheet(isPresented: $showProfileSheet) {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Text("User Profile")
                        .font(.headline)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button("Done") { showProfileSheet = false }
                }
                .padding()
                
                Text("This is where your profile settings would go")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .frame(minWidth: 400, minHeight: 300)
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
                        
                        UserDisplay(provider: provider, variant: .expanded)
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // Compact variant
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compact (Glass Container)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        UserDisplay(provider: provider, variant: .compact)
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // Plain variant (no container)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plain (No Container)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        UserDisplay(provider: provider, variant: .plain)
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // Avatar only variant
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Avatar Only")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        UserDisplay(provider: provider, variant: .avatarOnly)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer(minLength: 40)
            }
        }
    }
    
    // MARK: - Button Variant View
    
    private var buttonVariantView: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 24) {
                    // Standard button
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Standard Size")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        UserButton(provider: provider, size: .standard) {
                            showProfileSheet = true
                        }
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // Compact button
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compact Size (for toolbars)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        UserButton(provider: provider, size: .compact) {
                            showProfileSheet = true
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
                // Mock Toolbar
                mockToolbar
                
                // Mock Settings Panel
                mockSettingsPanel
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }
    
    // MARK: - Mock UI Examples
    
    private var mockToolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Toolbar Example")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            HStack {
                Text("MyApp")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                
                Spacer()
                
                UserButton(provider: provider, size: .compact) {
                    showProfileSheet = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    
    private var mockSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings Panel Example")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Account Settings")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Spacer()
                }
                
                // User Display in Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current User")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    UserDisplay(provider: provider, variant: .expanded)
                }
                
                Divider()
                
                // Mock settings options
                VStack(spacing: 12) {
                    mockSettingRow(title: "Notifications", icon: "bell.fill")
                    mockSettingRow(title: "Privacy", icon: "hand.raised.fill")
                    mockSettingRow(title: "Appearance", icon: "paintbrush.fill")
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
    private func mockSettingRow(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.blue.opacity(0.1)))
            
            Text(title)
                .font(.system(.body, design: .rounded))
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.3))
        )
    }
}

