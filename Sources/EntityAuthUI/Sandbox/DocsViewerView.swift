//
//  DocsViewerView.swift
//  EntityAuthUI
//
//  Docs viewer for EntityKitSandbox
//

import SwiftUI
import EntityDocsSwift

struct DocsViewerView: View {
    @State private var selectedAppTab: AppTab = .entityAuth
    @State private var isChangelog = false
    
    enum AppTab: String, CaseIterable {
        case entityAuth = "Entity Auth"
        case past = "Past"
        
        var appName: String {
            switch self {
            case .entityAuth: return "entity-auth"
            case .past: return "past"
            }
        }
        
        var icon: String {
            switch self {
            case .entityAuth: return "lock.shield"
            case .past: return "clock"
            }
        }
    }
    
    var body: some View {
        #if os(iOS)
        // iOS: Use standard bottom tab bar for apps, segmented control for docs/changelog
        VStack(spacing: 0) {
            // Docs/Changelog toggle at top
            HStack {
                Picker("Type", selection: $isChangelog) {
                    Text("Docs").tag(false)
                    Text("Changelog").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            
            // App tabs
            TabView(selection: $selectedAppTab) {
                DocsView(appName: AppTab.entityAuth.appName, isChangelog: isChangelog)
                    .tabItem {
                        Label(AppTab.entityAuth.rawValue, systemImage: AppTab.entityAuth.icon)
                    }
                    .tag(AppTab.entityAuth)
                
                DocsView(appName: AppTab.past.appName, isChangelog: isChangelog)
                    .tabItem {
                        Label(AppTab.past.rawValue, systemImage: AppTab.past.icon)
                    }
                    .tag(AppTab.past)
            }
        }
        #else
        // macOS: Content with toolbar pickers
        Group {
            DocsView(appName: selectedAppTab.appName, isChangelog: isChangelog)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 16) {
                    Picker("", selection: $selectedAppTab) {
                        ForEach(AppTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    
                    Picker("", selection: $isChangelog) {
                        Text("Docs").tag(false)
                        Text("Changelog").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
            }
        }
        #endif
    }
}

