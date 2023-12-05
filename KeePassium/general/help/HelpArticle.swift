//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

public struct HelpArticle {
    private let content: NSAttributedString

    public enum Key: String {
        case perpetualFallbackLicense = "perpetual-fallback-license"
        case appStoreFamilySharingProgramme = "appstore-family-sharing"
    }

    public func rendered() -> NSAttributedString {
        return content
    }

    public static func load(_ key: Key) -> HelpArticle? {
        let fileName = key.rawValue
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "html", subdirectory: "") else {
            Diag.error("Failed to find help article file")
            return nil
        }
        do {
            var d: NSDictionary?
            let content = try NSMutableAttributedString(
                url: url,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: &d)
            content.addAttribute(
                .foregroundColor,
                value: UIColor.primaryText,
                range: NSRange(0..<content.length)
            )
            return HelpArticle(content: content)
        } catch {
            Diag.error("Failed to load help article file [reason: \(error.localizedDescription)]")
            return nil
        }
    }
}
