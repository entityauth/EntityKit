import Foundation

public func normalizeUsername(_ raw: String) -> String {
	let lower = raw.lowercased()
	let trimmed = lower.trimmingCharacters(in: .whitespacesAndNewlines)
	// Replace whitespace with dashes
	var result = trimmed.replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
	// Replace non [a-z0-9._-] with dash
	result = result.replacingOccurrences(of: "[^a-z0-9._-]", with: "-", options: .regularExpression)
	// Collapse sequences of [-_.] to single '-'
	result = result.replacingOccurrences(of: "[-_.]{2,}", with: "-", options: .regularExpression)
	// Trim leading/trailing . _ -
	result = result.replacingOccurrences(of: "^[._-]+|[._-]+$", with: "", options: .regularExpression)
	return result
}
