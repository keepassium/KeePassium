//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum InclusionCondition: Int8, Codable, CustomStringConvertible {
    case inactive = -2
    case allowed  = -1
    case excluded = 0
    case required = 1
    
    public var description: String {
        switch self {
        case .inactive:
            return LString.InclusionCondition.inactive
        case .excluded:
            return LString.InclusionCondition.excluded
        case .allowed:
            return LString.InclusionCondition.allowed
        case .required:
            return LString.InclusionCondition.required
        }
    }
}

extension LString {
    enum InclusionCondition {
        public static let inactive = NSLocalizedString(
            "[PasswordGenerator/InclusionCondition/inactive]",
            bundle: Bundle.framework,
            value: "Inactive",
            comment: "Inclusion criterion for a password generator — a disabled/inactive one that won't be taken into account. For example: `Uppercase Letters: Inactive`")
        public static let excluded = NSLocalizedString(
            "[PasswordGenerator/InclusionCondition/excluded]",
            bundle: Bundle.framework,
            value: "Excluded",
            comment: "Inclusion criterion for a password generator. For example: `Uppercase Letters: Excluded`")
        public static let allowed = NSLocalizedString(
            "[PasswordGenerator/InclusionCondition/allowed]",
            bundle: Bundle.framework,
            value: "Allowed",
            comment: "Inclusion criterion for a password generator. For example: `Digits: Allowed`")
        public static let required = NSLocalizedString(
            "[PasswordGenerator/InclusionCondition/required]",
            bundle: Bundle.framework,
            value: "Required",
            comment: "Inclusion criterion for a password generator. For example: `Special Symbols: Required`")
    }
}
