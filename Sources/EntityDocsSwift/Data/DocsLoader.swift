//
//  DocsLoader.swift
//  EntityDocsSwift
//
//  Loads processed MDX data from JSON files
//

import Foundation

public enum DocsLoaderError: Error {
    case fileNotFound(String)
    case invalidData(String)
    case decodingError(Error)
}

public struct DocsLoader {
    private let bundle: Bundle
    
    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }
    
    /// Get the module bundle where JSON files are bundled
    private var moduleBundle: Bundle {
        // For Swift Package Manager, Bundle.module is automatically available
        // and contains the resources from the package
        return Bundle.module
    }
    
    /// Load docs for a specific app
    public func loadDocs(appName: String) throws -> [ProcessedPage] {
        // Try multiple possible paths
        var url: URL?
        
        // First, try the module bundle (where JSON files are bundled)
        // Try in module bundle's Resources/{appName}/docs.json
        if let foundURL = moduleBundle.url(forResource: "docs", withExtension: "json", subdirectory: appName) {
            url = foundURL
        }
        // Try in module bundle's Resources/{appName}/docs.json (direct)
        else if let foundURL = moduleBundle.url(forResource: "\(appName)/docs", withExtension: "json") {
            url = foundURL
        }
        
        // Fallback to main bundle (for apps that copy files themselves)
        if url == nil {
            // Try DocsData subdirectory first (folder reference structure)
            if let foundURL = bundle.url(forResource: "docs", withExtension: "json", subdirectory: "DocsData/\(appName)") {
                url = foundURL
            }
            // Try direct app name subdirectory
            else if let foundURL = bundle.url(forResource: "docs", withExtension: "json", subdirectory: appName) {
                url = foundURL
            }
            // Try other patterns
            else if let foundURL = bundle.url(forResource: "\(appName)/docs", withExtension: "json") {
                url = foundURL
            }
            else if let foundURL = bundle.url(forResource: "docs/\(appName)", withExtension: "json") {
                url = foundURL
            }
            else if let foundURL = bundle.url(forResource: appName, withExtension: "json") {
                url = foundURL
            }
        }
        
        guard let url = url else {
            throw DocsLoaderError.fileNotFound("docs.json for \(appName). Expected at: \(appName)/docs.json in bundle. The JSON files should be bundled in EntityDocsSwift module, or copied to your app's bundle resources.")
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DocsLoaderError.invalidData("Failed to read docs.json for \(appName) at \(url.path): \(error.localizedDescription)")
        }
        
        guard !data.isEmpty else {
            throw DocsLoaderError.invalidData("docs.json for \(appName) is empty at \(url.path)")
        }
        
        let decoder = JSONDecoder()
        let pages: [ProcessedPage]
        do {
            pages = try decoder.decode([ProcessedPage].self, from: data)
        } catch {
            throw DocsLoaderError.decodingError(error)
        }
        return pages
    }
    
    /// Load changelog for a specific app
    public func loadChangelog(appName: String) throws -> [ProcessedPage] {
        // Try multiple possible paths
        var url: URL?
        
        // First, try the module bundle (where JSON files are bundled)
        // Try in module bundle's Resources/{appName}/changelog.json
        if let foundURL = moduleBundle.url(forResource: "changelog", withExtension: "json", subdirectory: appName) {
            url = foundURL
        }
        // Try in module bundle's Resources/{appName}/changelog.json (direct)
        else if let foundURL = moduleBundle.url(forResource: "\(appName)/changelog", withExtension: "json") {
            url = foundURL
        }
        
        // Fallback to main bundle (for apps that copy files themselves)
        if url == nil {
            // Try DocsData subdirectory first (folder reference structure)
            if let foundURL = bundle.url(forResource: "changelog", withExtension: "json", subdirectory: "DocsData/\(appName)") {
                url = foundURL
            }
            // Try direct app name subdirectory
            else if let foundURL = bundle.url(forResource: "changelog", withExtension: "json", subdirectory: appName) {
                url = foundURL
            }
            // Try other patterns
            else if let foundURL = bundle.url(forResource: "\(appName)/changelog", withExtension: "json") {
                url = foundURL
            }
            else if let foundURL = bundle.url(forResource: "changelog/\(appName)", withExtension: "json") {
                url = foundURL
            }
            else if let foundURL = bundle.url(forResource: "\(appName)-changelog", withExtension: "json") {
                url = foundURL
            }
        }
        
        guard let url = url else {
            throw DocsLoaderError.fileNotFound("changelog.json for \(appName). Expected at: \(appName)/changelog.json in bundle. The JSON files should be bundled in EntityDocsSwift module, or copied to your app's bundle resources.")
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DocsLoaderError.invalidData("Failed to read changelog.json for \(appName) at \(url.path): \(error.localizedDescription)")
        }
        
        guard !data.isEmpty else {
            throw DocsLoaderError.invalidData("changelog.json for \(appName) is empty at \(url.path)")
        }
        
        let decoder = JSONDecoder()
        let pages: [ProcessedPage]
        do {
            pages = try decoder.decode([ProcessedPage].self, from: data)
        } catch {
            throw DocsLoaderError.decodingError(error)
        }
        
        // Filter out "unreleased" entries - they're internal/private only
        // Similar to how web version filters them out
        let filteredPages = pages.filter { page in
            // Check if slug is "unreleased" or if title/version contains "unreleased"
            let slugString = page.slug.joined(separator: "/")
            if slugString == "unreleased" || slugString.contains("unreleased") {
                return false
            }
            // Also check frontmatter for version or title
            if let frontmatter = page.frontmatter {
                if let version = frontmatter.version,
                   version.lowercased() == "unreleased" {
                    return false
                }
                if let title = frontmatter.title,
                   title.lowercased() == "unreleased" {
                    return false
                }
            }
            return true
        }
        
        return filteredPages
    }
    
    /// Load a specific page by slug
    public func loadPage(appName: String, slug: [String], isChangelog: Bool = false) throws -> ProcessedPage? {
        // Block access to "unreleased" changelog entries
        if isChangelog && slug == ["unreleased"] {
            return nil
        }
        
        let pages = isChangelog ? try loadChangelog(appName: appName) : try loadDocs(appName: appName)
        return pages.first { $0.slug == slug }
    }
    
    /// Get all pages for navigation
    public func getAllPages(appName: String) throws -> (docs: [ProcessedPage], changelog: [ProcessedPage]) {
        let docs = try loadDocs(appName: appName)
        let changelog = try loadChangelog(appName: appName)
        return (docs, changelog)
    }
}

