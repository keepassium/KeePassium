//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final public class OTPCodeFormatter {

    public static func decorate(otpCode: String) -> String {
        var result = otpCode
        switch otpCode.count {
        case 5: result.insert(" ", at: String.Index(utf16Offset: 2, in: result))
        case 6: result.insert(" ", at: String.Index(utf16Offset: 3, in: result))
        case 7: result.insert(" ", at: String.Index(utf16Offset: 3, in: result))
        case 8: result.insert(" ", at: String.Index(utf16Offset: 4, in: result))
        default:
            break
        }
        return result
    }
}
