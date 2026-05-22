//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension Entry {
    func canAcceptNewAttachments(count: Int) -> Bool {
        if isSupportsMultipleAttachments {
            return true
        }
        return count == 1 && attachments.isEmpty
    }

    var resolvedSubtitle: String? {
        switch Settings.current.entryListDetail {
        case .none:
            return nil
        case .userName:
            return getField(EntryField.userName)?.decoratedResolvedValue
        case .password:
            return getField(EntryField.password)?.decoratedResolvedValue
        case .url:
            return getField(EntryField.url)?.decoratedResolvedValue
        case .notes:
            return getField(EntryField.notes)?.decoratedResolvedValue
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
        case .lastModifiedDate:
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: lastModificationTime)
        case .tags:
            guard self is Entry2 else {
                return nil
            }
            return resolvingTags().joined(separator: ", ")
        }
    }
}
