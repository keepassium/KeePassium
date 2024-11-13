//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

public extension Data {
    init?(base64URLEncoded string: String) {
        var converted = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingLength = converted.count % 4
        let padding = String(repeating: "=", count: paddingLength)
        converted.append(padding)
        self.init(base64Encoded: converted)
    }

    func base64URLEncodedString() -> String {
        let converted = self.base64EncodedString()
        let result = converted
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return result
    }
}
