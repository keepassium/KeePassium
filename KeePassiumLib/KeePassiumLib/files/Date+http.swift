//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

extension Date {
    private enum HTTPHeaderFormats: String, CaseIterable {
        case imffixdate = "EEE, dd MMM yyyy HH:mm:ss z"
        case rfc850 = "EEEE, dd-MMM-yy HH:mm:ss z"
        case asctime = "EEE MMM d HH:mm:ss yyyy"
    }
    private static let usPosixLocale = Locale(identifier: "en_US_POSIX")
    private static let gmtTimeZone = TimeZone(secondsFromGMT: 0)
    
    public static func parse(httpHeaderValue: String?) -> Date? {
        guard let dateString = httpHeaderValue else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Date.usPosixLocale
        formatter.timeZone = Date.gmtTimeZone
        for format in HTTPHeaderFormats.allCases {
            formatter.dateFormat = format.rawValue
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
}
