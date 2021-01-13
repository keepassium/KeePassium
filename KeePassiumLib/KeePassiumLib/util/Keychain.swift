//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum KeychainError: LocalizedError {
    case generic(code: Int)
    case unexpectedFormat
    
    public var errorDescription: String? {
        switch self {
        case .generic(let code):
            return String.localizedStringWithFormat(
                NSLocalizedString(
                    "[KeychainError/generic] Keychain error (code %d) ",
                    bundle: Bundle.framework,
                    value: "Keychain error (code %d) ",
                    comment: "Generic error message about system keychain. [errorCode: Int]"),
                code)
        case .unexpectedFormat:
            return NSLocalizedString(
                "[KeychainError/unexpectedFormat] Keychain error: unexpected data format",
                bundle: Bundle.framework,
                value: "Keychain error: unexpected data format",
                comment: "Error message about system keychain.")
        }
    }
}

public class Keychain {
    public static let shared = Keychain()
    
    private static let accessGroup: String? = nil
    private enum Service: String {
        static let allValues: [Service] = [.general, .databaseKeys, databaseSettings, .premium]
        
        case general = "KeePassium"
        case databaseKeys = "KeePassium.dbKeys"
        case databaseSettings = "KeePassium.dbSettings"
        case premium = "KeePassium.premium"
    }
    private let appPasscodeAccount = "appPasscode"
    private let premiumExpiryDateAccount = "premiumExpiryDate"
    private let premiumProductAccount = "premiumProductID"
    private let premiumFallbackDateAccount = "premiumFallbackDate"
    
    private init() {
        cleanupObsoleteKeys()
    }
    
    private func cleanupObsoleteKeys() {
        try? remove(service: .databaseKeys, account: nil)
    }
    
    
    private func makeQuery(service: Service, account: String?) -> [String: AnyObject] {
        var result = [String: AnyObject]()
        result[kSecClass as String] = kSecClassGenericPassword
        result[kSecAttrService as String] = service.rawValue as AnyObject?
        if let account = account {
            result[kSecAttrAccount as String] = account as AnyObject?
        }
        if let accessGroup = Keychain.accessGroup {
            result[kSecAttrAccessGroup as String] = accessGroup as AnyObject?
        }
        return result
    }
    
    private func get(service: Service, account: String) throws -> Data? {
        var query = makeQuery(service: service, account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = kCFBooleanTrue
        query[kSecReturnData as String] = kCFBooleanTrue
        
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) { ptr in
            return SecItemCopyMatching(query as CFDictionary, ptr)
        }
        if status == errSecItemNotFound {
            return nil
        }
        guard status == noErr else {
            Diag.error("Keychain error [code: \(Int(status))]")
            throw KeychainError.generic(code: Int(status))
        }
        
        guard let item = queryResult as? [String: AnyObject],
              let data = item[kSecValueData as String] as? Data else
        {
            Diag.error("Keychain error: unexpected format")
            throw KeychainError.unexpectedFormat
        }
        return data
    }
    
    private func set(service: Service, account: String, data: Data) throws {
        if let _ = try get(service: service, account: account) { 
            let query = makeQuery(service: service, account: account)
            let attrsToUpdate = [kSecValueData as String : data as AnyObject?]
            let status = SecItemUpdate(query as CFDictionary, attrsToUpdate as CFDictionary)
            if status != noErr {
                Diag.error("Keychain error [code: \(Int(status))]")
                throw KeychainError.generic(code: Int(status))
            }
        } else {
            var newItem = makeQuery(service: service, account: account)
            newItem[kSecValueData as String] = data as AnyObject?
            let status = SecItemAdd(newItem as CFDictionary, nil)
            if status != noErr {
                Diag.error("Keychain error [code: \(Int(status))]")
                throw KeychainError.generic(code: Int(status))
            }
        }
    }
    
    private func remove(service: Service, account: String?) throws {
        let query = makeQuery(service: service, account: account)
        let status = SecItemDelete(query as CFDictionary)
        if status != noErr && status != errSecItemNotFound {
            Diag.error("Keychain error [code: \(Int(status))]")
            throw KeychainError.generic(code: Int(status))
        }
    }
    
    public func removeAll() throws {
        for service in Service.allValues {
            try remove(service: service, account: nil) 
        }
    }

    
    public func setAppPasscode(_ passcode: String) throws {
        let dataHash = ByteArray(utf8String: passcode).sha256.asData
        try set(service: .general, account: appPasscodeAccount, data: dataHash) 
        Settings.current.notifyAppLockEnabledChanged()
    }

    public func isAppPasscodeSet() throws -> Bool {
        let storedHash = try get(service: .general, account: appPasscodeAccount) 
        return storedHash != nil
    }
    
    public func isAppPasscodeMatch(_ passcode: String) throws -> Bool {
        guard let storedHash =
            try get(service: .general, account: appPasscodeAccount) else
        {
            return false
        }
        let passcodeHash = ByteArray(utf8String: passcode).sha256.asData
        return passcodeHash == storedHash
    }

    public func removeAppPasscode() throws {
        try remove(service: .general, account: appPasscodeAccount) 
        Settings.current.notifyAppLockEnabledChanged()
    }
    
    
    internal func getDatabaseSettings(
        for descriptor: URLReference.Descriptor) throws
        -> DatabaseSettings?
    {
        if let data = try get(service: .databaseSettings, account: descriptor) { 
            return DatabaseSettings.deserialize(from: data)
        }
        return nil
    }
    
    internal func setDatabaseSettings(
        _ dbSettings: DatabaseSettings,
        for descriptor: URLReference.Descriptor
    ) throws {
        let data = dbSettings.serialize()
        try set(service: .databaseSettings, account: descriptor, data: data)
    }
    
    internal func removeDatabaseSettings(for descriptor: URLReference.Descriptor) throws {
        try remove(service: .databaseSettings, account: descriptor) 
    }
    
    
    
    public func setPremiumExpiry(for product: InAppProduct, to expiryDate: Date) throws {
        let timestampBytes = UInt64(expiryDate.timeIntervalSinceReferenceDate).data
        let productID = product.rawValue.dataUsingUTF8StringEncoding
        try set(service: .premium, account: premiumProductAccount, data: productID)
        try set(service: .premium, account: premiumExpiryDateAccount, data: timestampBytes.asData)
    }
    
    #if DEBUG
    public func clearPremiumExpiryDate() throws {
        try remove(service: .premium, account: premiumExpiryDateAccount)
    }
    #endif
    
    public func getPremiumExpiryDate() throws -> Date? {
        guard let data = try get(service: .premium, account: premiumExpiryDateAccount) else {
            return nil
        }
        guard let timestamp = UInt64(data: ByteArray(data: data)) else {
            assertionFailure()
            return nil
        }
        return Date(timeIntervalSinceReferenceDate: Double(timestamp))
    }
    
    public func getPremiumProduct() throws -> InAppProduct? {
        guard let data = try get(service: .premium, account: premiumProductAccount),
            let productIDString = String(data: data, encoding: .utf8) else { return nil }
        guard let product = InAppProduct(rawValue: productIDString) else { return nil }
        return product
    }
    
    internal func setPremiumFallbackDate(_ date: Date?) throws {
        guard let date = date else {
            try remove(service: .premium, account: premiumFallbackDateAccount)
            return
        }

        let timestampBytes = UInt64(date.timeIntervalSinceReferenceDate).data
        try set(service: .premium, account: premiumFallbackDateAccount, data: timestampBytes.asData)
    }
    
    internal func getPremiumFallbackDate() throws -> Date? {
        guard let data = try get(service: .premium, account: premiumFallbackDateAccount) else {
            return nil
        }
        guard let timestamp = UInt64(data: ByteArray(data: data)) else {
            assertionFailure()
            return nil
        }
        return Date(timeIntervalSinceReferenceDate: Double(timestamp))
    }
}
