//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final public class DatabaseSettings: Eraseable {
    public var isReadOnlyFile: Bool = false

    public var isRememberMasterKey: Bool?
    public var isRememberFinalKey: Bool?
    public private(set) var masterKey: CompositeKey?
    public var hasMasterKey: Bool { return masterKey != nil }

    public var isRememberKeyFile: Bool?
    public private(set) var associatedKeyFile: URLReference?

    public var isRememberHardwareKey: Bool?
    public private(set) var associatedYubiKey: YubiKey?

    public var isQuickTypeEnabled: Bool?

    public var fallbackStrategy: UnreachableFileFallbackStrategy?
    public var fallbackTimeout: TimeInterval?
    public var autofillFallbackStrategy: UnreachableFileFallbackStrategy?
    public var autofillFallbackTimeout: TimeInterval?

    public var externalUpdateBehavior: ExternalUpdateBehavior?

    init() {
        isReadOnlyFile = false
    }

    deinit {
        erase()
    }

    public func erase() {
        self.isReadOnlyFile = false

        isRememberMasterKey = nil
        isRememberFinalKey = nil
        clearMasterKey()

        isRememberKeyFile = nil
        associatedKeyFile = nil

        isRememberHardwareKey = nil
        associatedYubiKey = nil

        isQuickTypeEnabled = nil

        fallbackStrategy = nil
        fallbackTimeout = nil
        autofillFallbackStrategy = nil
        autofillFallbackTimeout = nil

        externalUpdateBehavior = nil
    }

    public func setMasterKey(_ key: CompositeKey) {
        masterKey = key.clone()
        let isKeepFinalKey = self.isRememberFinalKey ?? Settings.current.isRememberDatabaseFinalKey
        if !isKeepFinalKey {
            masterKey?.eraseFinalKeys()
        }
    }

    public func maybeSetMasterKey(of database: Database) {
        maybeSetMasterKey(database.compositeKey)
    }

    public func maybeSetMasterKey(_ key: CompositeKey) {
        guard isRememberMasterKey ?? Settings.current.isRememberDatabaseKey else { return }
        guard key.state >= .combinedComponents else { return }
        setMasterKey(key)
    }

    public func clearMasterKey() {
        masterKey?.erase()
        masterKey = nil
    }

    public func clearFinalKey() {
        masterKey?.eraseFinalKeys()
    }

    public func setAssociatedKeyFile(_ urlRef: URLReference?) {
        associatedKeyFile = urlRef
    }

    public func maybeSetAssociatedKeyFile(_ urlRef: URLReference?) {
        if isRememberKeyFile ?? Settings.current.isKeepKeyFileAssociations {
            setAssociatedKeyFile(urlRef)
        } else {
            setAssociatedKeyFile(nil)
        }
    }

    public func setAssociatedYubiKey(_ yubiKey: YubiKey?) {
        associatedYubiKey = yubiKey
    }

    public func maybeSetAssociatedYubiKey(_ yubiKey: YubiKey?) {
        if isRememberHardwareKey ?? Settings.current.isKeepHardwareKeyAssociations {
            setAssociatedYubiKey(yubiKey)
        } else {
            setAssociatedYubiKey(nil)
        }
    }
}


extension DatabaseSettings: Codable {

    private enum CodingKeys: String, CodingKey {
        case isReadOnlyFile
        case isRememberMasterKey
        case isRememberFinalKey
        case masterKey
        case isRememberKeyFile
        case associatedKeyFile
        case isRememberHardwareKey
        case associatedYubiKey
        case isQuickTypeEnabled
        case fallbackStrategy
        case fallbackTimeout
        case autofillFallbackStrategy
        case autofillFallbackTimeout
        case externalUpdateBehavior
    }

    internal func serialize() -> Data {
        let encoder = JSONEncoder()
        let encodedData = try! encoder.encode(self)
        return encodedData
    }

    internal static func deserialize(from data: Data?) -> DatabaseSettings? {
        guard let data = data else { return nil }
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(DatabaseSettings.self, from: data)
            return result
        } catch {
            Diag.error("Failed to parse DB settings, ignoring [message: \(error.localizedDescription)]")
            return nil
        }
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        // swiftlint:disable line_length
        self.isReadOnlyFile = try container.decodeIfPresent(Bool.self, forKey: .isReadOnlyFile) ?? false
        self.isRememberMasterKey = try container.decodeIfPresent(Bool.self, forKey: .isRememberMasterKey)
        self.isRememberFinalKey = try container.decodeIfPresent(Bool.self, forKey: .isRememberFinalKey)
        self.masterKey = try container.decodeIfPresent(CompositeKey.self, forKey: .masterKey)
        self.isRememberKeyFile = try container.decodeIfPresent(Bool.self, forKey: .isRememberKeyFile)
        self.associatedKeyFile = try container.decodeIfPresent(URLReference.self, forKey: .associatedKeyFile)
        self.isRememberHardwareKey = try container.decodeIfPresent(Bool.self, forKey: .isRememberHardwareKey)
        self.associatedYubiKey = try container.decodeIfPresent(YubiKey.self, forKey: .associatedYubiKey)
        self.isQuickTypeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isQuickTypeEnabled)
        self.fallbackStrategy = try container.decodeIfPresent(UnreachableFileFallbackStrategy.self, forKey: .fallbackStrategy)
        self.fallbackTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .fallbackTimeout)
        self.autofillFallbackStrategy = try container.decodeIfPresent(UnreachableFileFallbackStrategy.self, forKey: .autofillFallbackStrategy)
        self.autofillFallbackTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .autofillFallbackTimeout)
        self.externalUpdateBehavior = try container.decodeIfPresent(
            ExternalUpdateBehavior.self,
            forKey: .externalUpdateBehavior
        )
        // swiftlint:enable line_length
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isReadOnlyFile, forKey: .isReadOnlyFile)
        if let _isRememberMasterKey = isRememberMasterKey {
            try container.encode(_isRememberMasterKey, forKey: .isRememberMasterKey)
        }
        if let _isRememberFinalKey = isRememberFinalKey {
            try container.encode(_isRememberFinalKey, forKey: .isRememberFinalKey)
        }
        if let _masterKey = masterKey {
            try container.encode(_masterKey, forKey: .masterKey)
        }
        if let _isRememberKeyFile = isRememberKeyFile {
            try container.encode(_isRememberKeyFile, forKey: .isRememberKeyFile)
        }
        if let _associatedKeyFile = associatedKeyFile {
            try container.encode(_associatedKeyFile, forKey: .associatedKeyFile)
        }
        if let _isRememberHardwareKey = isRememberHardwareKey {
            try container.encode(_isRememberHardwareKey, forKey: .isRememberHardwareKey)
        }
        if let _associatedYubiKey = associatedYubiKey {
            try container.encode(_associatedYubiKey, forKey: .associatedYubiKey)
        }
        if let _isQuickTypeEnabled = isQuickTypeEnabled {
            try container.encode(_isQuickTypeEnabled, forKey: .isQuickTypeEnabled)
        }
        if let _fallbackStrategy = fallbackStrategy {
            try container.encode(_fallbackStrategy, forKey: .fallbackStrategy)
        }
        if let _fallbackTimeout = fallbackTimeout {
            try container.encode(_fallbackTimeout, forKey: .fallbackTimeout)
        }
        if let _autofillFallbackStrategy = autofillFallbackStrategy {
            try container.encode(_autofillFallbackStrategy, forKey: .autofillFallbackStrategy)
        }
        if let _autofillFallbackTimeout = autofillFallbackTimeout {
            try container.encode(_autofillFallbackTimeout, forKey: .autofillFallbackTimeout)
        }
        if let _externalUpdateBehavior = externalUpdateBehavior {
            try container.encode(_externalUpdateBehavior, forKey: .externalUpdateBehavior)
        }
    }
}
