//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class DatabaseSettings: Eraseable, Codable {

    public enum AccessMode: Int, Codable {
        static let `default`: AccessMode = .readWrite 
        
        case readWrite = 0
    }

    public let databaseRef: URLReference
    
    public var accessMode: AccessMode
    
    public var isRememberMasterKey: Bool?
    public var isRememberFinalKey: Bool?
    public private(set) var masterKey: CompositeKey?
    public var hasMasterKey: Bool { return masterKey != nil }
    
    public var isRememberKeyFile: Bool?
    public private(set) var associatedKeyFile: URLReference?
    
    public var isRememberHardwareKey: Bool?
    public private(set) var associatedYubiKey: YubiKey?

    private enum CodingKeys: String, CodingKey {
        case databaseRef
        case accessMode
        case isRememberMasterKey
        case isRememberFinalKey
        case masterKey
        case isRememberKeyFile
        case associatedKeyFile
        case isRememberHardwareKey
        case associatedYubiKey
    }
    
    init(for databaseRef: URLReference) {
        self.databaseRef = databaseRef
        accessMode = AccessMode.default
    }
    
    deinit {
        erase()
    }
    
    public func erase() {
        self.accessMode = AccessMode.default
        
        isRememberMasterKey = nil
        isRememberFinalKey = nil
        clearMasterKey()
        
        isRememberKeyFile = nil
        associatedKeyFile = nil
    }
    
    internal func serialize() -> Data {
        let encoder = JSONEncoder()
        let encodedData = try! encoder.encode(self)
        return encodedData
    }
    
    internal static func deserialize(from data: Data?) -> DatabaseSettings? {
        guard let data = data else { return nil }
        let decoder = JSONDecoder()
        let result = try? decoder.decode(DatabaseSettings.self, from: data)
        return result
    }

    public func setMasterKey(_ key: CompositeKey) {
        masterKey = key.clone()
        let isKeepFinalKey = self.isRememberFinalKey ?? Settings.current.isRememberDatabaseFinalKey
        if !isKeepFinalKey {
            masterKey?.eraseFinalKeys()
        }
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
        guard isRememberKeyFile ?? Settings.current.isKeepKeyFileAssociations else { return }
        setAssociatedKeyFile(urlRef)
    }

    public func setAssociatedYubiKey(_ yubiKey: YubiKey?) {
        associatedYubiKey = yubiKey
    }

    public func maybeSetAssociatedYubiKey(_ yubiKey: YubiKey?) {
        guard isRememberHardwareKey ?? Settings.current.isKeepHardwareKeyAssociations else { return }
        setAssociatedYubiKey(yubiKey)
    }
}

