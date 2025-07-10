//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UITextInput {

    var selectedOrFullTextRange: Range<String.Index> {
        let range = selectedTextRange
            ?? textRange(
                from: self.beginningOfDocument,
                to: self.endOfDocument)
            ?? UITextRange()
        let location = offset(from: beginningOfDocument, to: range.start)
        let length = offset(from: range.start, to: range.end)
        let text = textRange(from: beginningOfDocument, to: endOfDocument).flatMap({ self.text(in: $0) }) ?? ""

        let startIndex = text.index(text.startIndex, offsetBy: location)
        let endIndex = text.index(startIndex, offsetBy: length)
        return startIndex ..< endIndex
    }
}
