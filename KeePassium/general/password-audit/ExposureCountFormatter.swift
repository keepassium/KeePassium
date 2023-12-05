//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final class ExposureCountFormatter: Formatter {
    public static func string(fromExposureCount exposureCount: Int) -> String {
        assert(exposureCount >= 0, "Number of exposures should be non-negative")
        if exposureCount < 10 {
            return String(exposureCount)
        }
        let formattedNumber = exposureCount.formatted(
           .number
           .rounded(rule: .down, increment: nil)
           .precision(.significantDigits(1))
           .grouping(.automatic)
        )
        return formattedNumber + "+"
    }
}
