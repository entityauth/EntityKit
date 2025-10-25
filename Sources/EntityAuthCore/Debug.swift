import Foundation

public enum EntityAuthDebugLog {
    public static let enabled: Bool = true
    public static func log(_ items: Any...) {
        guard enabled else { return }
        print("[EntityAuth]", items.map { String(describing: $0) }.joined(separator: " "))
    }
}


