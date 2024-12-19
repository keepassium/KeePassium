//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class Database2: Database {
    typealias XMLTimeFormatter = (_ date: Date) -> String
    typealias XMLTimeParser = (_ string: String?) -> Date?

    public enum FormatVersion: Comparable, CustomStringConvertible {
        case v3
        case v4
        case v4_1

        public var description: String {
            switch self {
            case .v3:
                return "kdbx3"
            case .v4:
                return "kdbx4"
            case .v4_1:
                return "kdbx4.1"
            }
        }

        public func hasMajorDifferences(with otherVersion: FormatVersion) -> Bool {
            switch (self, otherVersion) {
            case (.v3, _),
                 (_, .v3):
                return true
            case (.v4, .v4_1),
                 (.v4_1, .v4):
                return false
            default:
                return true
            }
        }
    }

    public enum FormatError: LocalizedError, Equatable {
        case prematureDataEnd
        case negativeBlockSize(blockIndex: Int)
        case parsingError(reason: String)
        case blockIDMismatch
        case blockHashMismatch(blockIndex: Int) 
        case blockHMACMismatch(blockIndex: Int) 
        case compressionError(reason: String)
        public var errorDescription: String? {
            // swiftlint:disable line_length
            switch self {
            case .prematureDataEnd:
                return NSLocalizedString(
                    "[Database2/FormatError] Unexpected end of file. Corrupted file?",
                    bundle: Bundle.framework,
                    value: "Unexpected end of file. Corrupted file?",
                    comment: "Error message")
            case .negativeBlockSize(let blockIndex):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/FormatError] Corrupted database file (block %d has negative size)",
                        bundle: Bundle.framework,
                        value: "Corrupted database file (block %d has negative size)",
                        comment: "Error message [blockIndex: Int]"),
                    blockIndex)
            case .parsingError(let reason):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/FormatError] Cannot parse database. %@",
                        bundle: Bundle.framework,
                        value: "Cannot parse database. %@",
                        comment: "Error message. Parsing refers to the analysis/understanding of file content. [reason: String]"),
                    reason)
            case .blockIDMismatch:
                return NSLocalizedString(
                    "[Database2/FormatError] Unexpected block ID.",
                    bundle: Bundle.framework,
                    value: "Unexpected block ID.",
                    comment: "Error message: wrong ID of a data block")
            case .blockHashMismatch(let blockIndex):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/FormatError] Corrupted database file (hash mismatch in block %d)",
                        bundle: Bundle.framework,
                        value: "Corrupted database file (hash mismatch in block %d)",
                        comment: "Error message: hash(checksum) of a data block is wrong. [blockIndex: Int]"),
                    blockIndex)
            case .blockHMACMismatch(let blockIndex):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/FormatError] Corrupted database file (HMAC mismatch in block %d)",
                        bundle: Bundle.framework,
                        value: "Corrupted database file (HMAC mismatch in block %d)",
                        comment: "Error message: HMAC value (kind of checksum) of a data block is wrong. [blockIndex: Int]"),
                    blockIndex)
            case .compressionError(let reason):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/FormatError] Gzip error: %@",
                        bundle: Bundle.framework,
                        value: "Gzip error: %@",
                        comment: "Error message about Gzip compression algorithm. [reason: String]"),
                    reason)
            }
            // swiftlint:enable line_length
        }
    }

    private enum ProgressSteps {
        static let all: Int64 = 100
        static let keyDerivation: Int64 = 60
        static let resolvingReferences: Int64 = 5

        static let decryption: Int64 = 20
        static let readingBlocks: Int64 = 5
        static let gzipUnpack: Int64 = 5
        static let parsing: Int64 = 5

        static let packing: Int64 = 5
        static let gzipPack: Int64 = 5
        static let encryption: Int64 = 20
        static let writingBlocks: Int64 = 5
    }

    private(set) var header: Header2!
    private(set) var meta: Meta2!
    public var formatVersion: FormatVersion { header.formatVersion }
    public var encryptionSettings: EncryptionSettings {
        EncryptionSettings(header: header)
    }
    public var binaries: [Binary2.ID: Binary2] = [:]
    public var customIcons: [CustomIcon2] { return meta.customIcons }
    public var defaultUserName: String { return meta.defaultUserName }
    private var cipherKey = SecureBytes.empty()
    private var hmacKey = SecureBytes.empty()
    private var deletedObjects: ContiguousArray<DeletedObject2> = []

    override public var keyHelper: KeyHelper { return _keyHelper }
    private let _keyHelper = KeyHelper2()

    public override var peakKDFMemoryFootprint: Int { header.peakKDFMemoryFootprint }

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
        Diag.debug("DB memory cleaned up")
    }

    internal static func makeNewV4(_ version: FormatVersion = .v4) -> Database2 {
        assert(version == .v4 || version == .v4_1, "Unexpected format version")
        let db = Database2()
        db.header.loadDefaultValuesV4(version)
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

    public func formatUpgradeRequired(for feature: DatabaseFeature2) -> FormatVersion? {
        let minimumRequiredFormat = FormatVersion.minimumRequired(for: feature)
        if minimumRequiredFormat > header.formatVersion {
            return minimumRequiredFormat
        } else {
            return nil
        }
    }

    public func formatUpgradeRequired(for settings: EncryptionSettings) -> FormatVersion? {
        switch (settings.kdf, settings.dataCipher) {
        case (.argon2d, _), (.argon2id, _), (_, .chaCha20):
            if .v4 > header.formatVersion {
                return .v4
            }
            return nil
        default:
            return nil
        }
    }

    public func upgradeFormatVersion(to newerVersion: FormatVersion) {
        header.upgradeFormatVersion(to: newerVersion)
    }

    public func applyEncryptionSettings(settings: EncryptionSettings) {
        header.applyEncryptionSettings(settings: settings)
    }

    override public class func isSignatureMatches(data: ByteArray) -> Bool {
        return Header2.isSignatureMatches(data: data)
    }

    internal func addDeletedObject(uuid: UUID) {
        let deletedObject = DeletedObject2(uuid: uuid)
        deletedObjects.append(deletedObject)
    }

    override public func load(
        dbFileName: String,
        dbFileData: ByteArray,
        compositeKey: CompositeKey,
        useStreams: Bool,
        warnings: DatabaseLoadingWarnings
    ) throws {
        Diag.info("Loading KDBX database")
        progress.completedUnitCount = 0
        progress.totalUnitCount = ProgressSteps.all
        progress.localizedDescription = LString.Progress.database2LoadingDatabase
        do {
            try header.read(data: dbFileData) 
            Diag.debug("Header read OK [format: \(header.formatVersion)]")
            Diag.verbose("== DB2 progress CP1: \(progress.completedUnitCount)")

            try deriveMasterKey(
                compositeKey: compositeKey,
                cipher: header.dataCipher,
                canUseFinalKey: true)
            Diag.debug("Key derivation OK")
            Diag.verbose("== DB2 progress CP2: \(progress.completedUnitCount)")

            var decryptedData: ByteArray
            let dbWithoutHeader: ByteArray = dbFileData.suffix(from: header.size)

            switch header.formatVersion {
            case .v3:
                decryptedData = try decryptBlocksV3(
                    data: dbWithoutHeader,
                    cipher: header.dataCipher)
            case .v4, .v4_1:
                decryptedData = try decryptBlocksV4(
                    data: dbWithoutHeader,
                    cipher: header.dataCipher)
            }
            Diag.debug("Block decryption OK")
            Diag.verbose("== DB2 progress CP3: \(progress.completedUnitCount)")

            if header.isCompressed {
                progress.localizedDescription = LString.Progress.database2DecompressingDatabase
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
            case .v4, .v4_1:
                let innerHeaderSize = try header.readInner(data: decryptedData) 
                xmlData = decryptedData.suffix(from: innerHeaderSize)
                Diag.debug("Inner header read OK")
            }

            try removeGarbageAfterXML(data: xmlData) 

            try load(xmlData: xmlData, useStreams: useStreams, warnings: warnings)
            if let backupGroup = getBackupGroup(createIfMissing: false) {
                backupGroup.deepSetDeleted(true)
            }

            progress.localizedDescription = LString.Progress.database2IntegrityCheck

            assert(root != nil)
            var allCurrentEntries = [Entry]()
            root?.collectAllEntries(to: &allCurrentEntries) 

            var allEntriesPlusHistory = [Entry]()
            allEntriesPlusHistory.reserveCapacity(allCurrentEntries.count * 4) 
            allCurrentEntries.forEach { entry in
                allEntriesPlusHistory.append(entry)
                guard let entry2 = entry as? Entry2 else { assertionFailure(); return }
                allEntriesPlusHistory.append(contentsOf: entry2.history)
            }

            resolveReferences(
                allEntries: allEntriesPlusHistory,
                parentProgress: progress,
                pendingProgressUnits: ProgressSteps.resolvingReferences
            )

            checkAttachmentsIntegrity(allEntries: allCurrentEntries, warnings: warnings)

            checkCustomFieldsIntegrity(allEntries: allCurrentEntries, warnings: warnings)

            Diag.debug("Content loaded OK")
            Diag.verbose("== DB2 progress CP5: \(progress.completedUnitCount)")
        } catch let error as Header2.HeaderError {
            Diag.error("Header error [reason: \(error.localizedDescription)]")
            throw DatabaseError.loadError(
                reason: .headerError(reason: error.localizedDescription)
            )
        } catch let error as CryptoError {
            Diag.error("Crypto error [reason: \(error.localizedDescription)]")
            throw DatabaseError.loadError(reason: .cryptoError(error))
        } catch let error as KeyFileError {
            Diag.error("Key file error [reason: \(error.localizedDescription)]")
            throw DatabaseError.loadError(reason: .keyFileError(error))
        } catch let error as ChallengeResponseError {
            Diag.error("Challenge-response error [reason: \(error.localizedDescription)]")
            throw DatabaseError.loadError(reason: .challengeResponseError(error))
        } catch let error as FormatError {
            Diag.error("Format error [reason: \(error.localizedDescription)]")
            throw DatabaseError.loadError(
                reason: .formatError(reason: error.localizedDescription)
            )
        } catch let error as GzipError {
            Diag.error("Gzip error [kind: \(error.kind), message: \(error.message)]")
            let reason = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Database2/Loading/Error] Error unpacking database: %@",
                    bundle: Bundle.framework,
                    value: "Error unpacking database: %@",
                    comment: "Error message about Gzip compression algorithm. [errorMessage: String]"),
                error.localizedDescription)
            throw DatabaseError.loadError(reason: .gzipError(reason: reason))
        }

        self.compositeKey = compositeKey
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
        readingProgress.localizedDescription = LString.Progress.database2ReadingContent
        progress.addChild(readingProgress, withPendingUnitCount: ProgressSteps.readingBlocks)

        var blockIndex: UInt64 = 0
        while true {
            guard let storedBlockHMAC = inStream.read(count: SHA256_SIZE) else {
                throw FormatError.prematureDataEnd
            }
            #if DEBUG
            print("Stored block HMAC: \(storedBlockHMAC.asHexString)")
            #endif
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

        #if DEBUG
        hmacKey.withDecryptedByteArray {
            print("hmacKey plain: \($0.asHexString)")
        }
        print("hmacKey enc: \(hmacKey.description)")

        cipherKey.withDecryptedByteArray {
            print("cipherKey plain: \($0.asHexString)")
        }
        print("cipherKey enc: \(cipherKey.description)")
        #endif

        let decryptedData = try cipher.decrypt(
            cipherText: allBlocksData,
            key: cipherKey,
            iv: SecureBytes.from(header.initialVector)
        ) 
        Diag.verbose("Decrypted \(decryptedData.count) bytes")

        return decryptedData
    }

    func decryptBlocksV3(data: ByteArray, cipher: DataCipher) throws -> ByteArray {
        Diag.debug("Decrypting V3 blocks")
        progress.addChild(cipher.initProgress(), withPendingUnitCount: ProgressSteps.decryption)
        let decryptedData = try cipher.decrypt(
            cipherText: data,
            key: cipherKey,
            iv: SecureBytes.from(header.initialVector)) 
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
        readingProgress.localizedDescription = LString.Progress.database2ReadingContent
        progress.addChild(readingProgress, withPendingUnitCount: ProgressSteps.readingBlocks)
        while true {
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
        var closingTagIndex: Int?
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

    func deriveMasterKey(compositeKey: CompositeKey, cipher: DataCipher, canUseFinalKey: Bool) throws {
        Diag.debug("Start key derivation")

        if canUseFinalKey,
           compositeKey.state == .final,
           let _cipherKey = compositeKey.cipherKey, 
           let _hmacKey = compositeKey.finalKey
        {
            self.cipherKey = _cipherKey
            self.hmacKey = _hmacKey
            progress.completedUnitCount += ProgressSteps.keyDerivation
            return
        }

        progress.addChild(header.kdf.initProgress(), withPendingUnitCount: ProgressSteps.keyDerivation)
        var combinedComponents: SecureBytes
        if compositeKey.state == .processedComponents {
            combinedComponents = try keyHelper.combineComponents(
                passwordData: compositeKey.passwordData!, 
                keyFileData: compositeKey.keyFileData!    
            ) 
            compositeKey.setCombinedStaticComponents(combinedComponents)
        } else if compositeKey.state >= .combinedComponents {
            combinedComponents = compositeKey.combinedStaticComponents! 
        } else {
            preconditionFailure("Unexpected key state")
        }

        let secureMasterSeed = SecureBytes.from(header.masterSeed)
        let joinedKey: SecureBytes
        switch header.formatVersion {
        case .v3:

            let keyToTransform = keyHelper.getKey(fromCombinedComponents: combinedComponents)

            let transformedKey = try header.kdf.transform(
                key: keyToTransform,
                params: header.kdfParams)

            let challengeResponse = try compositeKey.getResponse(challenge: secureMasterSeed) 
            joinedKey = SecureBytes.concat(secureMasterSeed, challengeResponse, transformedKey)
        case .v4, .v4_1:

            let challenge = try header.kdf.getChallenge(header.kdfParams) 
            let secureChallenge = SecureBytes.from(challenge)

            let challengeResponse = try compositeKey.getResponse(challenge: secureChallenge) 
            combinedComponents = SecureBytes.concat(combinedComponents, challengeResponse)

            let keyToTransform = keyHelper.getKey(fromCombinedComponents: combinedComponents)

            let transformedKey = try header.kdf.transform(
                key: keyToTransform,
                params: header.kdfParams)
            joinedKey = SecureBytes.concat(secureMasterSeed, transformedKey)
        }
        self.cipherKey = cipher.resizeKey(key: joinedKey)
        let one = SecureBytes.from([1])
        self.hmacKey = SecureBytes.concat(joinedKey, one).sha512
        compositeKey.setFinalKeys(hmacKey, cipherKey)
    }

    override public func changeCompositeKey(to newKey: CompositeKey) {
        compositeKey = newKey.clone()
        meta.masterKeyChangedTime = Date.now
        meta.masterKeyChangeForceOnce = false
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
            backupGroup.isDeleted = true
            backupGroup.isSearchingEnabled = false
            backupGroup.isAutoTypeEnabled = false
            Diag.verbose("RecycleBin group created")
            return backupGroup
        }
        Diag.verbose("RecycleBin group not found nor created.")
        return nil
    }


    func checkAttachmentsIntegrity(allEntries: [Entry], warnings: DatabaseLoadingWarnings) {
        func mapAttachmentNamesByID(of entry: Entry2, nameByID: inout [Binary2.ID: String]) {
            (entry.attachments as! [Attachment2]).forEach { attachment in
                nameByID[attachment.id] = attachment.name
            }
            entry.history.forEach { historyEntry in
                mapAttachmentNamesByID(of: historyEntry, nameByID: &nameByID)
            }
        }

        func insertAllAttachmentIDs(of entry: Entry2, into ids: inout Set<Binary2.ID>) {
            let attachments2 = entry.attachments as! [Attachment2]
            ids.formUnion(attachments2.map { $0.id })
            entry.history.forEach { historyEntry in
                insertAllAttachmentIDs(of: historyEntry, into: &ids)
            }
        }

        maybeFixAttachmentNames(entries: allEntries, warnings: warnings)

        var usedIDs = Set<Binary2.ID>() 
        allEntries.forEach { entry in
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
            warnings.addIssue(.unusedAttachments)

            let unusedIDs = unusedBinaries
                .map { String($0) }
                .joined(separator: ", ")
            Diag.warning("Some binaries are not referenced from any entry [IDs: \(unusedIDs)]")
        }

        if missingBinaries.count > 0 {

            var attachmentNameByID = [Binary2.ID: String]()
            allEntries.forEach { entry in
                mapAttachmentNamesByID(of: entry as! Entry2, nameByID: &attachmentNameByID)
            }
            let attachmentNames = missingBinaries.compactMap { attachmentNameByID[$0] }
            warnings.addIssue(.missingBinaries(attachmentNames: attachmentNames))

            let missingIDs = missingBinaries
                .map { String($0) }
                .joined(separator: ", ")
            Diag.warning("Some entries refer to non-existent binaries [IDs: \(missingIDs)]")
        }
    }

    private func maybeFixAttachmentNames(entries: [Entry], warnings: DatabaseLoadingWarnings) {
        func maybeFixAttachmentNames(entry: Entry2) -> Bool {
            var isSomethingFixed = false
            entry.attachments.forEach {
                if $0.name.isEmpty {
                    $0.name = "?" 
                    isSomethingFixed = true
                }
            }
            return isSomethingFixed
        }

        var affectedEntries = [Entry2]()
        for entry in entries {
            let entry2 = entry as! Entry2
            let isEntryAffected = maybeFixAttachmentNames(entry: entry2)
            let isHistoryAffected = entry2.history.contains { historyEntry in
                return maybeFixAttachmentNames(entry: historyEntry)
            }
            if isEntryAffected || isHistoryAffected {
                affectedEntries.append(entry2)
            }
        }

        if affectedEntries.isEmpty {
            return
        }

        let entryNames = affectedEntries.compactMap { $0.getGroupPath() + "/" + $0.resolvedTitle }
        let issue = DatabaseLoadingWarnings.IssueType.namelessAttachments(entryNames: entryNames)
        warnings.addIssue(issue)
        Diag.warning(warnings.getDescription(for: issue))
    }

    private func checkCustomFieldsIntegrity(allEntries: [Entry], warnings: DatabaseLoadingWarnings) {
        let problematicEntries = allEntries.filter { entry in
            let isProblematicEntry = entry.fields.contains { $0.name.isEmpty }
            return isProblematicEntry
        }
        guard problematicEntries.count > 0 else { return }

        let entryPaths = problematicEntries
            .map { "'\($0.resolvedTitle)' in '\($0.getGroupPath())'" }
        warnings.addIssue(.namelessCustomFields(entryPaths: entryPaths))
    }

    private func updateBinaries(root: Group2) {
        Diag.verbose("Updating all binaries")

        var oldBinaryPoolInverse = [ByteArray: Binary2]()
        binaries.values.forEach { oldBinaryPoolInverse[$0.data] = $0 }

        var newBinaryPoolInverse = [ByteArray: Binary2]()
        root.applyToAllChildren(
            groupHandler: nil,
            entryHandler: { [self] entry in
                updateBinaries(
                    entry: entry as! Entry2,
                    oldPoolInverse: oldBinaryPoolInverse,
                    newPoolInverse: &newBinaryPoolInverse
                )
            }
        )
        binaries.removeAll()
        newBinaryPoolInverse.values.forEach { binaries[$0.id] = $0 }
    }

    private func updateBinaries(
        entry: Entry2,
        oldPoolInverse: [ByteArray: Binary2],
        newPoolInverse: inout [ByteArray: Binary2]
    ) {
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
                binaryInOldPool.isCompressed == att2.isCompressed {
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
                    isProtected: !att2.isCompressed
                )
            }
            newPoolInverse[newBinary.data] = newBinary
            att2.id = newID
        }
    }

    override public func save() throws -> ByteArray {
        Diag.info("Saving KDBX database")
        assert(root != nil, "Load or create a DB before saving.")

        progress.totalUnitCount = ProgressSteps.all
        progress.completedUnitCount = 0
        header.maybeUpdateFormatVersion()
        let formatVersion = header.formatVersion
        Diag.debug("Format version: \(formatVersion)")
        do {
            try header.randomizeSeeds() 
            Diag.debug("Seeds randomized OK")
            try deriveMasterKey(
                compositeKey: compositeKey,
                cipher: header.dataCipher,
                canUseFinalKey: false)
            Diag.debug("Key derivation OK")
        } catch let error as CryptoError {
            Diag.error("Crypto error [reason: \(error.localizedDescription)]")
            throw DatabaseError.saveError(reason: error.localizedDescription)
        } catch let error as KeyFileError {
            Diag.error("Key file error [reason: \(error.localizedDescription)]")
            throw DatabaseError.saveError(reason: error.localizedDescription)
        } catch let error as ChallengeResponseError {
            Diag.error("Challenge-response error [reason: \(error.localizedDescription)]")
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
        let timeFormatter = getTimeFormatter(for: formatVersion)
        let xmlString = try self.toXml(timeFormatter: timeFormatter).xml
        let xmlData = ByteArray(utf8String: xmlString)
        Diag.debug("XML generation OK")

        switch formatVersion {
        case .v3:
            try encryptBlocksV3(to: outStream, xmlData: xmlData) 
        case .v4, .v4_1:
            try encryptBlocksV4(to: outStream, xmlData: xmlData) 
        }
        Diag.debug("Content encryption OK")

        var allEntries = [Entry]()
        root?.collectAllEntries(to: &allEntries)
        resolveReferences(
            allEntries: allEntries,
            parentProgress: progress,
            pendingProgressUnits: ProgressSteps.resolvingReferences
        )

        progress.completedUnitCount = progress.totalUnitCount
        return outStream.data!
    }

    internal func encryptBlocksV4(to outStream: ByteArray.OutputStream, xmlData: ByteArray) throws {
        Diag.debug("Encrypting kdbx4 blocks")
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
                iv: SecureBytes.from(header.initialVector)) 
            Diag.verbose("Encrypted \(encData.count) bytes")

            try writeAsBlocksV4(to: outStream, data: encData) 
            Diag.verbose("Blocks written OK")
        } catch let error as Header2.HeaderError {
            Diag.error("Header error [message: \(error.localizedDescription)]")
            throw DatabaseError.saveError(reason: error.localizedDescription)
        } catch let error as GzipError {
            Diag.error("Gzip error [kind: \(error.kind), message: \(error.message)]")
            let errMsg = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Database2/Saving/Error] Data compression error: %@",
                    bundle: Bundle.framework,
                    value: "Data compression error: %@",
                    comment: "Error message while saving a database. [errorDescription: String]"),
                error.localizedDescription)
            throw DatabaseError.saveError(reason: errMsg)
        } catch let error as CryptoError {
            Diag.error("Crypto error [reason: \(error.localizedDescription)]")
            let errMsg = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Database2/Saving/Error] Encryption error: %@",
                    bundle: Bundle.framework,
                    value: "Encryption error: %@",
                    comment: "Error message while saving a database. [errorDescription: String]"),
                error.localizedDescription)
            throw DatabaseError.saveError(reason: errMsg)
        }
    }

    internal func writeAsBlocksV4(to blockStream: ByteArray.OutputStream, data: ByteArray) throws {
        Diag.debug("Writing kdbx4 blocks")
        let defaultBlockSize = 1024 * 1024 
        var blockStart: Int = 0
        var blockIndex: UInt64 = 0

        let writeProgress = ProgressEx()
        writeProgress.totalUnitCount = Int64(data.count)
        writeProgress.localizedDescription = LString.Progress.database2WritingBlocks
        progress.addChild(writeProgress, withPendingUnitCount: ProgressSteps.writingBlocks)

        Diag.verbose("\(data.count) bytes to write")
        while blockStart != data.count {
            let blockSize = min(defaultBlockSize, data.count - blockStart)
            let blockData = data[blockStart..<(blockStart + blockSize)]

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
        Diag.debug("Encrypting kdbx3 blocks")
        let dataToSplit: ByteArray
        if header.isCompressed {
            do {
                dataToSplit = try xmlData.gzipped()
                Diag.verbose("Gzip compression OK")
            } catch let error as GzipError {
                Diag.error("Gzip error [kind: \(error.kind), message: \(error.message)]")
                let errMsg = String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/Saving/Error] Data compression error: %@",
                        bundle: Bundle.framework,
                        value: "Data compression error: %@",
                        comment: "Error message while saving a database. [errorDescription: String]"),
                    error.localizedDescription)
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
                iv: SecureBytes.from(header.initialVector)) 
            outStream.write(data: encryptedData)
            Diag.verbose("Encryption OK")
        } catch let error as CryptoError {
            Diag.error("Crypto error [message: \(error.localizedDescription)]")
            let errMsg = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Database2/Saving/Error] Encryption error: %@",
                    bundle: Bundle.framework,
                    value: "Encryption error: %@",
                    comment: "Error message while saving a database. [errorDescription: String]"),
                error.localizedDescription)

            throw DatabaseError.saveError(reason: errMsg)
        }
    }

    internal func splitToBlocksV3(to stream: ByteArray.OutputStream, data inData: ByteArray) throws {
        Diag.verbose("Will split to kdbx3 blocks")
        let defaultBlockSize = 1024 * 1024 
        var blockStart: Int = 0
        var blockID: UInt32 = 0
        let writingProgress = ProgressEx()
        writingProgress.localizedDescription = LString.Progress.database2WritingBlocks
        writingProgress.totalUnitCount = Int64(inData.count)
        progress.addChild(writingProgress, withPendingUnitCount: ProgressSteps.writingBlocks)
        while blockStart != inData.count {
            let blockSize = min(defaultBlockSize, inData.count - blockStart)
            let blockData = inData[blockStart..<(blockStart + blockSize)]

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

    func toXml(timeFormatter: XMLTimeFormatter) throws -> AEXMLDocument {
        Diag.debug("Will generate XML")
        var options = AEXMLOptions()
        options.documentHeader.encoding = "utf-8"
        options.documentHeader.standalone = "yes"
        options.documentHeader.version = 1.0

        let xmlMain = AEXMLElement(name: Xml2.keePassFile)
        let xmlDoc = AEXMLDocument(root: xmlMain, options: options)
        xmlMain.addChild(
            try meta.toXml(
                streamCipher: header.streamCipher,
                formatVersion: header.formatVersion,
                timeFormatter: timeFormatter
            )
        ) 
        Diag.verbose("XML generation: Meta OK")

        let xmlRoot = xmlMain.addChild(name: Xml2.root)
        let root2 = root! as! Group2
        let rootXML = try root2.toXml(
            formatVersion: header.formatVersion,
            streamCipher: header.streamCipher,
            timeFormatter: timeFormatter
        ) 
        xmlRoot.addChild(rootXML)
        Diag.verbose("XML generation: Root group OK")

        let xmlDeletedObjects = xmlRoot.addChild(name: Xml2.deletedObjects)
        for deletedObject in deletedObjects {
            xmlDeletedObjects.addChild(deletedObject.toXml(timeFormatter: timeFormatter))
        }
        return xmlDoc
    }

    func setAllTimestamps(to time: Date) {
        meta.setAllTimestamps(to: time)

        guard let root else { return }
        root.applyToAllChildren(
            includeSelf: true,
            groupHandler: { group in
                group.creationTime = time
                group.lastAccessTime = time
                group.lastModificationTime = time
            },
            entryHandler: { entry in
                entry.creationTime = time
                entry.lastModificationTime = time
                entry.lastAccessTime = time
            }
        )
    }


    override public func delete(group: Group) {
        guard let group = group as? Group2 else { fatalError() }
        guard let parentGroup = group.parent else {
            Diag.warning("Cannot delete group: no parent group")
            return
        }

        let moveOnly = !group.isDeleted && meta.isRecycleBinEnabled
        if moveOnly,
           let backupGroup = getBackupGroup(createIfMissing: meta.isRecycleBinEnabled)
        {
            Diag.debug("Moving group to RecycleBin")
            group.move(to: backupGroup) 
            group.touch(.accessed, updateParents: false)

            group.isDeleted = true
            group.applyToAllChildren(
                groupHandler: { $0.isDeleted = true },
                entryHandler: { $0.isDeleted = true })
        } else {
            Diag.debug("Removing the group permanently.")
            if group === getBackupGroup(createIfMissing: false) {
                meta?.resetRecycleBinGroupUUID()
            }
            addDeletedObject(uuid: group.uuid)
            group.applyToAllChildren(
                groupHandler: { self.addDeletedObject(uuid: $0.uuid) },
                entryHandler: { self.addDeletedObject(uuid: $0.uuid) })
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
            Diag.debug("Already in Backup, removing permanently")
            addDeletedObject(uuid: entry.uuid)
            parentGroup.remove(entry: entry)
            return
        }

        if meta.isRecycleBinEnabled,
           let backupGroup = getBackupGroup(createIfMissing: meta.isRecycleBinEnabled)
        {
            entry.move(to: backupGroup) 
            entry.touch(.accessed)
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


    public func setCustomIcon(_ icon: CustomIcon2, for entry: Entry2) {
        entry.backupState()
        entry.customIconUUID = icon.uuid
        entry.touch(.accessed)
        entry.touch(.modified, updateParents: false)
    }

    public func setCustomIcon(_ icon: CustomIcon2, for group: Group2) {
        group.customIconUUID = icon.uuid
        group.touch(.accessed)
        group.touch(.modified, updateParents: false)
    }

    public func addCustomIcon(_ image: UIImage) -> CustomIcon2? {
        guard let normalizedImage = image.downscalingToSquare(maxSidePixels: CustomIcon2.maxSidePixels) else {
            Diag.error("Failed to normalize the image, cancelling")
            return nil
        }
        guard let pngData = normalizedImage.pngData() else {
            Diag.warning("Failed to get image's PNG data, cancelling")
            return nil
        }
        return addCustomIcon(pngData: ByteArray(data: pngData))
    }

    public func addCustomIcon(pngData: ByteArray) -> CustomIcon2 {
        if let existingIcon = findCustomIcon(pngDataSha256: pngData.sha256) {
            return existingIcon
        }

        let newCustomIcon = CustomIcon2(uuid: UUID(), data: pngData)
        meta.addCustomIcon(newCustomIcon)
        Diag.debug("Custom icon added OK")
        return newCustomIcon
    }

    public func findCustomIcon(pngDataSha256: ByteArray) -> CustomIcon2? {
        return customIcons.first(where: { $0.data.sha256 == pngDataSha256 })
    }

    public func getCustomIcon(with uuid: UUID) -> CustomIcon2? {
        return customIcons.first(where: { $0.uuid == uuid })
    }

    @discardableResult
    public func deleteCustomIcon(uuid: UUID) -> Bool {
        guard customIcons.contains(where: { $0.uuid == uuid }) else {
            Diag.warning("Tried to delete non-existent custom icon")
            return false
        }
        meta.deleteCustomIcon(uuid: uuid)
        deletedObjects.append(DeletedObject2(uuid: uuid))
        removeUnusedCustomIconRefs()
        Diag.debug("Custom icon deleted OK")
        return true
    }

    private func removeUnusedCustomIconRefs() {
        let knownIconUUIDs = Set<UUID>(customIcons.map { $0.uuid })
        root?.applyToAllChildren(
            includeSelf: true,
            groupHandler: { group in
                (group as! Group2).enforceCustomIconUUID(isValid: knownIconUUIDs)
            },
            entryHandler: { entry in
                (entry as! Entry2).enforceCustomIconUUID(isValid: knownIconUUIDs)
            }
        )
    }

    public func setPasskey(_ passkey: Passkey, for entry: Entry2) {
        entry.backupState()
        passkey.apply(to: entry)
        entry.touch(.accessed)
        entry.touch(.modified, updateParents: false)
    }
}

extension Database2 {
    private func getTimeParser(for formatVersion: FormatVersion) -> XMLTimeParser {
        switch formatVersion {
        case .v3:
            return Self.xmlStringToDateV3
        case .v4, .v4_1:
            return Self.xmlStringToDateV4
        }
    }

    static private func xmlStringToDateV3(_ string: String?) -> Date? {
        let trimmedString = string?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let formatAppropriateDate = Date(iso8601string: trimmedString) {
            return formatAppropriateDate
        }
        if let altFormatDate = Date(base64Encoded: trimmedString) {
            Diag.warning("Found Base64-formatted timestamp in v3 DB.")
            return altFormatDate
        }
        return nil
    }

    static private func xmlStringToDateV4(_ string: String?) -> Date? {
        let trimmedString = string?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let formatAppropriateDate = Date(base64Encoded: trimmedString) {
            return formatAppropriateDate
        }
        if let altFormatDate = Date(iso8601string: trimmedString) {
            Diag.warning("Found ISO8601-formatted timestamp in v4 DB.")
            return altFormatDate
        }
        return nil
    }

    private func getTimeFormatter(for formatVersion: FormatVersion) -> XMLTimeFormatter {
        switch formatVersion {
        case .v3:
            return Self.dateToXMLStringV3
        case .v4, .v4_1:
            return Self.dateToXMLStringV4
        }
    }
    static private func dateToXMLStringV3(_ date: Date) -> String {
        return date.iso8601String()
    }
    static private func dateToXMLStringV4(_ date: Date) -> String {
        return date.base64EncodedString()
    }
}

extension Database2 {
    internal func load(
        xmlData: ByteArray,
        useStreams: Bool,
        warnings: DatabaseLoadingWarnings
    ) throws {
        do {
            progress.localizedDescription = LString.Progress.database2ParsingXML
            let timeParser = getTimeParser(for: formatVersion)

            let startTime = Date.now
            if useStreams {
                try loadAsStream(xmlData: xmlData, timeParser: timeParser, progress: progress, warnings: warnings)
            } else {
                try loadAsDOM(xmlData: xmlData, timeParser: timeParser, warnings: warnings)
            }
            let timeSpent = Date.now.timeIntervalSince(startTime)
            Diag.info(String(format: "XML loaded in %.4f s", timeSpent))

            progress.completedUnitCount += ProgressSteps.parsing

            Diag.debug("XML content loaded OK")
        } catch let error as Header2.HeaderError {
            Diag.error("Header error [reason: \(error.localizedDescription)]")
            if Diag.isDeepDebugMode() {
                header.protectedStreamKey?.withDecryptedByteArray {
                    Diag.debug("Inner encryption key: `\($0.asHexString)`")
                }
            }
            throw FormatError.parsingError(reason: error.localizedDescription)
        } catch let error as Xml2.ParsingError {
            Diag.error("XML parsing error [reason: \(error.localizedDescription)]")
            throw FormatError.parsingError(reason: error.localizedDescription)
        } catch let error as AEXMLError {
            Diag.error("Raw XML parsing error [reason: \(error.localizedDescription)]")
            throw FormatError.parsingError(reason: error.localizedDescription)
        }
    }
}

extension Database2 {
    private func loadAsDOM(
        xmlData: ByteArray,
        timeParser: XMLTimeParser,
        warnings: DatabaseLoadingWarnings
    ) throws {
        Diag.debug("Parsing XML (DOM)")

        var parsingOptions = AEXMLOptions()
        parsingOptions.documentHeader.standalone = "yes"
        parsingOptions.parserSettings.shouldTrimWhitespace = false

        let xmlDoc = try AEXMLDocument(xml: xmlData.asData, options: parsingOptions)
        if let xmlError = xmlDoc.error {
            Diag.error("Cannot parse XML: \(xmlError.localizedDescription)")
            throw Xml2.ParsingError.xmlError(details: xmlError.localizedDescription)
        }
        guard xmlDoc.root.name == Xml2.keePassFile else {
            Diag.error("Not a KeePass XML document [xmlRoot: \(xmlDoc.root.name)]")
            throw Xml2.ParsingError.unexpectedTag(actual: xmlDoc.root.name, expected: Xml2.keePassFile)
        }

        let rootGroup = Group2(database: self)
        rootGroup.parent = nil

        for tag in xmlDoc.root.children {
            switch tag.name {
            case Xml2.meta:
                try meta.load(
                    xml: tag,
                    formatVersion: header.formatVersion,
                    streamCipher: header.streamCipher,
                    timeParser: timeParser,
                    warnings: warnings
                )

                if meta.headerHash != nil && (header.hash != meta.headerHash!) {
                    Diag.error("kdbx3 meta meta hash mismatch")
                    throw Header2.HeaderError.hashMismatch
                }
                Diag.verbose("Meta loaded OK")
            case Xml2.root:
                try loadRoot(
                    xml: tag,
                    root: rootGroup,
                    timeParser: timeParser,
                    warnings: warnings
                )
                Diag.verbose("XML root loaded OK")
            default:
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "KeePassFile/*")
            }
        }
        self.root = rootGroup
    }

    private func loadRoot(
        xml: AEXMLElement,
        root: Group2,
        timeParser: XMLTimeParser,
        warnings: DatabaseLoadingWarnings
    ) throws {
        assert(xml.name == Xml2.root)
        Diag.debug("Loading XML root")
        for tag in xml.children {
            switch tag.name {
            case Xml2.group:
                try root.load(
                    xml: tag,
                    formatVersion: header.formatVersion,
                    streamCipher: header.streamCipher,
                    timeParser: timeParser,
                    warnings: warnings
                )
            case Xml2.deletedObjects:
                try loadDeletedObjects(xml: tag, timeParser: timeParser)
            default:
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Root/*")
            }
        }
    }

    private func loadDeletedObjects(
        xml: AEXMLElement,
        timeParser: XMLTimeParser
    ) throws {
        assert(xml.name == Xml2.deletedObjects)
        for tag in xml.children {
            switch tag.name {
            case Xml2.deletedObject:
                let deletedObject = DeletedObject2()
                try deletedObject.load(xml: tag, timeParser: timeParser)
                deletedObjects.append(deletedObject)
            default:
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "DeletedObjects/*")
            }
        }
    }
}

typealias DatabaseXMLParserStream = XMLParserStream<Database2.DocumentParsingContext>

extension Database2 {
    final class DocumentParsingContext: XMLDocumentContext {
        var formatVersion: Database2.FormatVersion
        var streamCipher: StreamCipher
        var timeParser: XMLTimeParser
        var progress: ProgressEx
        var warnings: DatabaseLoadingWarnings

        init(
            formatVersion: Database2.FormatVersion,
            streamCipher: StreamCipher,
            timeParser: @escaping XMLTimeParser,
            progress: ProgressEx,
            warnings: DatabaseLoadingWarnings
        ) {
            self.formatVersion = formatVersion
            self.streamCipher = streamCipher
            self.timeParser = timeParser
            self.progress = progress
            self.warnings = warnings
        }
    }

    final class ParsingContext: XMLReaderContext {
        var isKeePassFile = false
        var isRootLoaded = false
        var isRootGroupLoaded = false
    }

    private func loadAsStream(
        xmlData: ByteArray,
        timeParser: @escaping XMLTimeParser,
        progress: ProgressEx,
        warnings: DatabaseLoadingWarnings
    ) throws {
        Diag.debug("Parsing XML (stream)")
        let docContext = DocumentParsingContext(
            formatVersion: header.formatVersion,
            streamCipher: header.streamCipher,
            timeParser: timeParser,
            progress: progress,
            warnings: warnings
        )
        let docParser = XMLDocumentReader(xmlData: xmlData.asData, documentContext: docContext)
        let readerContext = ParsingContext()
        docParser.pushReader(parseKeePassFileElement, context: readerContext)
        do {
            try docParser.parse()
            guard readerContext.isKeePassFile else {
                docParser.popReader()
                Diag.error("XML does not contain any elements, cancelling")
                throw Xml2.ParsingError.unexpectedTag(actual: "nil", expected: Xml2.keePassFile)
            }
        } catch let xmlError as NSError where (xmlError.domain == XMLParser.errorDomain) {
            let parserMessage = xmlError.userInfo["NSXMLParserErrorMessage"] as? String
            let detailedMessage = [parserMessage, xmlError.description]
                .compactMap { $0 }
                .joined()
            Diag.error("Failed to parse XML: \(detailedMessage)")
            throw Xml2.ParsingError.xmlError(details: xmlError.localizedDescription)
        }
    }

    private func parseKeePassFileElement(_ xml: DatabaseXMLParserStream) throws {
        let context = xml.readerContext as! ParsingContext
        switch (xml.name, xml.event) {
        case (Xml2.keePassFile, .start):
            context.isKeePassFile = true
        case (Xml2.meta, .start):
            try meta.loadFromXML(xml)
        case (Xml2.root, .start):
            try xml.pushReader(parseRootElement, context: context)
        case (Xml2.keePassFile, .end):
            guard context.isRootLoaded else {
                Diag.error("No Root element found, cancelling")
                throw Xml2.ParsingError.unexpectedTag(actual: "/KeePassFile", expected: "Root")
            }
            Diag.verbose("XML file loaded OK")
            xml.popReader()
        default:
            throw Xml2.ParsingError.unexpectedTag(
                actual: xml.name,
                expected: context.isKeePassFile ? "KeePassFile/*" : "KeePassFile"
            )
        }
    }

    private func parseRootElement(_ xml: DatabaseXMLParserStream) throws {
        let context = xml.readerContext as! ParsingContext
        switch (xml.name, xml.event) {
        case (Xml2.root, .start):
            Diag.verbose("Loading XML: root")
            guard !context.isRootLoaded else {
                Diag.error("Encountered another Root element, cancelling")
                throw Xml2.ParsingError.unexpectedTag(actual: "Root", expected: "/KeePassFile")
            }
        case (Xml2.group, .start):
            guard !context.isRootGroupLoaded else {
                Diag.error("Encountered another root group, cancelling")
                throw Xml2.ParsingError.unexpectedTag(actual: "Group", expected: "/Root")
            }
            try Group2.readFromXML(xml, database: self) { [unowned self, unowned context] root in
                context.isRootGroupLoaded = true
                self.root = root
            }
        case (Xml2.deletedObjects, .start):
            try xml.pushReader(parseDeletedObjectsElement, context: nil)
        case (Xml2.root, .end):
            guard context.isRootGroupLoaded else {
                Diag.error("No root group found, cancelling")
                throw Xml2.ParsingError.unexpectedTag(actual: "/Root", expected: "Group")
            }
            context.isRootLoaded = true
            Diag.verbose("XML root loaded OK")
            xml.popReader()
        default:
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "Root/*")
        }
    }

    private func parseDeletedObjectsElement(_ xml: DatabaseXMLParserStream) throws {
        switch (xml.name, xml.event) {
        case (Xml2.deletedObjects, .start):
            Diag.verbose("Loading XML: deleted objects")
            deletedObjects.removeAll()
        case (Xml2.deletedObject, .start):
            try DeletedObject2.readFromXML(xml) { [unowned self] object in
                deletedObjects.append(object)
            }
        case (Xml2.deletedObjects, .end):
            Diag.verbose("XML deleted objects loaded OK")
            xml.popReader()
        default:
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "DeletedObjects/*")
        }
    }
}

private extension Group2 {
    func enforceCustomIconUUID(isValid validValues: Set<UUID>) {
        guard customIconUUID != UUID.ZERO else { return }
        if !validValues.contains(self.customIconUUID) {
            customIconUUID = UUID.ZERO
        }
    }
}

private extension Entry2 {
    func enforceCustomIconUUID(isValid validValues: Set<UUID>) {
        guard customIconUUID != UUID.ZERO else { return }
        if !validValues.contains(customIconUUID) {
            customIconUUID = UUID.ZERO
        }
        history.forEach { historyEntry in
            historyEntry.enforceCustomIconUUID(isValid: validValues)
        }
    }
}

extension LString.Warning {
    // swiftlint:disable line_length
    public static let unusedAttachmentsTemplate = NSLocalizedString(
        "[Database2/Loading/Warning/unusedAttachments]",
        bundle: Bundle.framework,
        value: "The database contains some attachments that are not used in any entry. Most likely, they have been forgotten by the last used app (%@). However, this can also be a sign of data corruption. \nPlease make sure to have a backup of your database before changing anything.",
        comment: "A warning about unused attachments after loading the database. [lastUsedAppName: String]"
    )
    public static let missingBinariesTemplate = NSLocalizedString(
        "[Database2/Loading/Warning/missingBinaries]",
        bundle: Bundle.framework,
        value: "Attachments of some entries are missing data. This is a sign of database corruption, most likely by the last used app (%@). KeePassium will preserve the empty attachments, but cannot restore them. You should restore your database from a backup copy. \n\nMissing attachments: %@",
        comment: "A warning about missing attachments after loading the database. [lastUsedAppName: String, attachmentNames: String]"
    )
    public static let namelessCustomFieldsTemplate = NSLocalizedString(
        "[Database2/Loading/Warning/namelessCustomFields]",
        bundle: Bundle.framework,
        value: "Some entries have custom field(s) with empty names. This can be a sign of data corruption. Please check these entries:\n\n%@",
        comment: "A warning about misformatted custom fields after loading the database. [entryPaths: String]"
    )
    public static let namelessAttachmentsTemplate = NSLocalizedString(
        "[Database2/Loading/Warning/namelessAttachments]",
        bundle: Bundle.framework,
        value: "Some entries have attachments without a name. This is a sign of previous database corruption.\n\n Please review attached files in the following entries (and their history):\n%@",
        comment: "A warning about nameless attachments, shown after loading the database. [listOfEntryNames: String]"
    )
    // swiftlint:enable line_length
}
