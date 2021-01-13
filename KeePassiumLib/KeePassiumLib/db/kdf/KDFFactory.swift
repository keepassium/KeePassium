//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
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

    init()
    
    func transform(key: SecureByteArray, params: KDFParams) throws -> SecureByteArray
    
    func getChallenge(_ params: KDFParams) throws -> ByteArray
    
    func randomize(params: inout KDFParams) throws
}

final class KDFFactory {
    private static let argon2dKDF = Argon2dKDF()
    private static let argon2idKDF = Argon2idKDF()
    private static let aesKDF = AESKDF()

    private init() {
    }
    
    public static func createFor(uuid: UUID) -> KeyDerivationFunction? {
        switch uuid {
        case argon2dKDF.uuid:
            Diag.info("Creating Argon2d KDF")
            return Argon2dKDF()
        case argon2idKDF.uuid:
            Diag.info("Creating Argon2id KDF")
            return Argon2idKDF()
        case aesKDF.uuid:
            Diag.info("Creating AES KDF")
            return AESKDF()
        default:
            Diag.warning("Unrecognized KDF UUID")
            return nil
        }
    }
}
