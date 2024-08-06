//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
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
        options: String.CompareOptions = []
    ) -> Bool {
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

    public func matchesCaseInsensitive(wildcard pattern: String) -> Bool {
        let predicate = NSComparisonPredicate(format: "self LIKE[c] %@", pattern)
        return predicate.evaluate(with: self)
    }

    public var isOpenableURL: Bool {
        guard let url = URL(string: self) else {
            return false
        }
        guard url.scheme != nil else {
            return false
        }
        if let appShared = AppGroup.applicationShared {
            return appShared.canOpenURL(url)
        } else {
            return true
        }
    }
}
