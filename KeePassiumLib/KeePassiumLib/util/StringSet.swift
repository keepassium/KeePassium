//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public typealias StringSet = Set<String>

public extension StringSet {
    static let digits: Set<String> =
        ["0","1","2","3","4","5","6","7","8","9"]
    static let lowerCase: Set<String> = [
        "a","b","c","d","e","f","g","h","i","j","k","l","m",
        "n","o","p","q","r","s","t","u","v","w","x","y","z"]
    static let upperCase: Set<String> = [
        "A","B","C","D","E","F","G","H","I","J","K","L","M",
        "N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
    static let specials: Set<String> = [
        "`","~","!","@","#","$","%","^","&","*","_","-","+","=","(",")","[","]",
        "{","}","<",">","\\","|",":",";",",",".","?","/","'","\""]
    static let lookalikes: Set<String> =
        ["I","l","|","1","0","O","S","5"]
    
    static func fromCharacters(of string: String) -> StringSet {
        let result = string.reduce(into: StringSet()) { characterSet, character in
            characterSet.insert(String(character))
        }
        return result
    }
}

public struct ConditionalStringSet {    
    var set: StringSet
    var condition: InclusionCondition
    
    public init(_ set: StringSet, condition: InclusionCondition) {
        self.set = set
        self.condition = condition
    }
}

extension LString {
    enum NamedStringSet {
        public static let shortTitleUpperCase = "A…Z"
        public static let shortTitleLowerCase = "a…z"
        public static let shortTitleDigits = "0…9"
        public static let shortTitleSpecials = "#$%^&*…"
        public static let shortTitleLookalikes = "1lI|0O5S"

        public static let titleUpperCase = NSLocalizedString(
            "[PasswordGenerator/Set/Uppercase/title]",
            bundle: Bundle.framework,
            value: "Uppercase letters",
            comment: "Title for uppercase letters (like 'ABC')"
        )
        public static let titleLowerCase = NSLocalizedString(
            "[PasswordGenerator/Set/Lowercase/title]",
            bundle: Bundle.framework,
            value: "Lowercase letters",
            comment: "Title for lowercase letters (like 'abc')"
        )
        public static let titleDigits = NSLocalizedString(
            "[PasswordGenerator/Set/Digits/title]",
            bundle: Bundle.framework,
            value: "Digits",
            comment: "Title for digits (like '123')"
        )
        public static let titleSpecials = NSLocalizedString(
            "[PasswordGenerator/Set/Specials/title]",
            bundle: Bundle.framework,
            value: "Special symbols",
            comment: "Title for special symbols (like '@#$')"
        )
        public static let titleLookalikes = NSLocalizedString(
            "[PasswordGenerator/Set/Lookalikes/title]",
            bundle: Bundle.framework,
            value: "Look-alike characters",
            comment: "Title for look-alike symbols (like '1lI', that is: digit `1`, small `L`, capital `i`)."
        )
    }
}
