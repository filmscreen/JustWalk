//
//  KeychainManager.swift
//  JustWalk
//
//  Secure storage that persists across app reinstalls
//  Used to prevent gaming of shield system via delete/reinstall
//

import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "onworldtech.JustWalk"

    private init() {}

    // MARK: - Shield Gaming Prevention

    private let initialShieldsGrantedKey = "initialShieldsGranted"

    /// Returns true if the user has already received their initial shields (survives reinstall)
    var hasReceivedInitialShields: Bool {
        return getBool(forKey: initialShieldsGrantedKey) ?? false
    }

    /// Mark that the user has received their initial shields
    func markInitialShieldsGranted() {
        setBool(true, forKey: initialShieldsGrantedKey)
    }

    // MARK: - Generic Keychain Operations

    private func setBool(_ value: Bool, forKey key: String) {
        let data = Data([value ? 1 : 0])
        set(data, forKey: key)
    }

    private func getBool(forKey key: String) -> Bool? {
        guard let data = get(forKey: key), let firstByte = data.first else {
            return nil
        }
        return firstByte == 1
    }

    private func set(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        SecItemAdd(newQuery as CFDictionary, nil)
    }

    private func get(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    // MARK: - Debug

    /// Clears the initial shields flag (for testing only)
    func resetInitialShieldsFlag() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: initialShieldsGrantedKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
