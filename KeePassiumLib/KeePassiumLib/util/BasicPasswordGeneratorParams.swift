//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public struct BasicPasswordGeneratorParams: Codable, Equatable {
    public static let lengthRange = 8...64
    public var length: Int = 32
}

extension BasicPasswordGeneratorParams: PasswordGeneratorRequirementsConvertible {
    public func toRequirements() -> PasswordGeneratorRequirements {
        assert(BasicPasswordGeneratorParams.lengthRange.contains(length), "Length is out of bounds")
        return PasswordGeneratorRequirements(
            length: length,
            sets: [
                ConditionalStringSet(StringSet.upperCase, condition: .allowed),
                ConditionalStringSet(StringSet.lowerCase, condition: .allowed),
                ConditionalStringSet(StringSet.digits, condition: .allowed),
                ConditionalStringSet(StringSet.lookalikes, condition: .excluded),
            ],
            maxConsecutive: nil
        )
    }
}
