//
//  DocsView.swift
//  EntityDocsSwift
//
//  Main docs viewer with navigation
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct DocsView: View {
    let appName: String
    let initialSlug: [String]?
    let isChangelog: Bool
    
    private let loader = DocsLoader()
    @State private var pages: [ProcessedPage] = []
    @State private var selectedPage: ProcessedPage?
    @State private var error: Error?
    @State private var isLoading = true
    
    public init(appName: String, initialSlug: [String]? = nil, isChangelog: Bool = false) {
        self.appName = appName
        self.initialSlug = initialSlug
        self.isChangelog = isChangelog
    }
    
    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error = error {
                ErrorView(error: error)
            } else if let page = selectedPage {
                PageView(
                    page: page,
                    onLinkTap: handleLinkTap,
                    onBack: {
                        selectedPage = nil
                    }
                )
            } else {
                GridIndexView(
                    pages: pages,
                    isChangelog: isChangelog,
                    onPageSelect: { page in
                        selectedPage = page
                    }
                )
            }
        }
        .onAppear {
            loadPages()
        }
        .onChange(of: appName) { _ in
            loadPages()
        }
        .onChange(of: isChangelog) { _ in
            loadPages()
        }
    }
    
    private func loadPages() {
        isLoading = true
        error = nil
        selectedPage = nil // Clear selected page when switching
        
        do {
            var loadedPages = isChangelog 
                ? try loader.loadChangelog(appName: appName)
                : try loader.loadDocs(appName: appName)
            
            // Filter out "unreleased" from changelog (already done in loadChangelog, but double-check)
            if isChangelog {
                loadedPages = loadedPages.filter { page in
                    let slugString = page.slug.joined(separator: "/")
                    return slugString != "unreleased" && !slugString.contains("unreleased")
                }
            }
            
            pages = loadedPages
            
            if let initialSlug = initialSlug {
                selectedPage = pages.first { $0.slug == initialSlug }
            } else {
                // Don't auto-select first page - show grid instead
                selectedPage = nil
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func handleLinkTap(_ url: String) {
        // Handle internal links
        if url.hasPrefix("/") {
            let slug = url
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/")
                .map(String.init)
            
            if let page = pages.first(where: { $0.slug == slug }) {
                selectedPage = page
            }
        } else if let url = URL(string: url) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}

// MARK: - Page View

private struct PageView: View {
    let page: ProcessedPage
    let onLinkTap: @MainActor @Sendable (String) -> Void
    let onBack: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Back button
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                        Text("Back")
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(page.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let date = page.date {
                        Text(date, style: .date)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    if let description = page.description {
                        Text(description)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.bottom)
                
                // Content
                MarkdownRenderer(nodes: page.content.children, onLinkTap: onLinkTap)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Grid Index View

private struct GridIndexView: View {
    let pages: [ProcessedPage]
    let isChangelog: Bool
    let onPageSelect: (ProcessedPage) -> Void
    
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    private var columns: [GridItem] {
        #if os(macOS)
        return [GridItem(.flexible()), GridItem(.flexible())]
        #else
        // iOS: 2 columns on iPad, 1 on iPhone
        if horizontalSizeClass == .regular {
            return [GridItem(.flexible()), GridItem(.flexible())]
        } else {
            return [GridItem(.flexible())]
        }
        #endif
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(isChangelog ? "Changelog" : "Documentation")
                        .font(.system(size: 36, weight: .bold))
                    
                    if isChangelog {
                        Text("Follow along with updates and improvements")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Browse documentation and guides")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 24)
                .padding(.bottom, 32)
                
                // Grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(pages) { page in
                        ArticleCard(
                            page: page,
                            onTap: {
                                onPageSelect(page)
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Article Card

private struct ArticleCard: View {
    let page: ProcessedPage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Title and Date row
                HStack(alignment: .top, spacing: 12) {
                    Text(page.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if let date = page.date {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Description
                if let description = page.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("View article")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Failed to load documentation")
                .font(.headline)
            
            if let docsError = error as? DocsLoaderError {
                switch docsError {
                case .fileNotFound(let message):
                    VStack(spacing: 8) {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("To fix: Copy JSON files from Entity-Docs/dist/swift/{app-name}/ to your app's bundle resources in Xcode.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                case .invalidData(let message):
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                case .decodingError(let error):
                    Text("Decoding error: \(error.localizedDescription)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

