//  KeePassium Password Manager
//  Copyright © 2018–2023 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

extension String {
    public var isNotEmpty: Bool { return !isEmpty }
    
    mutating func erase() {
        self.removeAll()
    }
    
    var utf8data: ByteArray {
        return ByteArray(data: self.data(using: .utf8)!) 
    }
    
    public func localizedContains<T: StringProtocol>(
        _ other: T,
        options: String.CompareOptions = [])
        -> Bool
    {
        let position = range(
            of: other,
            options: options,
            locale: Locale.current)
        return position != nil
    }
    
    public func containsDiacritics() -> Bool {
        let withoutDiacritics = self.folding(
            options: [.diacriticInsensitive],
            locale: Locale.current)
        let result = self.compare(withoutDiacritics, options: .literal, range: nil, locale: nil)
        return result != .orderedSame
    }
    
    public func withLeadingSlash() -> String {
        if self.first == "/" {
            return self
        } else {
            return "/" + self
        }
    }
    
    public func withTrailingSlash() -> String {
        if self.last == "/" {
            return self
        } else {
            return self + "/"
        }
    }
    
    public func matchedGroups(forRegex regex: String) -> [String]? {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let matches = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            guard let match = matches.first else { return nil }
            var groups = [String]()
            for i in 0..<match.numberOfRanges {
                let range = match.range(at: i)
                if range.location != NSNotFound,
                   let matchString = Range(range, in: self) {
                    groups.append(String(self[matchString]))
                }else {
                    groups.append("")
                }
            }
            return groups
        } catch {
            return nil
        }
    }
}
