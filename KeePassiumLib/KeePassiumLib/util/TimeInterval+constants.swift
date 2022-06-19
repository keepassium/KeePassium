//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public extension TimeInterval {
    static let second = TimeInterval(1.0)
    static let minute = 60 * second
    static let hour   = 60 * minute
    static let day    = 24 * hour
    static let week   = 7 * day
    static let month  = 30 * day
    static let year   = 365 * day
}
