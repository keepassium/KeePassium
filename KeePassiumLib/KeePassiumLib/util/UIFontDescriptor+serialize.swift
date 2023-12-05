//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIFontDescriptor {
    public func serialize() -> Data? {
        let data = try? NSKeyedArchiver.archivedData(
            withRootObject: self,
            requiringSecureCoding: true)
        return data
    }

    public static func deserialize(_ data: Data?) -> UIFontDescriptor? {
        guard let data else { return nil }
        let fontDescriptor = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: UIFontDescriptor.self,
            from: data
        )
        return fontDescriptor
    }
}
