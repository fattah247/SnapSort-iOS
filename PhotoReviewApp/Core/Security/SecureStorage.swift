//
//  SecureStorage.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 05/02/25.
//
import Foundation
import Security
import OSLog

struct SecureStorage {
    static func store(key: String, data: Data) -> OSStatus {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete any existing item with the same key.
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil)
    }

    static func retrieve(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            return dataTypeRef as? Data
        } else {
            AppLogger.security.error("Error retrieving keychain item: OSStatus \(status, privacy: .public)")
            return nil
        }
    }
}


