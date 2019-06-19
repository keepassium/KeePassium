//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class Database2: Database {
    
    public enum FormatVersion {
        case v3
        case v4
    }
    
    public enum FormatError: LocalizedError {
        case prematureDataEnd
        case negativeBlockSize(blockIndex: Int)
        case parsingError(reason: String)
        case blockIDMismatch
        case blockHashMismatch(blockIndex: Int) 
        case blockHMACMismatch(blockIndex: Int) 
        case compressionError(reason: String)
        public var errorDescription: String? {
            switch self {
            case .prematureDataEnd:
                return NSLocalizedString("Unexpected end of file. Corrupted file?", comment: "Error message")
            case .negativeBlockSize(let blockIndex):
                return NSLocalizedString("Corrupted database file (negative block #\(blockIndex) size)", comment: "Error message")
            case .parsingError(let reason):
                return NSLocalizedString("Cannot parse database. \(reason)", comment: "An error message. Parsing refers to the analysis/understanding of file content (do not confuse with reading it).")
            case .blockIDMismatch:
                return NSLocalizedString("Unexpected block ID.", comment: "Error message: wrong ID of a data block")
            case .blockHashMismatch(let blockIndex):
                return NSLocalizedString("Block #\(blockIndex) hash mismatch.", comment: "Error message: hash(checksum) of a data block is wrong")
            case .blockHMACMismatch(let blockIndex):
                return NSLocalizedString("Block #\(blockIndex) HMAC mismatch.", comment: "Error message: HMAC value (kind of checksum) of a data block is wrong")
            case .compressionError(let reason):
                return NSLocalizedString("Gzip error: \(reason)", comment: "Generic error message about Gzip compression algorithm")
            }
        }
    }
    
    private enum ProgressSteps {
        static let all: Int64 = 100
        static let keyDerivation: Int64 = 60

        static let decryption: Int64 = 20
        static let readingBlocks: Int64 = 5
        static let gzipUnpack: Int64 = 5
        static let parsing: Int64 = 10
        
        static let packing: Int64 = 10
        static let gzipPack: Int64 = 5
        static let encryption: Int64 = 20
        static let writingBlocks: Int64 = 5
    }
    
    private(set) var header: Header2!
    private(set) var meta: Meta2!
    public var binaries: [Binary2.ID: Binary2] = [:]
    public var customIcons: [UUID: CustomIcon2] { return meta.customIcons }
    private var cipherKey = SecureByteArray()
    private var hmacKey = ByteArray()
    private var deletedObjects: ContiguousArray<DeletedObject2> = []
    
    override public var keyHelper: KeyHelper { return _keyHelper }
    private let _keyHelper = KeyHelper2()
    
    override public init() {
        super.init()
        header = Header2(database: self)
        meta = Meta2(database: self)
    }
    
    deinit {
        erase()
    }
    
    override public func erase() {
        header.erase()
        meta.erase()
        binaries.removeAll()
        cipherKey.erase()
        hmacKey.erase()
        deletedObjects.removeAll()
        super.erase()
    }
    
    internal static func makeNewV4() -> Database2 {
        let db = Database2()
        db.header.loadDefaultValuesV4()
        db.meta.loadDefaultValuesV4()
        
        let rootGroup = Group2(database: db)
        rootGroup.uuid = UUID()
        rootGroup.name = "/"
        rootGroup.isAutoTypeEnabled = true
        rootGroup.isSearchingEnabled = true
        rootGroup.canExpire = false
        rootGroup.isExpanded = true
        db.root = rootGroup
        return db
    }
    
    override public class func isSignatureMatches(data: ByteArray) -> Bool {
        return Header2.isSignatureMatches(data: data)
    }
    
    internal func addDeletedObject(uuid: UUID) {
        let deletedObject = DeletedObject2(database: self, uuid: uuid)
        deletedObjects.append(deletedObject)
    }
    
    override public func load(
        dbFileData: ByteArray,
        compositeKey: SecureByteArray,
        warnings: DatabaseLoadingWarnings
    ) throws {
        Diag.info("Loading KP2 database")
        progress.completedUnitCount = 0
        progress.totalUnitCount = ProgressSteps.all
        progress.localizedAdditionalDescription = NSLocalizedString("Loading database", comment: "Progress bar status")
        do {
            try header.read(data: dbFileData) 
            Diag.debug("Header read OK [format: \(header.formatVersion)]")
            Diag.verbose("== DB2 progress CP1: \(progress.completedUnitCount)")
            
            try deriveMasterKey(compositeKey: compositeKey, cipher: header.dataCipher)
            Diag.debug("Key derivation OK")
            Diag.verbose("== DB2 progress CP2: \(progress.completedUnitCount)")
            
            var decryptedData: ByteArray
            let dbWithoutHeader: ByteArray = dbFileData.suffix(from: header.size)

            switch header.formatVersion {
            case .v3:
                decryptedData = try decryptBlocksV3(
                    data: dbWithoutHeader,
                    cipher: header.dataCipher)
            case .v4:
                decryptedData = try decryptBlocksV4(
                    data: dbWithoutHeader,
                    cipher: header.dataCipher)
            }
            Diag.debug("Block decryption OK")
            Diag.verbose("== DB2 progress CP3: \(progress.completedUnitCount)")
            
            if header.isCompressed {
                Diag.debug("Inflating Gzip data")
                decryptedData = try decryptedData.gunzipped() 
            } else {
                Diag.debug("Data not compressed")
            }
            progress.completedUnitCount += ProgressSteps.gzipUnpack
            Diag.verbose("== DB2 progress CP4: \(progress.completedUnitCount)")
            
            var xmlData: ByteArray
            switch header.formatVersion {
            case .v3:
                xmlData = decryptedData
            case .v4:
                let innerHeaderSize = try header.readInner(data: decryptedData) 
                xmlData = decryptedData.suffix(from: innerHeaderSize)
                Diag.debug("Inner header read OK")
            }
            
            try removeGarbageAfterXML(data: xmlData) 
            
            try load(xmlData: xmlData, warnings: warnings) 
            
            propagateDeletedStatus()
            
            checkAttachmentsIntegrity(warnings: warnings)
            
            checkCustomFieldsIntegrity(warnings: warnings)
            
            Diag.debug("Content loaded OK")
            Diag.verbose("== DB2 progress CP5: \(progress.completedUnitCount)")
        } catch let error as Header2.HeaderError {
            Diag.error("Header error [reason: \(error.localizedDescription)]")
            throw DatabaseError.loadError(reason: error.localizedDescription)
        } catch let error as CryptoError {
            Diag.error("Crypto error [reason: \(error.localizedDescription)]")
            throw DatabaseError.loadError(reason: error.localizedDescription)
        } catch let error as FormatError {
            Diag.error("Format error [reason: \(error.localizedDescription)]")
            throw DatabaseError.loadError(reason: error.localizedDescription)
        } catch let error as GzipError {
            Diag.error("Gzip error [kind: \(error.kind), message: \(error.message)]")
            throw DatabaseError.loadError(reason: NSLocalizedString("Error unpacking database (\(error.message))", comment: "Error message. Unpacking is decompression of compressed data."))
        }
        
        self.compositeKey = compositeKey
    }
    
    func xmlStringToDate(_ string: String?) -> Date? {
        switch header.formatVersion {
        case .v3:
            return Date(iso8601string: string)
        case .v4:
            return Date(base64Encoded: string)
        }
    }
    
    func xmlDateToString(_ date: Date) -> String {
        switch header.formatVersion {
        case .v3:
            return date.iso8601String()
        case .v4:
            return date.base64EncodedString()
        }
    }
    
    func decryptBlocksV4(data: ByteArray, cipher: DataCipher) throws -> ByteArray {
        Diag.debug("Decrypting V4 blocks")
        let inStream = data.asInputStream()
        inStream.open()
        defer { inStream.close() }
        
        guard let storedHash = inStream.read(count: SHA256_SIZE) else {
            throw FormatError.prematureDataEnd
        }
        guard header.hash == storedHash else {
            Diag.error("Header hash mismatch. Database corrupted?")
            throw Header2.HeaderError.hashMismatch
        }
        
        let headerHMAC = header.getHMAC(key: self.hmacKey)
        guard let storedHMAC = inStream.read(count: SHA256_SIZE) else {
            throw FormatError.prematureDataEnd
        }
        guard headerHMAC == storedHMAC else {
            Diag.error("Header HMAC mismatch. Invalid master key?")
            throw DatabaseError.invalidKey
        }
        
        Diag.verbose("Reading blocks")
        let blockBytesCount = data.count - storedHash.count - storedHMAC.count
        let allBlocksData = ByteArray(capacity: blockBytesCount)
        let readingProgress = ProgressEx()
        readingProgress.totalUnitCount = Int64(blockBytesCount)
        readingProgress.localizedAdditionalDescription = NSLocalizedString("Reading database content", comment: "Status message")
        progress.addChild(readingProgress, withPendingUnitCount: ProgressSteps.readingBlocks)
        var blockIndex: UInt64 = 0
        while true {
            guard let storedBlockHMAC = inStream.read(count: SHA256_SIZE) else {
                throw FormatError.prematureDataEnd
            }
            guard let blockSize = inStream.readInt32() else {
                throw FormatError.prematureDataEnd
            }
            guard blockSize >= 0 else {
                throw FormatError.negativeBlockSize(blockIndex: Int(blockIndex))
            }
            
            guard let blockData = inStream.read(count: Int(blockSize)) else {
                throw FormatError.prematureDataEnd
            }
            let blockKey = CryptoManager.getHMACKey64(key: hmacKey, blockIndex: blockIndex)
            let dataForHMAC = ByteArray.concat(blockIndex.data, blockSize.data, blockData)
            let blockHMAC = CryptoManager.hmacSHA256(data: dataForHMAC, key: blockKey)
            guard blockHMAC == storedBlockHMAC else {
                Diag.error("Block HMAC mismatch")
                throw FormatError.blockHMACMismatch(blockIndex: Int(blockIndex))
            }

            let bytesReadNow = storedBlockHMAC.count + blockSize.byteWidth + blockData.count
            readingProgress.completedUnitCount += Int64(bytesReadNow)
            
            if blockSize == 0 { break }

            allBlocksData.append(blockData)
            blockIndex += 1
        }
        
        Diag.verbose("Will decrypt \(allBlocksData.count) bytes")
        progress.addChild(cipher.initProgress(), withPendingUnitCount: ProgressSteps.decryption)
        let decryptedData = try cipher.decrypt(
            cipherText: allBlocksData,
            key: cipherKey,
            iv: header.initialVector) 
        Diag.verbose("Decrypted \(decryptedData.count) bytes")

        return decryptedData
    }
    
    func decryptBlocksV3(data: ByteArray, cipher: DataCipher) throws -> ByteArray {
        Diag.debug("Decrypting V3 blocks")
        progress.addChild(cipher.initProgress(), withPendingUnitCount: ProgressSteps.decryption)
        var decryptedData = try cipher.decrypt(
            cipherText: data,
            key: cipherKey,
            iv: header.initialVector) 
        Diag.verbose("Decrypted \(decryptedData.count) bytes")
        
        let decryptedStream = decryptedData.asInputStream()
        decryptedStream.open()
        defer { decryptedStream.close() }
        
        guard let startData = decryptedStream.read(count: SHA256_SIZE) else {
            throw FormatError.prematureDataEnd
        }
        guard startData == header.fields[.streamStartBytes] else {
            Diag.error("First bytes do not match. Invalid master key?")
            throw DatabaseError.invalidKey
        }
        
        let blocksData = ByteArray(capacity: decryptedData.count - startData.count)
        var blockID: UInt32 = 0
        let readingProgress = ProgressEx()
        readingProgress.totalUnitCount = Int64(decryptedData.count - startData.count)
        readingProgress.localizedAdditionalDescription = NSLocalizedString("Reading database content", comment: "Status message")
        progress.addChild(readingProgress, withPendingUnitCount: ProgressSteps.readingBlocks)
        while(true) {
            guard let inBlockID: UInt32 = decryptedStream.readUInt32() else {
                throw FormatError.prematureDataEnd
            }
            guard inBlockID == blockID else {
                Diag.error("Block ID mismatch")
                throw FormatError.blockIDMismatch
            }
            blockID += 1
            
            guard let storedBlockHash = decryptedStream.read(count: SHA256_SIZE) else {
                throw FormatError.prematureDataEnd
            }
            guard let blockSize: UInt32 = decryptedStream.readUInt32() else {
                throw FormatError.prematureDataEnd
            }
            if blockSize == 0 {
                if storedBlockHash.containsOnly(0) {
                    break
                } else {
                    Diag.error("Empty block with non-zero hash. Database corrupted?")
                    throw FormatError.blockHashMismatch(blockIndex: Int(blockID))
                }
            }
            guard let blockData = decryptedStream.read(count: Int(blockSize)) else {
                throw FormatError.prematureDataEnd
            }
            let computedBlockHash = blockData.sha256
            guard computedBlockHash == storedBlockHash else {
                Diag.error("Block hash mismatch")
                throw FormatError.blockHashMismatch(blockIndex: Int(blockID))
            }
            blocksData.append(blockData)
            readingProgress.completedUnitCount +=
                Int64(sizeof(blockID) + SHA256_SIZE + sizeof(blockSize) + Int(blockSize))
            blockData.erase()
        }
        readingProgress.completedUnitCount = readingProgress.totalUnitCount
        return blocksData
    }

    
    private func removeGarbageAfterXML(data: ByteArray) throws {
        guard header.dataCipher is TwofishDataCipher else { return }
        
        let finalXMLTagBytes = ("</" + Xml2.keePassFile + ">").arrayUsingUTF8StringEncoding
        let finalTagSize = finalXMLTagBytes.count
        guard data.count > finalTagSize else { return }
        
        let lastBytes = data.withBytes { $0[(data.count - finalTagSize)..<data.count] }
        if lastBytes.elementsEqual(finalXMLTagBytes) {
            return
        }
        
        let searchFrom = data.count - finalTagSize - 2 * Twofish.blockSize
        let searchTo = data.count - finalTagSize
        guard searchFrom > 0 && searchTo > 0 else { return }
        var closingTagIndex: Int? = nil
        data.withBytes {
            for i in searchFrom...searchTo {
                let slice = $0[i..<(i + finalTagSize)]
                if slice.elementsEqual(finalXMLTagBytes) {
                    closingTagIndex = i
                    break
                }
            }
        }

        guard let _closingTagIndex = closingTagIndex else {
            Diag.warning("Failed to remove padding from XML content")
            throw CryptoError.paddingError(code: 100)
        }
        Diag.warning("Removed random padding from XML data")
        data.trim(toCount: _closingTagIndex + finalTagSize)
    }

    func load(xmlData: ByteArray, warnings: DatabaseLoadingWarnings) throws {
        var parsingOptions = AEXMLOptions()
        parsingOptions.documentHeader.standalone = "yes"
        parsingOptions.parserSettings.shouldTrimWhitespace = false
        do {
            Diag.debug("Parsing XML")
            let xmlDoc = try AEXMLDocument(xml: xmlData.asData, options: parsingOptions)
            if let xmlError = xmlDoc.error {
                Diag.error("Cannot parse XML: \(xmlError.localizedDescription)")
                throw Xml2.ParsingError.xmlError(details: xmlError.localizedDescription)
            }
            guard xmlDoc.root.name == Xml2.keePassFile else {
                Diag.error("Not a KeePass XML document [xmlRoot: \(xmlDoc.root.name)]")
                throw Xml2.ParsingError.notKeePassDocument
            }
            
            let rootGroup = Group2(database: self)
            rootGroup.parent = nil
            
            for tag in xmlDoc.root.children {
                switch tag.name {
                case Xml2.meta:
                    try meta.load(xml: tag, streamCipher: header.streamCipher, warnings: warnings)
                    
                    if meta.headerHash != nil && (header.hash != meta.headerHash!) {
                        Diag.error("KP2v3 meta meta hash mismatch")
                        throw Header2.HeaderError.hashMismatch
                    }
                    Diag.verbose("Meta loaded OK")
                case Xml2.root:
                    try loadRoot(xml: tag, root: rootGroup, warnings: warnings)
                    Diag.verbose("XML root loaded OK")
                default:
                    throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "KeePassFile/*")
                }
            }
            
            progress.completedUnitCount += ProgressSteps.parsing
            
            self.root = rootGroup
            Diag.debug("XML content loaded OK")
        } catch let error as Header2.HeaderError {
            Diag.error("Header error [reason: \(error.localizedDescription)]")
            throw FormatError.parsingError(reason: error.localizedDescription)
        } catch let error as Xml2.ParsingError {
            Diag.error("XML parsing error [reason: \(error.localizedDescription)]")
            throw FormatError.parsingError(reason: error.localizedDescription)
        } catch let error as AEXMLError {
            Diag.error("Raw XML parsing error [reason: \(error.localizedDescription)]")
            throw FormatError.parsingError(reason: error.localizedDescription)
        }
    }
    
    internal func loadRoot(
        xml: AEXMLElement,
        root: Group2,
        warnings: DatabaseLoadingWarnings
        ) throws
    {
        assert(xml.name == Xml2.root)
        Diag.debug("Loading XML root")
        for tag in xml.children {
            switch tag.name {
            case Xml2.group:
                try root.load(xml: tag, streamCipher: header.streamCipher, warnings: warnings)
            case Xml2.deletedObjects:
                try loadDeletedObjects(xml: tag)
            default:
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Root/*")
            }
        }
    }
    
    private func loadDeletedObjects(xml: AEXMLElement) throws {
        assert(xml.name == Xml2.deletedObjects)
        for tag in xml.children {
            switch tag.name {
            case Xml2.deletedObject:
                let deletedObject = DeletedObject2(database: self)
                try deletedObject.load(xml: tag)
                deletedObjects.append(deletedObject)
            default:
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "DeletedObjects/*")
            }
        }
    }
    
    private func propagateDeletedStatus() {
        if let backupGroup = getBackupGroup(createIfMissing: false) {
            var deletedGroups = [Group2]() as [Group]
            var deletedEntries = [Entry2]() as [Entry]
            backupGroup.collectAllChildren(groups: &deletedGroups, entries: &deletedEntries)
            deletedGroups.forEach { $0.isDeleted = true }
            deletedEntries.forEach { $0.isDeleted = true }
        }
    }
    
    func deriveMasterKey(compositeKey: SecureByteArray, cipher: DataCipher) throws {
        Diag.debug("Start key derivation")
        progress.addChild(header.kdf.initProgress(), withPendingUnitCount: ProgressSteps.keyDerivation)
        let transformedKey = try header.kdf.transform(key: compositeKey, params: header.kdfParams)
        let joinedKey = ByteArray.concat(header.masterSeed, transformedKey)
        self.cipherKey = cipher.resizeKey(key: joinedKey)
        let one = ByteArray(bytes: [1])
        self.hmacKey = ByteArray.concat(joinedKey, one).sha512
    }
    
    override public func changeCompositeKey(to newKey: SecureByteArray) {
        compositeKey = newKey
    }
    
    override public func getBackupGroup(createIfMissing: Bool) -> Group? {
        assert(root != nil)
        if !meta.isRecycleBinEnabled {
            Diag.verbose("RecycleBin disabled in Meta")
            return nil
        }

        guard let root = root else {
            Diag.warning("Tried to get RecycleBin group without the root one")
            assertionFailure()
            return nil
        }
        
        if meta.recycleBinGroupUUID != UUID.ZERO {
            if let backupGroup = root.findGroup(byUUID: meta.recycleBinGroupUUID) {
                Diag.verbose("RecycleBin group found")
                return backupGroup
            }
        }
        
        if createIfMissing {
            let backupGroup = meta.createRecycleBinGroup()
            root.add(group: backupGroup)
            Diag.verbose("RecycleBin group created")
            return backupGroup
        }
        Diag.verbose("RecycleBin group not found nor created.")
        return nil
    }
    
    
    func checkAttachmentsIntegrity(warnings: DatabaseLoadingWarnings) {
        func mapAttachmentNamesByID(of entry: Entry2, nameByID: inout [Binary2.ID: String]) {
            (entry.attachments as! [Attachment2]).forEach { (attachment) in
                nameByID[attachment.id] = attachment.name
            }
            entry.history.forEach { (historyEntry) in
                mapAttachmentNamesByID(of: historyEntry, nameByID: &nameByID)
            }
        }
        
        func insertAllAttachmentIDs(of entry: Entry2, into ids: inout Set<Binary2.ID>) {
            let attachments2 = entry.attachments as! [Attachment2]
            ids.formUnion(attachments2.map { $0.id })
            entry.history.forEach { (historyEntry) in
                insertAllAttachmentIDs(of: historyEntry, into: &ids)
            }
        }
        
        var allEntries = [Entry]()
        root?.collectAllEntries(to: &allEntries)
        
        var usedIDs = Set<Binary2.ID>() 
        allEntries.forEach { (entry) in
            insertAllAttachmentIDs(of: entry as! Entry2, into: &usedIDs)
        }
        let knownIDs = Set(binaries.keys) 
        
        if knownIDs == usedIDs {
            Diag.debug("Attachments integrity OK")
            return
        }
        
        let unusedBinaries = knownIDs.subtracting(usedIDs)
        let missingBinaries = usedIDs.subtracting(knownIDs)
        
        if unusedBinaries.count > 0 {
            let lastUsedAppName = warnings.databaseGenerator ?? ""
            let warningMessage = NSLocalizedString("The database contains some attachments that are not used in any entry. Most likely, they have been forgotten by the last used app (\(lastUsedAppName)). However, this can also be a sign of data corruption. \nPlease make sure to have a backup of your database before changing anything.", comment: "A warning about unused attachments after loading the database.")
            warnings.messages.append(warningMessage)
            
            let unusedIDs = unusedBinaries
                .map { String($0) }
                .joined(separator: ", ")
            Diag.warning("Some binaries are not referenced from any entry [IDs: \(unusedIDs)]")
        }
        
        if missingBinaries.count > 0 {
            
            var attachmentNameByID = [Binary2.ID: String]()
            allEntries.forEach { (entry) in
                mapAttachmentNamesByID(of: entry as! Entry2, nameByID: &attachmentNameByID)
            }
            let attachmentNames = missingBinaries
                .compactMap { attachmentNameByID[$0] } 
                .map { "\"\($0)\"" } 
                .joined(separator: "\n ") 
            
            let lastUsedAppName = warnings.databaseGenerator ?? ""
            let warningMessage = NSLocalizedString("Attachments of some entries are missing data. This is a sign of database corruption, most likely by the last used app (\(lastUsedAppName)). KeePassium will preserve the empty attachments, but cannot restore them. You should restore your database from a backup copy. \n\nMissing attachments: \(attachmentNames)", comment: "A warning about missing attachments after loading the database.")
            warnings.messages.append(warningMessage)

            let missingIDs = missingBinaries
                .map { String($0) }
                .joined(separator: ", ")
            Diag.warning("Some entries refer to non-existent binaries [IDs: \(missingIDs)]")
        }
    }
    
    private func checkCustomFieldsIntegrity(warnings: DatabaseLoadingWarnings) {
        guard let root = root else { return }
        var allEntries = [Entry]()
        root.collectAllEntries(to: &allEntries)
        
        let problematicEntries = allEntries.filter { entry in
            let isProblematicEntry = entry.fields.reduce(false) { result, field in
                return result || field.name.isEmpty
            }
            return isProblematicEntry
        }
        guard problematicEntries.count > 0 else { return }
        
        let entryPaths = problematicEntries
            .map { entry in "'\(entry.title)' in '\(entry.getGroupPath())'" }
            .joined(separator: "\n")
        let warningMessage = NSLocalizedString("Some entries have custom field(s) with empty names. This can be a sign of data corruption. Please check these entries:\n\n\(entryPaths)", comment: "A warning about misformatted custom fields after loading the database.")
        warnings.messages.append(warningMessage)
    }
    
    private func updateBinaries(root: Group2) {
        Diag.verbose("Updating all binaries")
        var allEntries = [Entry2]() as [Entry]
        root.collectAllEntries(to: &allEntries)

        var oldBinaryPoolInverse = [ByteArray : Binary2]()
        binaries.values.forEach { oldBinaryPoolInverse[$0.data] = $0 }
        
        var newBinaryPoolInverse = [ByteArray: Binary2]()
        for entry in allEntries {
            updateBinaries(
                entry: entry as! Entry2,
                oldPoolInverse: oldBinaryPoolInverse,
                newPoolInverse: &newBinaryPoolInverse)
        }
        binaries.removeAll()
        newBinaryPoolInverse.values.forEach { binaries[$0.id] = $0 }
    }

    private func updateBinaries(
        entry: Entry2,
        oldPoolInverse: [ByteArray: Binary2],
        newPoolInverse: inout [ByteArray: Binary2])
    {
        for histEntry in entry.history {
            updateBinaries(
                entry: histEntry,
                oldPoolInverse: oldPoolInverse,
                newPoolInverse: &newPoolInverse
            )
        }
        
        for att in entry.attachments {
            let att2 = att as! Attachment2
            if let binaryInNewPool = newPoolInverse[att2.data],
                binaryInNewPool.isCompressed == att2.isCompressed
            {
                att2.id = binaryInNewPool.id
                continue
            }
            
            let newID = newPoolInverse.count
            let newBinary: Binary2
            if let binaryInOldPool = oldPoolInverse[att2.data],
                binaryInOldPool.isCompressed == att2.isCompressed
            {
                newBinary = Binary2(
                    id: newID,
                    data: binaryInOldPool.data,
                    isCompressed: binaryInOldPool.isCompressed,
                    isProtected: binaryInOldPool.isProtected
                )
            } else {
                newBinary = Binary2(
                    id: newID,
                    data: att2.data,
                    isCompressed: att2.isCompressed,
                    isProtected: true
                )
            }
            newPoolInverse[newBinary.data] = newBinary
            att2.id = newID
        }
    }
    
    override public func save() throws -> ByteArray {
        Diag.info("Saving KP2 database")
        assert(root != nil, "Load or create a DB before saving.")
        
        progress.totalUnitCount = ProgressSteps.all
        progress.completedUnitCount = 0
        header.maybeUpdateFormatVersion()
        let formatVersion = header.formatVersion
        Diag.debug("Format version: \(formatVersion)")
        do {
            try header.randomizeSeeds() 
            Diag.debug("Seeds randomized OK")
            try deriveMasterKey(compositeKey: compositeKey, cipher: header.dataCipher)
            Diag.debug("Key derivation OK")
        } catch let error as CryptoError {
            Diag.error("Crypto error [reason: \(error.localizedDescription)]")
            throw DatabaseError.saveError(reason: error.localizedDescription)
        }

        
        updateBinaries(root: root! as! Group2)
        Diag.verbose("Binaries updated OK")
        
        let outStream = ByteArray.makeOutputStream()
        outStream.open()
        defer { outStream.close() }
        progress.completedUnitCount += ProgressSteps.packing
        
        header.write(to: outStream) 

        meta.headerHash = header.hash
        let xmlString = try self.toXml().xml 
        let xmlData = ByteArray(utf8String: xmlString)
        Diag.debug("XML generation OK")

        switch formatVersion {
        case .v3:
            try encryptBlocksV3(to: outStream, xmlData: xmlData) 
        case .v4:
            try encryptBlocksV4(to: outStream, xmlData: xmlData) 
        }
        Diag.debug("Content encryption OK")
        
        progress.completedUnitCount = progress.totalUnitCount
        return outStream.data!
    }
    
    internal func encryptBlocksV4(to outStream: ByteArray.OutputStream, xmlData: ByteArray) throws {
        Diag.debug("Encrypting KP2v4 blocks")
        outStream.write(data: header.hash)
        outStream.write(data: header.getHMAC(key: hmacKey))

        
        let contentStream = ByteArray.makeOutputStream()
        contentStream.open()
        defer { contentStream.close() }

        do {
            try header.writeInner(to: contentStream) 
            Diag.verbose("Header written OK")
            contentStream.write(data: xmlData)
            guard let contentData = contentStream.data else { fatalError() }

            var dataToEncrypt = contentData
            if header.isCompressed {
                dataToEncrypt = try contentData.gzipped()
                Diag.verbose("Gzip compression OK")
            } else {
                Diag.verbose("No compression required")
            }
            progress.completedUnitCount += ProgressSteps.gzipPack
            
            Diag.verbose("Encrypting \(dataToEncrypt.count) bytes")
            progress.addChild(
                header.dataCipher.initProgress(),
                withPendingUnitCount: ProgressSteps.encryption)
            let encData = try header.dataCipher.encrypt(
                plainText: dataToEncrypt,
                key: cipherKey,
                iv: header.initialVector) 
            Diag.verbose("Encrypted \(encData.count) bytes")
            
            try writeAsBlocksV4(to: outStream, data: encData) 
            Diag.verbose("Blocks written OK")
        } catch let error as Header2.HeaderError {
            Diag.error("Header error [message: \(error.localizedDescription)]")
            throw DatabaseError.saveError(reason: error.localizedDescription)
        } catch let error as GzipError {
            Diag.error("Gzip error [kind: \(error.kind), message: \(error.message)]")
            let errMsg = NSLocalizedString("Data compression error: \(error.localizedDescription)", comment: "Error message")
            throw DatabaseError.saveError(reason: errMsg)
        } catch let error as CryptoError {
            Diag.error("Crypto error [reason: \(error.localizedDescription)]")
            let errMsg = NSLocalizedString("Encryption error: \(error.localizedDescription)", comment: "Error message")
            throw DatabaseError.saveError(reason: errMsg)
        }
    }
    
    internal func writeAsBlocksV4(to blockStream: ByteArray.OutputStream, data: ByteArray) throws {
        Diag.debug("Writing KP2v4 blocks")
        let defaultBlockSize  = 1024 * 1024 
        var blockStart: Int = 0
        var blockIndex: UInt64 = 0
        
        let writeProgress = ProgressEx()
        writeProgress.totalUnitCount = Int64(data.count)
        writeProgress.localizedAdditionalDescription = NSLocalizedString("Writing encrypted blocks", comment: "Status message")
        progress.addChild(writeProgress, withPendingUnitCount: ProgressSteps.writingBlocks)
        
        Diag.verbose("\(data.count) bytes to write")
        while blockStart != data.count {
            let blockSize = min(defaultBlockSize, data.count - blockStart)
            let blockData = data[blockStart..<blockStart+blockSize]

            let blockKey = CryptoManager.getHMACKey64(key: hmacKey, blockIndex: blockIndex)
            let dataForHMAC = ByteArray.concat(blockIndex.data, Int32(blockSize).data, blockData)
            let blockHMAC = CryptoManager.hmacSHA256(data: dataForHMAC, key: blockKey)
            blockStream.write(data: blockHMAC)
            blockStream.write(value: Int32(blockSize))
            blockStream.write(data: blockData)
            blockStart += blockSize
            blockIndex += 1
            writeProgress.completedUnitCount += Int64(blockSize)
            if writeProgress.isCancelled {
                throw ProgressInterruption.cancelled(reason: writeProgress.cancellationReason)
            }
        }
        let endBlockSize: Int32 = 0
        let endBlockKey = CryptoManager.getHMACKey64(key: hmacKey, blockIndex: blockIndex)
        let endBlockHMAC = CryptoManager.hmacSHA256(
            data: ByteArray.concat(blockIndex.data, endBlockSize.data),
            key: endBlockKey)
        blockStream.write(data: endBlockHMAC)
        blockStream.write(value: endBlockSize) 
        
        writeProgress.completedUnitCount = writeProgress.totalUnitCount
    }
    
    internal func encryptBlocksV3(to outStream: ByteArray.OutputStream, xmlData: ByteArray) throws {
        Diag.debug("Encrypting KP2v3 blocks")
        let dataToSplit: ByteArray
        if header.isCompressed {
            do {
                dataToSplit = try xmlData.gzipped()
                Diag.verbose("Gzip compression OK")
            } catch let error as GzipError {
                Diag.error("Gzip error [kind: \(error.kind), message: \(error.message)]")
                let errMsg = NSLocalizedString("Data compression error: \(error.localizedDescription)", comment: "Error message")
                throw DatabaseError.saveError(reason: errMsg)
            }
        } else {
            dataToSplit = xmlData
            Diag.verbose("No compression required")
        }
        progress.completedUnitCount += ProgressSteps.gzipPack
        
        let blockStream = ByteArray.makeOutputStream()
        blockStream.open()
        defer { blockStream.close() }
        blockStream.write(data: header.streamStartBytes!) 
        try splitToBlocksV3(to: blockStream, data: dataToSplit) 
        guard let blocksData = blockStream.data else { fatalError() }
        Diag.verbose("Blocks split OK")
        
        do {
            progress.addChild(
                header.dataCipher.initProgress(),
                withPendingUnitCount: ProgressSteps.encryption)
            let encryptedData = try header.dataCipher.encrypt(
                plainText: blocksData,
                key: cipherKey,
                iv: header.initialVector) 
            outStream.write(data: encryptedData)
            Diag.verbose("Encryption OK")
        } catch let error as CryptoError {
            Diag.error("Crypto error [message: \(error.localizedDescription)]")
            let errMsg = NSLocalizedString("Encryption error: \(error.localizedDescription)", comment: "Error message")
            throw DatabaseError.saveError(reason: errMsg)
        }
    }
    
    internal func splitToBlocksV3(to stream: ByteArray.OutputStream, data inData: ByteArray) throws {
        Diag.verbose("Will split to KP2v3 blocks")
        let defaultBlockSize = 1024 * 1024 
        var blockStart: Int = 0
        var blockID: UInt32 = 0
        let writingProgress = ProgressEx()
        writingProgress.localizedAdditionalDescription = NSLocalizedString("Writing encrypted blocks", comment: "Status message")
        writingProgress.totalUnitCount = Int64(inData.count)
        progress.addChild(writingProgress, withPendingUnitCount: ProgressSteps.writingBlocks)
        while blockStart != inData.count {
            let blockSize = min(defaultBlockSize, inData.count - blockStart)
            let blockData = inData[blockStart..<blockStart+blockSize]
            
            stream.write(value: UInt32(blockID))
            stream.write(data: blockData.sha256)
            stream.write(value: UInt32(blockData.count))
            stream.write(data: blockData)
            blockStart += blockSize
            blockID += 1
            writingProgress.completedUnitCount += Int64(blockSize)
            if writingProgress.isCancelled {
                throw ProgressInterruption.cancelled(reason: writingProgress.cancellationReason)
            }
        }
        stream.write(value: UInt32(blockID))
        stream.write(data: ByteArray(count: SHA256_SIZE))
        stream.write(value: UInt32(0))
        stream.write(data: ByteArray(count: 0))
        writingProgress.completedUnitCount = writingProgress.totalUnitCount
    }
    
    func toXml() throws -> AEXMLDocument {
        Diag.debug("Will generate XML")
        var options = AEXMLOptions()
        options.documentHeader.encoding = "utf-8"
        options.documentHeader.standalone = "yes"
        options.documentHeader.version = 1.0
        
        let xmlMain = AEXMLElement(name: Xml2.keePassFile)
        let xmlDoc = AEXMLDocument(root: xmlMain, options: options)
        xmlMain.addChild(try meta.toXml(streamCipher: header.streamCipher))
        Diag.verbose("XML generation: Meta OK")
        
        let xmlRoot = xmlMain.addChild(name: Xml2.root)
        let root2 = root! as! Group2
        xmlRoot.addChild(try root2.toXml(streamCipher: header.streamCipher))
        Diag.verbose("XML generation: Root group OK")
        
        let xmlDeletedObjects = xmlRoot.addChild(name: Xml2.deletedObjects)
        for deletedObject in deletedObjects {
            xmlDeletedObjects.addChild(deletedObject.toXml())
        }
        return xmlDoc
    }
    
    func setAllTimestamps(to time: Date) {
        meta.setAllTimestamps(to: time)
        
        guard let root = root else { return }
        var groups: [Group] = [root]
        var entries: [Entry] = []
        root.collectAllChildren(groups: &groups, entries: &entries)
        for group in groups {
            group.creationTime = time
            group.lastAccessTime = time
            group.lastModificationTime = time
        }
        for entry in entries {
            entry.creationTime = time
            entry.lastModificationTime = time
            entry.lastAccessTime = time
        }
    }
    
    
    override public func delete(group: Group) {
        guard let group = group as? Group2 else { fatalError() }
        guard let parentGroup = group.parent else {
            Diag.warning("Cannot delete group: no parent group")
            return
        }
        
        var subGroups = [Group]()
        var subEntries = [Entry]()
        group.collectAllChildren(groups: &subGroups, entries: &subEntries)
        
        let moveOnly = !group.isDeleted && meta.isRecycleBinEnabled
        if moveOnly, let backupGroup = getBackupGroup(createIfMissing: meta.isRecycleBinEnabled) {
            Diag.debug("Moving group to RecycleBin")
            parentGroup.remove(group: group)
            backupGroup.add(group: group)
            group.accessed()
            group.locationChangedTime = Date.now
            
            group.isDeleted = true
            subGroups.forEach { $0.isDeleted = true }
            subEntries.forEach { $0.isDeleted = true }
        } else {
            Diag.debug("Removing the group permanently.")
            if group === getBackupGroup(createIfMissing: false) {
                meta?.resetRecycleBinGroupUUID()
            }
            addDeletedObject(uuid: group.uuid)
            subGroups.forEach { addDeletedObject(uuid: $0.uuid) }
            subEntries.forEach { addDeletedObject(uuid: $0.uuid) }
            parentGroup.remove(group: group)
        }
        Diag.debug("Delete group OK")
    }
    
    override public func delete(entry: Entry) {
        guard let parentGroup = entry.parent else {
            Diag.warning("Cannot delete entry: no parent group")
            return
        }
        
        if entry.isDeleted {
            addDeletedObject(uuid: entry.uuid)
            parentGroup.remove(entry: entry)
            return
        }
        
        if meta.isRecycleBinEnabled,
            let backupGroup = getBackupGroup(createIfMissing: meta.isRecycleBinEnabled)
        {
            entry.accessed()
            backupGroup.moveEntry(entry: entry)
        } else {
            Diag.debug("Backup disabled, removing permanently.")
            addDeletedObject(uuid: entry.uuid)
            parentGroup.remove(entry: entry)
        }
        Diag.debug("Delete entry OK")
    }
    
    override public func makeAttachment(name: String, data: ByteArray) -> Attachment {
        let attemptCompression = header.isCompressed
        
        if attemptCompression {
            do {
                let compressedData = try data.gzipped()
                return Attachment2(name: name, isCompressed: true, data: compressedData)
            } catch {
                Diag.warning("Failed to compress attachment data [message: \(error.localizedDescription)]")
            }
        }

        return Attachment2(name: name, isCompressed: false, data: data)
    }
}
