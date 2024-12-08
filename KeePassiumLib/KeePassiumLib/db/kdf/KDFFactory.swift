//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

protocol KeyDerivationFunction {
    var uuid: UUID { get }
    var name: String { get }
    var defaultParams: KDFParams { get }

    func initProgress() -> ProgressEx

    func parseParams(_ kdfParams: KDFParams, to settings: inout EncryptionSettings)

    func getPeakMemoryFootprint(_ kdfParams: KDFParams) -> Int

    func apply(_ settings: EncryptionSettings, to kdfParams: inout KDFParams)

    init()

    func transform(key: SecureBytes, params: KDFParams) throws -> SecureBytes

    func getChallenge(_ params: KDFParams) throws -> ByteArray

    func randomize(params: inout KDFParams) throws
}

final class KDFFactory {
    private init() {
    }

    public static func create(_ kdfType: EncryptionSettings.KDFType) -> KeyDerivationFunction {
        switch kdfType {
        case .argon2d:
            Diag.info("Creating Argon2d KDF")
            return Argon2dKDF()
        case .argon2id:
            Diag.info("Creating Argon2id KDF")
            return Argon2idKDF()
        case .aesKdf:
            Diag.info("Creating AES KDF")
            return AESKDF()
        }
    }

    public static func createFor(uuid: UUID) -> KeyDerivationFunction? {
        switch uuid {
        case Argon2dKDF._uuid:
            Diag.info("Creating Argon2d KDF")
            return Argon2dKDF()
        case Argon2idKDF._uuid:
            Diag.info("Creating Argon2id KDF")
            return Argon2idKDF()
        case AESKDF._uuid:
            Diag.info("Creating AES KDF")
            return AESKDF()
        default:
            Diag.warning("Unrecognized KDF UUID")
            return nil
        }
    }
}
