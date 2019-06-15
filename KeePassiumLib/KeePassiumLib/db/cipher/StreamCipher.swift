//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

protocol StreamCipher: Eraseable {
    func encrypt(data: ByteArray, progress: ProgressEx?) throws -> ByteArray
    func decrypt(data: ByteArray, progress: ProgressEx?) throws -> ByteArray
}
