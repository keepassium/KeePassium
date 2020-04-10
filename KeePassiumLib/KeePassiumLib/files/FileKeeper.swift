//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public enum FileKeeperError: LocalizedError {
    case openError(reason: String)
    case importError(reason: String)
    case removalError(reason: String)
    public var errorDescription: String? {
        switch self {
        case .openError(let reason):
            return String.localizedStringWithFormat(
                NSLocalizedString(
                    "[FileKeeper] Failed to open file. Reason: %@",
                    bundle: Bundle.framework,
                    value: "Failed to open file. Reason: %@",
                    comment: "Error message [reason: String]"),
                reason)
        case .importError(let reason):
            return String.localizedStringWithFormat(
                NSLocalizedString(
                    "[FileKeeper] Failed to import file. Reason: %@",
                    bundle: Bundle.framework,
                    value: "Failed to import file. Reason: %@",
                    comment: "Error message [reason: String]"),
                reason)
        case .removalError(let reason):
            return String.localizedStringWithFormat(
                NSLocalizedString(
                    "[FileKeeper] Failed to delete file. Reason: %@",
                    bundle: Bundle.framework,
                    value: "Failed to delete file. Reason: %@",
                    comment: "Error message [reason: String]"),
                reason)
        }
    }
}

public protocol FileKeeperDelegate: class {
    
    func shouldResolveImportConflict(
        target: URL,
        handler: @escaping (FileKeeper.ConflictResolution) -> Void
    )
}

public class FileKeeper {
    public static let shared = FileKeeper()
    
    public weak var delegate: FileKeeperDelegate?
    
    public enum ConflictResolution {
        case ask
        case abort
        case rename
        case overwrite
    }

    private enum UserDefaultsKey {
        static var mainAppPrefix: String {
            if BusinessModel.type == .prepaid {
                return "com.keepassium.pro.recentFiles"
            } else {
                return "com.keepassium.recentFiles"
            }
        }

        static var autoFillExtensionPrefix: String {
            if BusinessModel.type == .prepaid {
                return "com.keepassium.pro.autoFill.recentFiles"
            } else {
                return "com.keepassium.autoFill.recentFiles"
            }
        }
        
        static let internalDatabases = ".internal.databases"
        static let internalKeyFiles = ".internal.keyFiles"
        static let externalDatabases = ".external.databases"
        static let externalKeyFiles = ".external.keyFiles"
    }
    
    private static let documentsDirectoryName = "Documents"
    private static let inboxDirectoryName = "Inbox"
    private static let backupDirectoryName = "Backup"
    
    public enum OpenMode {
        case openInPlace
        case `import`
    }
    
    private var urlToOpen: URL?
    private var openMode: OpenMode = .openInPlace
    private var pendingOperationGroup = DispatchGroup()
    
    fileprivate let docDirURL: URL
    fileprivate let backupDirURL: URL
    fileprivate let inboxDirURL: URL
    
    public var hasPendingFileOperations: Bool {
        return urlToOpen != nil
    }

    private init() {
        docDirURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!  
            .standardizedFileURL
        inboxDirURL = docDirURL.appendingPathComponent(
            FileKeeper.inboxDirectoryName,
            isDirectory: true)
            .standardizedFileURL

        print("\nDoc dir: \(docDirURL)\n")
        
        guard let sharedContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.id) else { fatalError() }
        backupDirURL = sharedContainerURL.appendingPathComponent(
            FileKeeper.backupDirectoryName,
            isDirectory: true)
            .standardizedFileURL
        do {
            try FileManager.default.createDirectory(
                at: backupDirURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Diag.warning("Failed to create backup directory")
        }
        
        deleteExpiredBackupFiles()
    }

    fileprivate func getDirectory(for location: URLReference.Location) -> URL? {
        switch location {
        case .internalDocuments:
            return docDirURL
        case .internalBackup:
            return backupDirURL
        case .internalInbox:
            return inboxDirURL
        default:
            return nil
        }
    }
    
    public func getLocation(for filePath: URL) -> URLReference.Location {
        let path: String
        if filePath.isDirectory {
            path = filePath.standardizedFileURL.path
        } else {
            path = filePath.standardizedFileURL.deletingLastPathComponent().path
        }
        
        for candidateLocation in URLReference.Location.allInternal {
            guard let dirPath = getDirectory(for: candidateLocation)?.path else {
                assertionFailure()
                continue
            }
            if path == dirPath {
                return candidateLocation
            }
        }
        return .external
    }
    
    private func userDefaultsKey(for fileType: FileType, external isExternal: Bool) -> String {
        let keySuffix: String
        switch fileType {
        case .database:
            if isExternal {
                keySuffix = UserDefaultsKey.externalDatabases
            } else {
                keySuffix = UserDefaultsKey.internalDatabases
            }
        case .keyFile:
            if isExternal {
                keySuffix = UserDefaultsKey.externalKeyFiles
            } else {
                keySuffix = UserDefaultsKey.internalKeyFiles
            }
        }
        if AppGroup.isMainApp {
            return UserDefaultsKey.mainAppPrefix + keySuffix
        } else {
            return UserDefaultsKey.autoFillExtensionPrefix + keySuffix
        }
    }
    
    private func getStoredReferences(
        fileType: FileType,
        forExternalFiles isExternal: Bool
        ) -> [URLReference]
    {
        let key = userDefaultsKey(for: fileType, external: isExternal)
        guard let refsData = UserDefaults.appGroupShared.array(forKey: key) else {
            return []
        }
        var refs: [URLReference] = []
        for data in refsData {
            if let ref = URLReference.deserialize(from: data as! Data) {
                refs.append(ref)
            }
        }
        return refs
    }
    
    private func storeReferences(
        _ refs: [URLReference],
        fileType: FileType,
        forExternalFiles isExternal: Bool)
    {
        let serializedRefs = refs.map{ $0.serialize() }
        let key = userDefaultsKey(for: fileType, external: isExternal)
        UserDefaults.appGroupShared.set(serializedRefs, forKey: key)
    }

    private func findStoredExternalReferenceFor(url: URL, fileType: FileType) -> URLReference? {
        let storedRefs = getStoredReferences(fileType: fileType, forExternalFiles: true)
        for ref in storedRefs {
            if let refUrl = try? ref.resolve(), refUrl == url {
                return ref
            }
        }
        return nil
    }

    public func deleteFile(_ urlRef: URLReference, fileType: FileType, ignoreErrors: Bool) throws {
        Diag.debug("Will trash local file [fileType: \(fileType)]")
        do {
            let url = try urlRef.resolve()
            try FileManager.default.removeItem(at: url)
            Diag.info("Local file deleted")
            FileKeeperNotifier.notifyFileRemoved(urlRef: urlRef, fileType: fileType)
        } catch {
            if ignoreErrors {
                Diag.debug("Suppressed file deletion error [message: '\(error.localizedDescription)']")
            } else {
                Diag.error("Failed to delete file [message: '\(error.localizedDescription)']")
                throw FileKeeperError.removalError(reason: error.localizedDescription)
            }
        }

    }
    
    public func removeExternalReference(_ urlRef: URLReference, fileType: FileType) {
        Diag.debug("Removing URL reference [fileType: \(fileType)]")
        var refs = getStoredReferences(fileType: fileType, forExternalFiles: true)
        if let index = refs.index(of: urlRef) {
            refs.remove(at: index)
            storeReferences(refs, fileType: fileType, forExternalFiles: true)
            FileKeeperNotifier.notifyFileRemoved(urlRef: urlRef, fileType: fileType)
            Diag.info("URL reference removed successfully")
        } else {
            assertionFailure("Tried to delete non-existent reference")
            Diag.warning("Failed to remove URL reference - no such reference")
        }
    }
    
    public func getAllReferences(fileType: FileType, includeBackup: Bool) -> [URLReference] {
        var result: [URLReference] = []
        result.append(contentsOf:getStoredReferences(fileType: fileType, forExternalFiles: true))
        if AppGroup.isMainApp {
            let sandboxFileRefs = scanLocalDirectory(docDirURL, fileType: fileType)
            storeReferences(sandboxFileRefs, fileType: fileType, forExternalFiles: false)
            result.append(contentsOf: sandboxFileRefs)
        } else {
            result.append(contentsOf:
                getStoredReferences(fileType: fileType, forExternalFiles: false))
        }

        if includeBackup {
            result.append(contentsOf:scanLocalDirectory(backupDirURL, fileType: fileType))
        }
        return result
    }
    
    func scanLocalDirectory(_ dirURL: URL, fileType: FileType) -> [URLReference] {
        var refs: [URLReference] = []
        let location = getLocation(for: dirURL)
        do {
            let dirContents = try FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: nil,
                options: [])
            for url in dirContents {
                if !url.isDirectory && FileType(for: url) == fileType {
                    let urlRef = try URLReference(from: url, location: location)
                    refs.append(urlRef)
                }
            }
        } catch {
            Diag.error(error.localizedDescription)
        }
        return refs
    }
    
    public func addFile(
        url: URL,
        mode: OpenMode,
        success successHandler: ((URLReference)->Void)?,
        error errorHandler: ((FileKeeperError)->Void)?)
    {
        prepareToAddFile(url: url, mode: mode, notify: false)
        processPendingOperations(success: successHandler, error: errorHandler)
    }
    
    public func prepareToAddFile(url: URL, mode: OpenMode, notify: Bool=true) {
        Diag.debug("Preparing to add file [mode: \(mode)]")
        let origURL = url
        let actualURL = origURL.resolvingSymlinksInPath()
        print("\n originURL: \(origURL) \n actualURL: \(actualURL) \n")
        self.urlToOpen = origURL
        self.openMode = mode
        if notify {
            FileKeeperNotifier.notifyPendingFileOperation()
        }
    }
    
    public func processPendingOperations(
        success successHandler: ((URLReference)->Void)?,
        error errorHandler: ((FileKeeperError)->Void)?)
    {
        pendingOperationGroup.wait()
        pendingOperationGroup.enter()
        defer { pendingOperationGroup.leave() }
        
        guard let sourceURL = urlToOpen else { return }
        urlToOpen = nil

        Diag.debug("Will process pending file operations")

        guard sourceURL.isFileURL else {
            Diag.error("Tried to import a non-file URL: \(sourceURL.redacted)")
            let messageNotAFileURL = NSLocalizedString(
                "[FileKeeper] Not a file URL",
                bundle: Bundle.framework,
                value: "Not a file URL",
                comment: "Error message: tried to import URL which does not point to a file")
            switch openMode {
            case .import:
                let importError = FileKeeperError.importError(reason: messageNotAFileURL)
                errorHandler?(importError)
                return
            case .openInPlace:
                let openError = FileKeeperError.openError(reason: messageNotAFileURL)
                errorHandler?(openError)
                return
            }
        }
        
        
        let fileType = FileType(for: sourceURL)
        let location = getLocation(for: sourceURL)
        switch location {
        case .external:
            processExternalFile(
                url: sourceURL,
                fileType: fileType,
                success: successHandler,
                error: errorHandler)
        case .internalDocuments, .internalBackup:
            processInternalFile(
                url: sourceURL,
                fileType: fileType,
                location: location,
                success: successHandler,
                error: errorHandler)
        case .internalInbox:
            processInboxFile(
                url: sourceURL,
                fileType: fileType,
                location: location,
                success: successHandler,
                error: errorHandler)
        }
    }
    
    private func processExternalFile(
        url sourceURL: URL,
        fileType: FileType,
        success successHandler: ((URLReference) -> Void)?,
        error errorHandler: ((FileKeeperError) -> Void)?)
    {
        switch fileType {
        case .database:
            if let urlRef = findStoredExternalReferenceFor(url: sourceURL, fileType: fileType) {
                Settings.current.startupDatabase = urlRef
                FileKeeperNotifier.notifyFileAdded(urlRef: urlRef, fileType: fileType)
                Diag.info("Added already known external file, deduplicating.")
                successHandler?(urlRef)
                return
            }
            addExternalFileRef(
                url: sourceURL,
                fileType: fileType,
                success: { urlRef in
                    Settings.current.startupDatabase = urlRef
                    FileKeeperNotifier.notifyFileAdded(urlRef: urlRef, fileType: fileType)
                    Diag.info("External database added successfully")
                    successHandler?(urlRef)
                },
                error: errorHandler)
        case .keyFile:
            guard AppGroup.isMainApp else {
                addExternalFileRef(
                    url: sourceURL,
                    fileType: fileType,
                    success: { (urlRef) in
                        FileKeeperNotifier.notifyFileAdded(urlRef: urlRef, fileType: fileType)
                        Diag.info("External key file added successfully")
                        successHandler?(urlRef)
                    },
                    error: errorHandler
                )
                return 
            }
            importFile(
                url: sourceURL,
                success: { (url) in
                    do {
                        let urlRef = try URLReference(
                            from: url,
                            location: self.getLocation(for: url))
                        FileKeeperNotifier.notifyFileAdded(urlRef: urlRef, fileType: fileType)
                        Diag.info("External key file imported successfully")
                        successHandler?(urlRef)
                    } catch {
                        Diag.error("""
                            Failed to import external file [
                                type: \(fileType),
                                message: \(error.localizedDescription),
                                url: \(sourceURL.redacted)]
                            """)
                        let importError = FileKeeperError.importError(reason: error.localizedDescription)
                        errorHandler?(importError)
                    }
                },
                error: errorHandler
            )
        }
    }
    
    private func processInboxFile(
        url sourceURL: URL,
        fileType: FileType,
        location: URLReference.Location,
        success successHandler: ((URLReference) -> Void)?,
        error errorHandler: ((FileKeeperError) -> Void)?)
    {
        importFile(url: sourceURL, success: { url in
            do {
                let urlRef = try URLReference(from: url, location: location)
                if fileType == .database {
                    Settings.current.startupDatabase = urlRef
                }
                FileKeeperNotifier.notifyFileAdded(urlRef: urlRef, fileType: fileType)
                Diag.info("Inbox file added successfully [fileType: \(fileType)]")
                successHandler?(urlRef)
            } catch {
                Diag.error("Failed to import inbox file [type: \(fileType), message: \(error.localizedDescription)]")
                let importError = FileKeeperError.importError(reason: error.localizedDescription)
                errorHandler?(importError)
            }
        }, error: errorHandler)
    }
    
    
    private func processInternalFile(
        url sourceURL: URL,
        fileType: FileType,
        location: URLReference.Location,
        success successHandler: ((URLReference) -> Void)?,
        error errorHandler: ((FileKeeperError) -> Void)?)
    {
        do {
            let urlRef = try URLReference(from: sourceURL, location: location)
            if fileType == .database {
                Settings.current.startupDatabase = urlRef
            }
            FileKeeperNotifier.notifyFileAdded(urlRef: urlRef, fileType: fileType)
            Diag.info("Internal file processed successfully [fileType: \(fileType), location: \(location)]")
            successHandler?(urlRef)
        } catch {
            Diag.error("Failed to create URL reference [error: '\(error.localizedDescription)', url: '\(sourceURL.redacted)']")
            let importError = FileKeeperError.openError(reason: error.localizedDescription)
            errorHandler?(importError)
        }
    }
    
    private func addExternalFileRef(
        url sourceURL: URL,
        fileType: FileType,
        success successHandler: ((URLReference) -> Void)?,
        error errorHandler: ((FileKeeperError) -> Void)?)
    {
        Diag.debug("Will add external file reference")
        let dummyDoc = FileDocument(fileURL: sourceURL)
        
        dummyDoc.open(
            successHandler: { [weak self] in
                guard let _self = self else { return }
                do {
                    let newRef = try URLReference(from: sourceURL, location: .external)
                    
                    var storedRefs = _self.getStoredReferences(
                        fileType: fileType,
                        forExternalFiles: true)
                    storedRefs.insert(newRef, at: 0)
                    _self.storeReferences(storedRefs, fileType: fileType, forExternalFiles: true)
                    
                    Diag.info("External URL reference added OK")
                    successHandler?(newRef)
                } catch {
                    Diag.error("Failed to create URL reference [error: '\(error.localizedDescription)', url: '\(sourceURL.redacted)']")
                    let importError = FileKeeperError.openError(reason: error.localizedDescription)
                    errorHandler?(importError)
                }
            },
            errorHandler: { (error) in
                Diag.error("Failed to open document [error: '\(error.localizedDescription)', url: '\(sourceURL.redacted)']")
                let docError = FileKeeperError.openError(reason: error.localizedDescription)
                errorHandler?(docError)

            }
        )
    }
    
    
    private func importFile(
        url sourceURL: URL,
        success successHandler: ((URL) -> Void)?,
        error errorHandler: ((FileKeeperError)->Void)?)
    {
        let fileName = sourceURL.lastPathComponent
        let targetURL = docDirURL.appendingPathComponent(fileName)
        let sourceDirs = sourceURL.deletingLastPathComponent() 
        
        if sourceDirs.path == docDirURL.path {
            Diag.info("Tried to import a file already in Documents, nothing to do")
            successHandler?(sourceURL)
            return
        }
        
        Diag.debug("Will import a file")
        let doc = FileDocument(fileURL: sourceURL)
        doc.open(
            successHandler: { 
                self.saveDataWithConflictResolution(
                    doc.data,
                    to: targetURL,
                    conflictResolution: .ask,
                    success: successHandler,
                    error: errorHandler)
            },
            errorHandler: { error in 
                Diag.error("Failed to import external file [message: \(error.localizedDescription)]")
                let importError = FileKeeperError.importError(reason: error.localizedDescription)
                errorHandler?(importError)
                self.clearInbox()
            }
        )
    }
    
    private func saveDataWithConflictResolution(
        _ data: ByteArray,
        to targetURL: URL,
        conflictResolution: FileKeeper.ConflictResolution,
        success successHandler: ((URL) -> Void)?,
        error errorHandler: ((FileKeeperError)->Void)?)
    {
        let hasConflict = FileManager.default.fileExists(atPath: targetURL.path)
        guard hasConflict else {
            writeToFile(data, to: targetURL, success: successHandler, error: errorHandler)
            clearInbox()
            return
        }
        
        switch conflictResolution {
        case .ask:
            assert(delegate != nil)
            delegate?.shouldResolveImportConflict(
                target: targetURL,
                handler: { (resolution) in 
                    Diag.info("Conflict resolution: \(resolution)")
                    self.saveDataWithConflictResolution(
                        data,
                        to: targetURL,
                        conflictResolution: resolution,
                        success: successHandler,
                        error: errorHandler)
                }
            )
        case .abort:
            clearInbox()
            successHandler?(targetURL)
        case .rename:
            let newURL = makeUniqueFileName(targetURL)
            writeToFile(data, to: newURL, success: successHandler, error: errorHandler)
            clearInbox()
            successHandler?(newURL)
        case .overwrite:
            writeToFile(data, to: targetURL, success: successHandler, error: errorHandler)
            clearInbox()
            successHandler?(targetURL)
        }
    }
    
    
    private func makeUniqueFileName(_ url: URL) -> URL {
        let fileManager = FileManager.default

        let path = url.deletingLastPathComponent()
        let fileNameNoExt = url.deletingPathExtension().lastPathComponent
        let fileExt = url.pathExtension
        
        var fileName = url.lastPathComponent
        var index = 1
        while fileManager.fileExists(atPath: path.appendingPathComponent(fileName).path) {
            fileName = String(format: "%@ (%d).%@", fileNameNoExt, index, fileExt)
            index += 1
        }
        return path.appendingPathComponent(fileName)
    }
    
    private func writeToFile(
        _ bytes: ByteArray,
        to targetURL: URL,
        success successHandler: ((URL) -> Void)?,
        error errorHandler: ((FileKeeperError)->Void)?)
    {
        do {
            try bytes.write(to: targetURL, options: [.atomicWrite])
            Diag.debug("File imported successfully")
            clearInbox()
            successHandler?(targetURL)
        } catch {
            Diag.error("Failed to save external file [message: \(error.localizedDescription)]")
            let importError = FileKeeperError.importError(reason: error.localizedDescription)
            errorHandler?(importError)
        }
    }
    
    private func clearInbox() {
        let fileManager = FileManager()
        let inboxFiles = try? fileManager.contentsOfDirectory(
            at: inboxDirURL,
            includingPropertiesForKeys: nil,
            options: [])
        inboxFiles?.forEach {
            try? fileManager.removeItem(at: $0) 
        }
    }
    
    
    func makeBackup(nameTemplate: String, contents: ByteArray) {
        guard !contents.isEmpty else {
            Diag.info("No data to backup.")
            return
        }
        guard let encodedNameTemplate = nameTemplate
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        guard let nameTemplateURL = URL(string: encodedNameTemplate) else { return }
        
        deleteExpiredBackupFiles()
        
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(
                at: backupDirURL,
                withIntermediateDirectories: true,
                attributes: nil)

            let timestamp = Date.now - 1.0
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestampStr = dateFormatter.string(from: timestamp)

            let baseFileName = nameTemplateURL
                .deletingPathExtension()
                .absoluteString
                .removingPercentEncoding  
                ?? nameTemplate           
            let baseFileExt = nameTemplateURL.pathExtension
            let backupFileURL = backupDirURL
                .appendingPathComponent(baseFileName + "_" + timestampStr, isDirectory: false)
                .appendingPathExtension(baseFileExt)
            try contents.asData.write(to: backupFileURL, options: .atomic)
            
            try fileManager.setAttributes(
                [FileAttributeKey.creationDate: timestamp,
                 FileAttributeKey.modificationDate: timestamp],
                ofItemAtPath: backupFileURL.path)
            Diag.info("Backup copy created OK")
        } catch {
            Diag.warning("Failed to make backup copy [error: \(error.localizedDescription)]")
        }
    }
    
    public func getBackupFiles() -> [URLReference] {
        return scanLocalDirectory(backupDirURL, fileType: .database)
    }
    
    @discardableResult
    public func deleteExpiredBackupFiles() -> Bool {
        Diag.debug("Will perform backup maintenance")
        let isAllOK = deleteBackupFiles(olderThan: Settings.current.backupKeepingDuration.seconds)
        Diag.info("Backup maintenance completed [allOK: \(isAllOK)]")
        return isAllOK
    }

    @discardableResult
    public func deleteBackupFiles(olderThan maxAge: TimeInterval) -> Bool {
        let allBackupFileRefs = getBackupFiles()
        var isEverythingProcessedOK = true
        let now = Date.now
        for fileRef in allBackupFileRefs {
            guard let modificationDate = fileRef.getInfo().modificationDate else { continue }
            if now.timeIntervalSince(modificationDate) < maxAge {
                continue
            }
            do {
                try deleteFile(fileRef, fileType: .database, ignoreErrors: false)
                FileKeeperNotifier.notifyFileRemoved(urlRef: fileRef, fileType: .database)
            } catch {
                isEverythingProcessedOK = false
            }
        }
        return isEverythingProcessedOK
    }
}
