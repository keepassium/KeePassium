//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import UIKit

enum Tag {
    case direct(title: String, selected: Bool)
    case inherited(String)
    case database(title: String, selected: Bool, occurences: Int)

    var title: String {
        switch self {
        case .direct(let title, _),
             .inherited(let title),
             .database(title: let title, selected: _, occurences: _):
            return title
        }
    }

    var tintColor: UIColor {
        switch self {
        case .direct, .database:
            return .actionTint
        case .inherited:
            return .secondaryLabel
        }
    }

    var selected: Bool {
        switch self {
        case .inherited:
            return true
        case .direct(title: _, selected: let selected),
             .database(title: _, selected: let selected, occurences: _):
            return selected
        }
    }

    var count: Int? {
        switch self {
        case .direct, .inherited:
            return nil
        case .database(title: _, selected: _, occurences: let count):
            return count
        }
    }

    func contains(text: String) -> Bool {
        return title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .contains(text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current))
    }
}
