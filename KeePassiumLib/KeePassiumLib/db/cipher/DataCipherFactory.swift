//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final class DataCipherFactory {
    public static let instance = DataCipherFactory()
    private let aes: AESDataCipher
    private let chacha20: ChaCha20DataCipher
    private let twofish: TwofishDataCipher
    private init() {
        aes = AESDataCipher()
        chacha20 = ChaCha20DataCipher()
        twofish = TwofishDataCipher(isPaddingLikelyMessedUp: true)
    }
    
    public func createFor(uuid: UUID) -> DataCipher? {
        switch uuid {
        case aes.uuid:
            Diag.info("Creating AES cipher")
            return AESDataCipher()
        case chacha20.uuid:
            Diag.info("Creating ChaCha20 cipher")
            return ChaCha20DataCipher()
        case twofish.uuid:
            Diag.info("Creating Twofish cipher")
            return TwofishDataCipher(isPaddingLikelyMessedUp: true)
        default:
            Diag.warning("Unrecognized cipher UUID")
            return nil
        }
    }
}
