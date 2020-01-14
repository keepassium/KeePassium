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
    public private(set) var masterKey: SecureByteArray?
    public var hasMasterKey: Bool { return masterKey != nil }
    
    public var isRememberKeyFile: Bool?
    public private(set) var associatedKeyFile: URLReference?

    private enum CodingKeys: String, CodingKey {
        case databaseRef
        case accessMode
        case isRememberMasterKey
        case masterKey
        case isRememberKeyFile
        case associatedKeyFile
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

    public func setMasterKey(_ key: SecureByteArray) {
        masterKey = key.secureClone()
    }
    
    public func maybeSetMasterKey(_ key: SecureByteArray) {
        if isRememberKeyFile ?? Settings.current.isRememberDatabaseKey {
            setMasterKey(key)
        }
    }

    public func clearMasterKey() {
        masterKey?.erase()
        masterKey = nil
    }

    public func setAssociatedKeyFile(_ urlRef: URLReference?) {
        associatedKeyFile = urlRef
    }
    
    public func maybeSetAssociatedKeyFile(_ urlRef: URLReference?) {
        if isRememberKeyFile ?? Settings.current.isKeepKeyFileAssociations {
            setAssociatedKeyFile(urlRef)
        }
    }
}

