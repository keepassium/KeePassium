//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

struct Favicon {
    enum FaviconType: String {
        case appleTouchIcon = "apple-touch-icon"
        case icon = "icon"
        case shortcutIcon = "shortcut icon"
    }

    public static let defaultFilename = "favicon.ico"

    private static let linkRelRegexp = try! NSRegularExpression(pattern: "rel=\"([^\"]*)\"")
    private static let linkHrefRegexp = try! NSRegularExpression(pattern: "href=\"([^\"]*)\"")
    private static let linkSizesRegexp = try! NSRegularExpression(pattern: "sizes=\"([^\"]*)\"")

    let url: URL
    let type: FaviconType
    let size: CGSize

    init?(html: String, baseURL: URL) {
        let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matchedValue = { (regexp: NSRegularExpression) -> String? in
            guard let match = regexp.firstMatch(in: html, range: fullRange),
                  let matchRange = Range(match.range(at: 1), in: html)
            else {
                return nil
            }
            return String(html[matchRange])
        }

        guard let typeValueString = matchedValue(Self.linkRelRegexp),
              let type = FaviconType(rawValue: typeValueString)
        else {
            return nil
        }

        guard let urlValueString = matchedValue(Self.linkHrefRegexp),
              let url = URL(string: urlValueString, relativeTo: baseURL)
        else {
            return nil
        }

        let size = matchedValue(Self.linkSizesRegexp).map { value -> CGSize in
            let parts = value.split(separator: "x")
            guard parts.count == 2,
                  let width = Int(parts[0]),
                  let height = Int(parts[1])
            else {
                return .zero
            }
            return CGSize(width: width, height: height)
        }

        self.type = type
        self.url = url
        self.size = size ?? .zero
    }
}
