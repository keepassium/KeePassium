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
    
    func randomize(params: inout KDFParams) throws
}

final class KDFFactory {
    private static let argon2kdf = Argon2KDF()
    private static let aeskdf = AESKDF()

    private init() {
    }
    
    public static func createFor(uuid: UUID) -> KeyDerivationFunction? {
        switch uuid {
        case argon2kdf.uuid:
            Diag.info("Creating Argon2 KDF")
            return Argon2KDF()
        case aeskdf.uuid:
            Diag.info("Creating AES KDF")
            return AESKDF()
        default:
            Diag.warning("Unrecognized KDF UUID")
            return nil
        }
    }
}
