//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import UIKit
import Zxcvbn

enum PasswordQuality {
    case veryWeak(Int32)
    case weak(Int32)
    case almostGood(Int32)
    case good(Int32)
    case veryGood(Int32)

    var entropy: Int32 {
        switch self {
        case let .weak(entropy),
             let .veryWeak(entropy),
             let .almostGood(entropy),
             let .good(entropy),
             let .veryGood(entropy):
            return entropy
        }
    }
}

extension PasswordQuality: CaseIterable {
    static var allCases: [PasswordQuality] {
        return [.veryWeak(0), .weak(0), .almostGood(0), .good(0), .veryGood(0)]
    }
}

extension PasswordQuality: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.veryWeak, .veryWeak),
             (.weak, .weak),
             (.almostGood, .almostGood),
             (.good, .good),
             (.veryGood, .veryGood):
            return true
        default:
            return false
        }
    }
}

extension PasswordQuality {
    private static let zxcvbn = DBZxcvbn()
}

extension PasswordQuality {
    init?(password: String?) {
        guard let password = password,
              !password.isEmpty,
              let match = Self.zxcvbn.passwordStrength(password),
              let entropy = Float32(match.entropy).flatMap({ Int32($0) })
        else {
            return nil
        }

        switch match.score {
        case 0:
            self = .veryWeak(entropy)
        case 1:
            self = .weak(entropy)
        case 2:
            self = .almostGood(entropy)
        case 3:
            self = .good(entropy)
        case 4:
            self = .veryGood(entropy)
        default:
            return nil
        }
    }
}

extension PasswordQuality {
    var strengthColor: UIColor {
        switch self {
        case .veryWeak:
            return .auxiliaryText
        case .weak:
            return .init(red: 228 / 255, green: 8 / 255, blue: 8 / 255, alpha: 1)
        case .almostGood:
            return .init(red: 255 / 255, green: 216 / 255, blue: 0 / 255, alpha: 1)
        case .good, .veryGood:
            return .init(red: 44 / 255, green: 177 / 255, blue: 23 / 255, alpha: 1)
        }
    }

    var title: String {
        switch self {
        case .veryWeak:
            return NSLocalizedString(
                "[PasswordQuality/Level] Very weak",
                value: "Very weak",
                comment: "Very weak password quality")
        case .weak:
            return NSLocalizedString(
                "[PasswordQuality/Level] Weak",
                value: "Weak",
                comment: "Weak password quality")
        case .almostGood:
            return NSLocalizedString(
                "[PasswordQuality/Level] Almost good",
                value: "Almost good",
                comment: "Almost good password quality")
        case .good:
            return NSLocalizedString(
                "[PasswordQuality/Level] Good",
                value: "Good",
                comment: "Good password quality")
        case .veryGood:
            return NSLocalizedString(
                "[PasswordQuality/Level] Very good",
                value: "Very good",
                comment: "Very good password quality")
        }
    }

    var iconColor: UIColor? {
        switch self {
        case .veryWeak:
            return .init(red: 228 / 255, green: 8 / 255, blue: 8 / 255, alpha: 1)
        case .weak, .almostGood:
            return .init(red: 255 / 255, green: 216 / 255, blue: 0 / 255, alpha: 1)
        case .good, .veryGood:
            return nil
        }
    }

    var symbolName: SymbolName? {
        switch self {
        case .veryWeak:
            return SymbolName.exclamationMarkOctagonFill
        case .weak:
            return SymbolName.exclamationMarkTriangleFill
        case .almostGood:
            return SymbolName.exclamationMarkTriangle
        case .good, .veryGood:
            return nil
        }
    }
}
