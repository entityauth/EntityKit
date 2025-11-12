import SwiftUI
import EntityAuthDomain

/// A gallery view showcasing UserProfile component variants
public struct UserProfileGallery: View {
    @Environment(\.entityAuthProvider) private var provider
    @State private var selectedVariantTab: VariantTab = .button
    
    public enum VariantTab: String, CaseIterable {
        case button = "Button Variants"
        case toolbar = "Toolbar Example"
        case withDocs = "With Documentation"
        
        var icon: String {
            switch self {
            case .button: return "hand.tap"
            case .toolbar: return "menubar.rectangle"
            case .withDocs: return "doc.text"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        #if os(iOS)
        // iOS: Use standard bottom tab bar
        TabView(selection: $selectedVariantTab) {
            buttonVariantView
                .tabItem {
                    Label(VariantTab.button.rawValue, systemImage: VariantTab.button.icon)
                }
                .tag(VariantTab.button)
            
            toolbarVariantView
                .tabItem {
                    Label(VariantTab.toolbar.rawValue, systemImage: VariantTab.toolbar.icon)
                }
                .tag(VariantTab.toolbar)
            
            withDocsVariantView
                .tabItem {
                    Label(VariantTab.withDocs.rawValue, systemImage: VariantTab.withDocs.icon)
                }
                .tag(VariantTab.withDocs)
        }
        #else
        // macOS: Content with toolbar picker
        Group {
            switch selectedVariantTab {
            case .button:
                buttonVariantView
            case .toolbar:
                toolbarVariantView
            case .withDocs:
                withDocsVariantView
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
    
    // MARK: - Button Variant View
    
    private var buttonVariantView: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 24) {
                    // Standard UserProfile button
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Standard Interactive Button")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        UserProfile()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer(minLength: 40)
            }
        }
    }
    
    // MARK: - Toolbar Variant View
    
    private var toolbarVariantView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Mock App with Toolbar
                mockAppWithToolbar
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }
    
    // MARK: - Mock UI Examples
    
    private var mockAppWithToolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Toolbar Example")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 16) {
                    // App title
                    Text("My App")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    
                    Spacer()
                    
                    // Navigation buttons
                    HStack(spacing: 12) {
                        Button(action: {}) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {}) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        // User profile toolbar button
                        UserProfileToolbarButton()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Rectangle()
                        .fill(.regularMaterial)
                )
                .overlay(
                    Rectangle()
                        .strokeBorder(.tertiary.opacity(0.2), lineWidth: 1),
                    alignment: .bottom
                )
                
                // Mock content area
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)
                        
                        Text("Your App Content Here")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                    }
                    .padding(.vertical, 60)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .background(
                    Rectangle()
                        .fill(.quaternary.opacity(0.3))
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.tertiary.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - With Docs Variant View
    
    private var withDocsVariantView: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 24) {
                    // UserProfile with docs enabled (entity-auth)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("With Documentation (Entity Auth)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Text("Shows docs and changelog for 'entity-auth' app")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        UserProfile(
                            featureFlags: UserProfileFeatureFlags(
                                showDocs: true,
                                docsAppName: "entity-auth"
                            )
                        )
                    }
                    
                    Divider()
                    
                    // UserProfile with docs enabled (past)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("With Documentation (Past)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Text("Shows docs and changelog for 'past' app")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        UserProfile(
                            featureFlags: UserProfileFeatureFlags(
                                showDocs: true,
                                docsAppName: "past"
                            )
                        )
                    }
                    
                    Divider()
                    
                    // UserProfile with all features including docs
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Features + Documentation")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Text("Includes preferences, security, delete account, and docs")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        UserProfile(
                            featureFlags: UserProfileFeatureFlags(
                                showPreferences: true,
                                showSecurity: true,
                                showDeleteAccount: true,
                                showDocs: true,
                                docsAppName: "entity-auth"
                            )
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer(minLength: 40)
            }
        }
    }
}

