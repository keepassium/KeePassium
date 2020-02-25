//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final class KeyHelper2: KeyHelper {
    
    override init() {
        super.init()
    }
    
    override func getPasswordData(password: String) -> SecureByteArray {
        return SecureByteArray(data: Data(password.utf8))
    }
    
    override func combineComponents(
        passwordData: SecureByteArray,
        keyFileData: ByteArray
    ) -> SecureByteArray {
        let hasPassword = !passwordData.isEmpty
        let hasKeyFile = !keyFileData.isEmpty
        
        precondition(hasPassword || hasKeyFile)
        
        var preKey = SecureByteArray()
        if hasPassword {
            Diag.info("Using password")
            preKey = SecureByteArray.concat(preKey, passwordData.sha256)
        }
        if hasKeyFile {
            Diag.info("Using key file")
            preKey = SecureByteArray.concat(
                preKey,
                processKeyFile(keyFileData: keyFileData)
            )
        }
        if preKey.isEmpty {
            fatalError("All key components are empty after being checked.")
        }
        return preKey 
    }
    
    override func getKey(fromCombinedComponents combinedComponents: SecureByteArray) -> SecureByteArray {
        return combinedComponents.sha256
    }
    
    internal override func processXmlKeyFile(keyFileData: ByteArray) -> SecureByteArray? {
        do {
            let xml = try AEXMLDocument(xml: keyFileData.asData)
            let base64 = xml[Xml2.keyFile][Xml2.key][Xml2.data].value
            guard let out = ByteArray(base64Encoded: base64) else {
                return nil
            }
            return SecureByteArray(out)
        } catch {
            return nil
        }
    }
}
