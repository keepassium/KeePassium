//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.


public final class DatabaseLoadingWarnings {
    public enum IssueType {
        case unusedAttachments
        case missingBinaries(attachmentNames: [String])
        case namelessAttachments(entryNames: [String])
        case namelessCustomFields(entryPaths: [String])
        case databaseFileIsInTrash(fileName: String)
        case temporaryBackupDatabase
        case lesserTargetFormat
        
        public var priority: Int {
            switch self {
            case .namelessAttachments,
                 .namelessCustomFields:
                return 10
            case .unusedAttachments,
                 .missingBinaries:
                return 20
            case .temporaryBackupDatabase,
                 .lesserTargetFormat:
                return 30
            case .databaseFileIsInTrash:
                return 40
            }
        }
        
        fileprivate var isGeneratorBased: Bool {
            switch self {
            case .unusedAttachments,
                 .missingBinaries,
                 .namelessAttachments,
                 .namelessCustomFields:
                return true
            case .databaseFileIsInTrash,
                 .temporaryBackupDatabase,
                 .lesserTargetFormat:
                return false
            }
        }
        
        public var helpURL: URL? {
            switch self {
            case .databaseFileIsInTrash:
                return URL.AppHelp.databaseFileIsInTrashWarning
            case .temporaryBackupDatabase:
                return URL.AppHelp.temporaryBackupDatabaseWarning
            default:
                return nil
            }
        }
        
        internal var debugName: String {
            switch self {
            case .unusedAttachments:
                return "unusedAttachments"
            case .missingBinaries:
                return "missingBinaries"
            case .namelessAttachments:
                return "namelessAttachments"
            case .namelessCustomFields:
                return "namelessCustomFields"
            case .databaseFileIsInTrash:
                return "databaseFileIsInTrash"
            case .temporaryBackupDatabase:
                return "temporaryBackupDatabase"
            case .lesserTargetFormat:
                return "lesserTargetFormat"
            }
        }
        
        internal func getDescription(with databaseGenerator: String) -> String {
            switch self {
            case .unusedAttachments:
                return String.localizedStringWithFormat(
                    LString.Warning.unusedAttachmentsTemplate,
                    databaseGenerator)
            case .missingBinaries(let attachmentNames):
                let attachmentNamesFormatted = attachmentNames
                    .map { "\"\($0)\"" } 
                    .joined(separator: "\n ") 
                return String.localizedStringWithFormat(
                    LString.Warning.missingBinariesTemplate,
                    databaseGenerator,
                    attachmentNamesFormatted)
            case .namelessAttachments(let entryNames):
                let entryNamesFormatted = entryNames
                    .map { "\"\($0)\"" } 
                    .joined(separator: "\n ") 
                return String.localizedStringWithFormat(
                    LString.Warning.namelessAttachmentsTemplate,
                    entryNamesFormatted)
            case .namelessCustomFields(let entryPaths):
                let entryPathsJoined = entryPaths.joined(separator: "\n")
                return String.localizedStringWithFormat(
                    LString.Warning.namelessCustomFieldsTemplate,
                    entryPathsJoined)
            case .databaseFileIsInTrash(let fileName):
                return String.localizedStringWithFormat(
                    LString.Warning.fileIsInTrashTemplate,
                    fileName
                )
            case .temporaryBackupDatabase:
                return LString.Warning.temporaryBackupDatabase
            case .lesserTargetFormat:
                return LString.Warning.lesserTargetDatabaseFormat
            }
        }
    }
    
    public internal(set) var databaseGenerator: String?

    public private(set) var issues = [IssueType]()
    public var isEmpty: Bool { return issues.isEmpty }
    
    public var isGeneratorImportant: Bool {
        return issues.contains { $0.isGeneratorBased }
    }
    
    internal init() {
        databaseGenerator = nil
    }

    public func addIssue(_ issue: IssueType) {
        issues.append(issue)
    }
    
    public func getDescription(for issue: IssueType) -> String {
        return issue.getDescription(with: databaseGenerator ?? "")
    }
    
    public func getRedactedDescription() -> String {
        return issues.map({ $0.debugName}).joined(separator: ", ")
    }
    
    public func getHelpURL() -> URL? {
        let relevantHelpURLs = issues.compactMap { $0.helpURL }
        if relevantHelpURLs.count == 1 {
            return relevantHelpURLs.first!
        } else {
            return nil
        }
    }
}
