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
    ) throws -> SecureByteArray {
        let hasPassword = !passwordData.isEmpty
        let hasKeyFile = !keyFileData.isEmpty
        
        var preKey = SecureByteArray()
        if hasPassword {
            Diag.info("Using password")
            preKey = SecureByteArray.concat(preKey, passwordData.sha256)
        }
        if hasKeyFile {
            Diag.info("Using key file")
            preKey = SecureByteArray.concat(
                preKey,
                try processKeyFile(keyFileData: keyFileData) 
            )
        }
        if preKey.isEmpty {
            Diag.warning("All key components are empty after being checked.")
        }
        return preKey 
    }
    
    override func getKey(fromCombinedComponents combinedComponents: SecureByteArray) -> SecureByteArray {
        return combinedComponents.sha256
    }
    
    internal override func processXmlKeyFile(keyFileData: ByteArray) throws -> SecureByteArray? {
        let xml: AEXMLDocument
        do {
            xml = try AEXMLDocument(xml: keyFileData.asData)
        } catch {
            return nil
        }
        
        let versionElement = xml[Xml2.keyFile][Xml2.meta][Xml2.version]
        if versionElement.error != nil {
            return nil
        }
        guard let version = versionElement.value else {
            Diag.warning("Missing version in XML key file")
            return nil
        }
        guard let majorVersionString = version.split(separator: ".").first,
              let majorVersion = Int(majorVersionString) else {
            Diag.warning("Misformatted key file version [version: \(version)]")
            return nil
        }

        switch majorVersion {
        case 2:
            let result = try processXMLFileVersion2(xml) 
            return result
        case 1:
            let result = try processXMLFileVersion1(xml) 
            return result
        default:
            Diag.error("Unsupported XML key file format [version: \(version)]")
            throw KeyFileError.unsupportedFormat
        }
    }
    
    private func processXMLFileVersion1(_ xml: AEXMLDocument) throws -> SecureByteArray? {
        guard let base64 = xml[Xml2.keyFile][Xml2.key][Xml2.data].value else {
            Diag.warning("Empty Base64 value")
            return nil
        }
        guard let keyData = ByteArray(base64Encoded: base64) else {
            Diag.error("Invalid Base64 string")
            throw KeyFileError.keyFileCorrupted
        }
        return SecureByteArray(keyData)
    }
    
    private func processXMLFileVersion2(_ xml: AEXMLDocument) throws -> SecureByteArray? {
        let rawHexString = xml[Xml2.keyFile][Xml2.key][Xml2.data].value
        guard let hexString = rawHexString?.filter({ !$0.isWhitespace }),
              hexString.isNotEmpty
        else {
            Diag.warning("Empty key data")
            throw KeyFileError.keyFileCorrupted
        }
        
        guard let keyData = ByteArray(hexString: hexString) else {
            Diag.error("Invalid hex string")
            throw KeyFileError.keyFileCorrupted
        }
        
        if let hashString = xml[Xml2.keyFile][Xml2.key][Xml2.data].attributes[Xml2.hash] {
            guard let hashData = ByteArray(hexString: hashString) else {
                Diag.error("Invalid hash hex string")
                throw KeyFileError.keyFileCorrupted
            }
            guard keyData.sha256.prefix(4) == hashData else {
                Diag.error("Hash verification failed")
                throw KeyFileError.keyFileCorrupted
            }
        }
        return SecureByteArray(keyData)
    }
}
