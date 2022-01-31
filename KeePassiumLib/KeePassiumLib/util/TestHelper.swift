//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final public class TestHelper {
    
    public static func getIndex(from optionCount: Int) -> Int {
        assert(optionCount > 0)
        let weekNumberBaseN = Date.now.iso8601WeekOfYear % optionCount
        return weekNumberBaseN
    }
    
    public static func getCurrent<T>(from options: [T], debug: Int? = nil) -> T {
        if let debugIndex = debug {
            return options[debugIndex]
        }
        let currentIndex = getIndex(from: options.count)
        return options[currentIndex]
    }
}
