//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public struct SecureRandomNumberGenerator: RandomNumberGenerator {
    public func next() -> UInt64 {
        var random: UInt64 = 0
        let status = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt64>.size, &random)
        guard status == errSecSuccess else {
            Diag.warning("Failed to generate random bytes [status: \(status)]")
            __failed_to_generate_random_bytes()
            fatalError()
        }
        return random
    }
    
    private func __failed_to_generate_random_bytes() {
        fatalError()
    }
}
