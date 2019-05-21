//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public extension Date {
    static var now: Date { return Date() }
    
    static internal let dotNetTimeZero = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(abbreviation: "UTC"),
        year: 1, month: 1, day: 1,
        hour: 0, minute: 0, second: 0, nanosecond: 0
        ).date! 

    init?(iso8601string string: String?) {
        guard let string = string else { return nil }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = dateFormatter.date(from:string) {
            self = date
        } else {
            return nil
        }
    }
    
    init?(base64Encoded string: String?) {
        guard let data = ByteArray(base64Encoded: string) else { return nil }
        guard let seconds = Int64(data: data) else { return nil }
        self = Date(timeInterval: Double(seconds), since: Date.dotNetTimeZero)
    }
    
    func iso8601String() -> String {
        return ISO8601DateFormatter().string(from: self)
    }
    
    func base64EncodedString() -> String {
        let secondsSinceRef = Int64(self.timeIntervalSince(Date.dotNetTimeZero))
        return secondsSinceRef.data.base64EncodedString()
    }
}
