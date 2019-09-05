//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

class Header1 {
    public static let signature1: UInt32 = 0x9AA2D903
    public static let signature2: UInt32 = 0xB54BFB65
    public static let fileVersion: UInt32 = 0x00030003
    public static let versionMask: UInt32 = 0xFFFFFF00
    
    public let count = 124
    private let masterSeedSize    = 16
    private let initialVectorSize = 16
    private let transformSeedSize = 32
    
    enum Error: LocalizedError {
        case readingError
        case wrongSignature
        case unsupportedFileVersion(actualVersion: String)
        case unsupportedDataCipher(flags: UInt32)
        
        public var errorDescription: String? {
            switch self {
            case .readingError:
                return NSLocalizedString(
                    "[Database1/Header1/Error] Header reading error. DB file corrupt?",
                    bundle: Bundle.framework,
                    value: "Header reading error. DB file corrupt?",
                    comment: "Error message when reading database header")
            case .wrongSignature:
                return NSLocalizedString(
                    "[Database1/Header1/Error] Wrong file signature. Not a KeePass database?",
                    bundle: Bundle.framework,
                    value: "Wrong file signature. Not a KeePass database?",
                    comment: "Error message when opening a database")
            case .unsupportedFileVersion(let version):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database1/Header1/Error] Unsupported database format version: %@.",
                        bundle: Bundle.framework,
                        value: "Unsupported database format version: %@.",
                        comment: "Error message when opening a database. [version: String]"),
                    version)
            case .unsupportedDataCipher(let flags):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database1/Header1/Error] Unsupported cipher. (Code: %@)",
                        bundle: Bundle.framework,
                        value: "Unsupported cipher. (Code: %@)",
                        comment: "Error message. [flagsHexString: String]"),
                    flags.asHexString)
            }
        }
    }
    
    enum Flag {
        public static let sha2     = UInt32(0x01)
        public static let aes      = UInt32(0x02)
        public static let arcfour  = UInt32(0x04)
        public static let twofish  = UInt32(0x08)
    }
    enum CipherAlgorithm: UInt8 {
        case aes     = 0
        case twofish = 1
    }
    
    private weak var database: Database1?
    private(set) var flags: UInt32 
    private(set) var masterSeed: ByteArray
    private(set) var initialVector: ByteArray
    internal var contentHash: ByteArray
    private(set) var transformSeed: ByteArray
    private(set) var transformRounds: UInt32
    internal var groupCount: Int 
    internal var entryCount: Int 
    private(set) var algorithm: CipherAlgorithm
    
    init(database: Database1) {
        self.database = database
        flags = 0
        masterSeed = ByteArray()
        initialVector = ByteArray()
        contentHash = ByteArray()
        transformSeed = ByteArray()
        transformRounds = 0
        groupCount = 0
        entryCount = 0
        algorithm = .aes
    }
    deinit {
        erase()
    }
    func erase() {
        flags = 0
        masterSeed.erase()
        initialVector.erase()
        contentHash.erase()
        transformSeed.erase()
        transformRounds = 0
        groupCount = 0
        entryCount = 0
        algorithm = .aes
    }
    
    class func isSignatureMatches(data: ByteArray) -> Bool {
        let stream = data.asInputStream()
        stream.open()
        defer { stream.close() }
        
        guard let sign1 = stream.readUInt32(),
            let sign2 = stream.readUInt32(),
            let _ = stream.readUInt32(), 
            let fileVer = stream.readUInt32() else
        {
            Diag.warning("Signature bytes missing")
            return false
        }
        guard sign1 == Header1.signature1 && sign2 == Header1.signature2 else {
            return false
        }
        guard (fileVer & Header1.versionMask) == (Header1.fileVersion & Header1.versionMask) else {
            Diag.warning("File version mismatch [version: \(fileVer.asHexString)]")
            return false
        }
        return true
    }
    
    func read(data: ByteArray) throws {
        Diag.debug("Reading the header")
        erase()
        
        let stream = data.asInputStream()
        stream.open()
        defer { stream.close() }
        
        guard let sign1 = stream.readUInt32(),
            let sign2 = stream.readUInt32(),
            let flags = stream.readUInt32(),
            let fileVer = stream.readUInt32() else {
                throw Error.readingError
        }
        
        guard sign1 == Header1.signature1 && sign2 == Header1.signature2 else {
            throw Error.wrongSignature
        }
        guard (fileVer & Header1.versionMask) == (Header1.fileVersion & Header1.versionMask) else {
            throw Error.unsupportedFileVersion(actualVersion: fileVer.asHexString)
        }
        
        if (flags & Flag.aes != 0) && (flags & Flag.twofish == 0) {
            algorithm = .aes
        } else if (flags & Flag.twofish != 0) && (flags & Flag.aes == 0) {
            algorithm = .twofish
        } else {
            throw Error.unsupportedDataCipher(flags: flags)
        }
        
        self.flags = flags
        
        guard let masterSeed = stream.read(count: masterSeedSize) else { throw Error.readingError }
        guard let initialVector = stream.read(count: initialVectorSize) else { throw Error.readingError }
        self.masterSeed = masterSeed
        self.initialVector = initialVector

        guard let groupCount = stream.readUInt32() else { throw Error.readingError }
        guard let entryCount = stream.readUInt32() else { throw Error.readingError }
        self.groupCount = Int(groupCount)
        self.entryCount = Int(entryCount)
        
        guard let contentHash = stream.read(count: SHA256_SIZE) else { throw Error.readingError }
        guard let transformSeed = stream.read(count: transformSeedSize) else { throw Error.readingError }
        self.contentHash = contentHash
        self.transformSeed = transformSeed
        
        guard let transformRounds = stream.readUInt32() else { throw Error.readingError }
        self.transformRounds = transformRounds
    }
    
    func write(to stream: ByteArray.OutputStream) {
        Diag.debug("Writing the header")
        switch algorithm {
        case .aes:
            flags = Flag.sha2 | Flag.aes
        case .twofish:
            flags = Flag.sha2 | Flag.twofish
        }
        stream.write(value: Header1.signature1)
        stream.write(value: Header1.signature2)
        stream.write(value: flags)
        stream.write(value: Header1.fileVersion)
        stream.write(data: masterSeed)
        stream.write(data: initialVector)
        stream.write(value: UInt32(groupCount))
        stream.write(value: UInt32(entryCount))
        stream.write(data: contentHash)
        stream.write(data: transformSeed)
        stream.write(value: transformRounds)
    }
    
    internal func randomizeSeeds() throws {
        Diag.debug("Randomizing the seeds")
        initialVector = try CryptoManager.getRandomBytes(count: initialVectorSize)
        masterSeed = try CryptoManager.getRandomBytes(count: masterSeedSize)
        transformSeed = try CryptoManager.getRandomBytes(count: transformSeedSize)
    }
}
