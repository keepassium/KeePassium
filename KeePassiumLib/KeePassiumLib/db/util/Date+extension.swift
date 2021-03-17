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
    
    private static let iso8601DateFormatter = { () -> ISO8601DateFormatter in
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    private static let iso8601DateFormatterWithFractionalSeconds = { () -> ISO8601DateFormatter in
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions =  [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let miniKeePassDateFormatter = { () -> DateFormatter in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static internal let secondsBetweenSwiftAndDotNetReferenceDates = Int64(63113904000)

    init?(iso8601string string: String?) {
        guard let string = string else { return nil }
        if let date = Date.iso8601DateFormatter.date(from: string) {
            self = date
        } else if let date = Date.iso8601DateFormatterWithFractionalSeconds.date(from: string) {
            self = date
        } else if let date = Date.miniKeePassDateFormatter.date(from: string) {
            self = date
        } else {
            return nil
        }
    }
    
    init?(base64Encoded string: String?) {
        guard let data = ByteArray(base64Encoded: string) else { return nil }
        guard let secondsSinceDotNetReferenceDate = Int64(data: data) else { return nil }
        let secondsSinceSwiftReferenceDate =
            secondsSinceDotNetReferenceDate - Date.secondsBetweenSwiftAndDotNetReferenceDates
        self = Date(timeIntervalSinceReferenceDate: Double(secondsSinceSwiftReferenceDate))
    }
    
    func iso8601String() -> String {
        return Date.iso8601DateFormatter.string(from: self)
    }
    
    func base64EncodedString() -> String {
        let secondsSinceSwiftReferenceDate = Int64(self.timeIntervalSinceReferenceDate)
        let secondsSinceDotNetReferenceDate =
            secondsSinceSwiftReferenceDate + Date.secondsBetweenSwiftAndDotNetReferenceDates
        return secondsSinceDotNetReferenceDate.data.base64EncodedString()
    }
    
    var iso8601WeekOfYear: Int {
        let isoCalendar = Calendar(identifier: .iso8601)
        let dateComponents = isoCalendar.dateComponents([.weekOfYear], from: self)
        return dateComponents.weekOfYear ?? 0
    }
}
