//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public class PasswordStringHelper {
    public enum Color {
        public static let letter = UIColor.passwordLetters
        public static let digit = UIColor.passwordDigits
        public static let symbol = UIColor.passwordSymbols
    }
    
    public static func decorate(_ password: String, font: UIFont?) -> NSAttributedString {
        let baseFont = font ?? UIFont.monospaceFont(forTextStyle: .body)
        
        let result = NSMutableAttributedString()
        let letterAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Color.letter,
            .font: baseFont
        ]
        let digitAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Color.digit,
            .font: baseFont
        ]
        let symbolAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Color.symbol,
            .font: baseFont
        ]


        password.forEach { (character) in
            if character.isNumber {
                result.append(
                    NSAttributedString(string: String(character), attributes: digitAttributes))
            } else if character.isLetter {
                result.append(
                    NSAttributedString(string: String(character), attributes: letterAttributes))
            } else {
                result.append(
                    NSAttributedString(string: String(character), attributes: symbolAttributes))
            }
        }
        return result
    }
}
