//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum PasswordGeneratorError: LocalizedError {
    case requiredSetCompletelyExcluded
    case desiredLengthTooShort(minimum: Int)
    case notEnoughElementsToSample
    case maxConsecutiveNotSatisfiable
    
    public var errorDescription: String? {
        switch self {
        case .requiredSetCompletelyExcluded:
            return LString.PasswordGeneratorError.titleRequiredSetCompletelyExcluded
        case .desiredLengthTooShort(let minimumLength):
            return String.localizedStringWithFormat(
                LString.PasswordGeneratorError.titleDesiredLengthTooShortTemplate,
                minimumLength)
        case .notEnoughElementsToSample:
            return LString.PasswordGeneratorError.titleNotEnoughElementsToSample
        case .maxConsecutiveNotSatisfiable:
            return LString.PasswordGeneratorError.titleMaxConsecutiveNotSatisfiable
        }
    }
}

public extension LString {
    enum PasswordGeneratorError {
        public static let titleCannotGenerateText =  NSLocalizedString(
            "[PasswordGenerator/CannotGenerateText/title]",
            bundle: Bundle.framework,
            value: "Cannot generate text",
            comment: "Error message from the random text generator."
        )
        public static let titleRequiredSetCompletelyExcluded = NSLocalizedString(
            "[PasswordGenerator/RequiredSetCompletelyExcluded/title]",
            bundle: Bundle.framework,
            value: "One of the character sets is both required and excluded.",
            comment: "Error message from the random text generator. `required` and `excluded` are as in [PasswordGenerator/InclusionCondition/required] and [PasswordGenerator/InclusionCondition/excluded]"
        )
        public static let titleDesiredLengthTooShortTemplate = NSLocalizedString(
            "[PasswordGenerator/DesiredLengthTooShort/title]",
            bundle: Bundle.framework,
            value: "Increase the length parameter to at least %d.",
            comment: "Error message/call to action from the random text generator."
        )
        public static let titleNotEnoughElementsToSample = NSLocalizedString(
            "[PasswordGenerator/NotEnoughElementsToSample/title]",
            bundle: Bundle.framework,
            value: "Need more elements to pick from.",
            comment: "Error message from the random text generator."
        )
        public static let titleMaxConsecutiveNotSatisfiable = NSLocalizedString(
            "[PasswordGenerator/MaxConsecutiveNotSatisfiable/title]",
            bundle: Bundle.framework,
            value: "Increase the limit on maximum number of identical elements repeating consecutively.",
            comment: "Error message/call to action from the random text generator."
        )
    }
}
