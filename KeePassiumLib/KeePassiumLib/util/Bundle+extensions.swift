//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

extension Bundle {
    internal static let framework = Bundle(identifier: "com.keepassium.ios.KeePassiumLib")!

    static var mainAppURL: URL {
        var pathComponents = main.bundleURL.pathComponents
        guard let index = pathComponents.lastIndex(where: { $0.hasSuffix(".app") }) else {
            Diag.debug("Failed to find main app's path")
            assertionFailure("Failed to find the main app's path")
            return main.bundleURL
        }
        let mainAppPathComponents = pathComponents.prefix(through: index)
        let result = URL(fileURLWithPath: mainAppPathComponents.joined(separator: "/"))
        return result
    }
}
