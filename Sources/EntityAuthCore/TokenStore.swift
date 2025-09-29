import Foundation
import Security

public protocol TokenStoring: Sendable {
    func loadAccessToken() throws -> String?
    func loadRefreshToken() throws -> String?
    func save(accessToken: String?) throws
    func save(refreshToken: String?) throws
    func clear() throws
}

public struct KeychainTokenStore: TokenStoring {
    private let accessKey = "com.entityauth.accessToken"
    private let refreshKey = "com.entityauth.refreshToken"

    public init() {}

    public func loadAccessToken() throws -> String? {
        try keychainGet(accessKey)
    }

    public func loadRefreshToken() throws -> String? {
        try keychainGet(refreshKey)
    }

    public func save(accessToken: String?) throws {
        if let accessToken {
            try keychainSet(accessKey, value: accessToken)
        } else {
            try keychainDelete(accessKey)
        }
    }

    public func save(refreshToken: String?) throws {
        if let refreshToken {
            try keychainSet(refreshKey, value: refreshToken)
        } else {
            try keychainDelete(refreshKey)
        }
    }

    public func clear() throws {
        try keychainDelete(accessKey)
        try keychainDelete(refreshKey)
    }
}

private func keychainSet(_ key: String, value: String) throws {
    guard let data = value.data(using: .utf8) else {
        throw EntityAuthError.storage("Unable to encode token")
    }
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data
    ]
    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw EntityAuthError.keychain(status)
    }
}

private func keychainGet(_ key: String) throws -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: kCFBooleanTrue as Any,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
        return nil
    }
    guard status == errSecSuccess else {
        throw EntityAuthError.keychain(status)
    }
    guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
        throw EntityAuthError.storage("Unable to decode token")
    }
    return string
}

private func keychainDelete(_ key: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
        throw EntityAuthError.keychain(status)
    }
}
