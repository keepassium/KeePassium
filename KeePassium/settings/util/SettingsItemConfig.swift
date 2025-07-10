//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import UIKit

class SettingsItemConfig: Hashable {
    var title: String
    var subtitle: String?
    var image: UIImage?
    var isEnabled: Bool
    var needsPremium: Bool

    init(
        title: String,
        subtitle: String? = nil,
        image: UIImage? = nil,
        isEnabled: Bool,
        needsPremium: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.isEnabled = isEnabled
        self.needsPremium = needsPremium
    }

    static func == (lhs: SettingsItemConfig, rhs: SettingsItemConfig) -> Bool {
        return type(of: lhs) == type(of: rhs) && lhs.isEqual(rhs)
    }

    func isEqual(_ another: SettingsItemConfig?) -> Bool {
        return self.title == another?.title
            && self.subtitle == another?.subtitle
            && self.image == another?.image
            && self.isEnabled == another?.isEnabled
            && self.needsPremium == another?.needsPremium
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(image)
        hasher.combine(isEnabled)
        hasher.combine(needsPremium)
    }
}
