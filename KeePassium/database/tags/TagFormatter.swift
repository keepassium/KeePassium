//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import UIKit

final class TagFormatter {

    static func format(_ tagString: String?) -> NSAttributedString? {
        guard let tags = tagString?
            .components(separatedBy: .init(charactersIn: ","))
            .filter({ $0.isNotEmpty })
        else {
            return nil
        }
        return format(tags: tags)
    }

    static func format(tags: [String]) -> NSAttributedString? {
        guard !tags.isEmpty else {
            return nil
        }

        let result = NSMutableAttributedString(string: "")
        tags.forEach {
            let tag = "\u{00a0}\($0)\u{00a0}"
            let attributedTag = NSMutableAttributedString(string: tag)
            let wholeTagRange = NSRange(location: 0, length: tag.count)
            attributedTag.addAttribute(.backgroundColor, value: UIColor.actionTint, range: wholeTagRange)
            attributedTag.addAttribute(.foregroundColor, value: UIColor.actionText, range: wholeTagRange)
            result.append(attributedTag)
            result.append(NSMutableAttributedString(string: " "))
        }
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
                .withRelativeSize(Settings.current.textScale)
        let wholeResultRange = NSRange(location: 0, length: result.length)
        result.addAttribute(.font, value: font, range: wholeResultRange)
        return result
    }
}
