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
    public static let minDatabasePasswordEntropy = Float(maxEntropyWeak)
    public static let minAppPasscodeEntropy = Float(maxEntropyVeryWeak)

    private static let maxEntropyVeryWeak = 40
    private static let maxEntropyWeak = 75
    private static let maxEntropyGood = 100

    public static let highestEntropyCutoff = maxEntropyGood

    case veryWeak(Int32)
    case weak(Int32)
    case good(Int32)
    case veryGood(Int32)

    var entropy: Int32 {
        switch self {
        case let .weak(entropy),
             let .veryWeak(entropy),
             let .good(entropy),
             let .veryGood(entropy):
            return entropy
        }
    }
}

extension PasswordQuality: CaseIterable {
    static var allCases: [PasswordQuality] {
        return [.veryWeak(0), .weak(0), .good(0), .veryGood(0)]
    }
}

extension PasswordQuality: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.veryWeak, .veryWeak),
             (.weak, .weak),
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
              password.count < 1000
        else {
            return nil
        }
        guard let match = Self.zxcvbn.passwordStrength(password),
              let entropy = Float32(match.entropy).flatMap({ Int32($0) })
        else {
            return nil
        }

        if entropy <= Self.maxEntropyVeryWeak {
            self = .veryWeak(entropy)
        } else if entropy < Self.maxEntropyWeak {
            self = .weak(entropy)
        } else if entropy < Self.maxEntropyGood {
            self = .good(entropy)
        } else {
            self = .veryGood(entropy)
        }
    }
}

extension PasswordQuality {
    var strengthColor: UIColor {
        switch self {
        case .veryWeak:
            return .systemRed
        case .weak:
            return .systemOrange
        case .good, .veryGood:
            return .systemGreen
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
            return .systemRed
        case .weak:
            return .systemOrange
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
        case .good, .veryGood:
            return nil
        }
    }
}
