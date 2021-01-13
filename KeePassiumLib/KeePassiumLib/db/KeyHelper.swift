//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class KeyHelper {
    public static let compositeKeyLength = 32
    internal let keyFileKeyLength = 32
    
    public func combineComponents(
        passwordData: SecureByteArray,
        keyFileData: ByteArray
    ) throws -> SecureByteArray {
        fatalError("Pure virtual method")
    }
    
    public func getKey(fromCombinedComponents combinedComponents: SecureByteArray) -> SecureByteArray {
        fatalError("Pure virtual method")
    }
    
    public func getPasswordData(password: String) -> SecureByteArray {
        fatalError("Pure virtual method")
    }
    
    public func processKeyFile(keyFileData: ByteArray) throws -> SecureByteArray {
        assert(!keyFileData.isEmpty, "keyFileData cannot be empty here")

        if keyFileData.count == keyFileKeyLength {
            Diag.debug("Key file format is: binary")
            return SecureByteArray(keyFileData)
        } else if keyFileData.count == 2 * keyFileKeyLength {
            let hexString = keyFileData.toString(using: .ascii)
            if let hexString = hexString {
                if let key = ByteArray(hexString: hexString) {
                    Diag.debug("Key file format is: base64")
                    return SecureByteArray(key)
                }
            }
        }
        
        if let key = try processXmlKeyFile(keyFileData: keyFileData) {
            Diag.debug("Key file format is: XML")
            return key
        }
        
        Diag.debug("Key file format is: other")
        return SecureByteArray(keyFileData.sha256)
    }
    
    public func processXmlKeyFile(keyFileData: ByteArray) throws -> SecureByteArray? {
        return nil
    }
}


