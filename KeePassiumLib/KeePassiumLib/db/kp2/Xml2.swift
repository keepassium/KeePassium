//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

internal struct Xml2 {
    enum ParsingError: LocalizedError {
        case xmlError(details: String) 
        case notKeePassDocument
        case unexpectedTag(actual: String, expected: String?)
        case malformedValue(tag: String, value: String?)
        
        public var errorDescription: String? {
            switch self {
            case .xmlError(let details):
                return NSLocalizedString("XML error: \(details)", comment: "Generic error while parsing XML")
            case .notKeePassDocument:
                return NSLocalizedString("Not a KeePass XML", comment: "Error message about XML parsing")
            case .unexpectedTag(let actual, let expected):
                if let expected = expected {
                    return NSLocalizedString("Unexpected tag '\(actual)' (instead of '\(expected)')", comment: "Error message about XML parsing")
                } else {
                    return NSLocalizedString("Unexpected tag '\(actual)'", comment: "Error message about XML parsing")
                }
            case .malformedValue(let tag, let value):
                if let value = value {
                    return NSLocalizedString("Malformed value '\(value)' in \(tag)", comment: "Error message about XML parsing")
                } else {
                    return NSLocalizedString("Nil value in \(tag)", comment: "Error message about XML parsing")
                }
            }
        }
    } 
    
    static let meta = "Meta"
    static let root = "Root"
    static let group = "Group"
    static let entry = "Entry"
    
    static let keePassFile = "KeePassFile"
    static let generator = "Generator"
    static let settingsChanged = "SettingsChanged"
    static let headerHash = "HeaderHash"
    static let databaseName = "DatabaseName"
    static let databaseNameChanged = "DatabaseNameChanged"
    static let databaseDescription = "DatabaseDescription"
    static let databaseDescriptionChanged = "DatabaseDescriptionChanged"
    static let defaultUserName = "DefaultUserName"
    static let defaultUserNameChanged = "DefaultUserNameChanged"
    static let maintenanceHistoryDays = "MaintenanceHistoryDays"
    static let color = "Color"
    static let masterKeyChanged = "MasterKeyChanged"
    static let masterKeyChangeRec = "MasterKeyChangeRec"
    static let masterKeyChangeForce = "MasterKeyChangeForce"
    static let memoryProtection = "MemoryProtection"
    static let protectTitle = "ProtectTitle"
    static let protectUserName = "ProtectUserName"
    static let protectPassword = "ProtectPassword"
    static let protectURL = "ProtectURL"
    static let protectNotes = "ProtectNotes"
    static let recycleBinEnabled = "RecycleBinEnabled"
    static let recycleBinUUID = "RecycleBinUUID"
    static let recycleBinChanged = "RecycleBinChanged"
    static let entryTemplatesGroup = "EntryTemplatesGroup"
    static let entryTemplatesGroupChanged = "EntryTemplatesGroupChanged"
    static let historyMaxItems = "HistoryMaxItems"
    static let historyMaxSize = "HistoryMaxSize"
    static let lastSelectedGroup = "LastSelectedGroup"
    static let lastTopVisibleGroup = "LastTopVisibleGroup"
    static let customIcons = "CustomIcons"
    static let icon = "Icon"
    static let data = "Data"
    static let binaries = "Binaries"
    static let id = "ID"
    static let compressed = "Compressed"
    static let customData = "CustomData"
    static let item = "Item"
    static let binary = "Binary"
    
    static let uuid = "UUID"
    static let name = "Name"
    static let notes = "Notes"
    static let iconID = "IconID"
    static let customIconUUID = "CustomIconUUID"
    static let string = "String"
    static let history = "History"
    static let key = "Key"
    static let value = "Value"
    static let protected = "Protected"
    static let ref = "Ref"
    
    static let isExpanded = "IsExpanded"
    static let defaultAutoTypeSequence = "DefaultAutoTypeSequence" 
    static let enableAutoType = "EnableAutoType"
    static let enableSearching = "EnableSearching"
    static let lastTopVisibleEntry = "LastTopVisibleEntry"
    static let usageCount = "UsageCount"
    static let locationChanged = "LocationChanged"
    static let foregroundColor = "ForegroundColor"
    static let backgroundColor = "BackgroundColor"
    static let overrideURL = "OverrideURL"
    static let tags = "Tags"
    
    static let autoType = "AutoType"
    static let enabled = "Enabled"
    static let dataTransferObfuscation = "DataTransferObfuscation"
    static let defaultSequence = "DefaultSequence" 
    static let association = "Association"
    static let window = "Window"
    static let keystrokeSequence = "KeystrokeSequence"
    
    static let times = "Times"
    static let lastModificationTime = "LastModificationTime"
    static let creationTime = "CreationTime"
    static let lastAccessTime = "LastAccessTime"
    static let expiryTime = "ExpiryTime"
    static let expires = "Expires"
    
    static let deletedObjects = "DeletedObjects"
    static let deletedObject = "DeletedObject"
    static let deletionTime = "DeletionTime"
    
    static let keyFile = "KeyFile"
    static let version = "Version"

    static let _true = "True"
    static let _false = "False"
    static let null = "null" 
}
