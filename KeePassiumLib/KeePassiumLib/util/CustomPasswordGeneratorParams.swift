//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public struct CustomPasswordGeneratorParams: Codable, Equatable {
    public enum FixedSet: Int, Codable, CustomStringConvertible {
        case upperCase = 0
        case lowerCase = 1
        case digits    = 2
        case specials  = 3
        case lookalikes = 4

        public var title: String {
            switch self {
            case .upperCase:
                return LString.NamedStringSet.shortTitleUpperCase
            case .lowerCase:
                return LString.NamedStringSet.shortTitleLowerCase
            case .digits:
                return LString.NamedStringSet.shortTitleDigits
            case .specials:
                return LString.NamedStringSet.shortTitleSpecials
            case .lookalikes:
                return LString.NamedStringSet.shortTitleLookalikes
            }
        }
        
        public var description: String {
            switch self {
            case .upperCase:
                return LString.NamedStringSet.titleUpperCase
            case .lowerCase:
                return LString.NamedStringSet.titleLowerCase
            case .digits:
                return LString.NamedStringSet.titleDigits
            case .specials:
                return LString.NamedStringSet.titleSpecials
            case .lookalikes:
                return LString.NamedStringSet.titleLookalikes
            }
        }
        
        public var value: StringSet {
            switch self {
            case .upperCase:
                return StringSet.upperCase
            case .lowerCase:
                return StringSet.lowerCase
            case .digits:
                return StringSet.digits
            case .specials:
                return StringSet.specials
            case .lookalikes:
                return StringSet.lookalikes
            }
        }
    }
    
    public static let lengthRange = 4...128  
    public var length: Int = 32
    public var fixedSets: [FixedSet: InclusionCondition] = [
        .upperCase: .allowed,
        .lowerCase: .allowed,
        .digits: .allowed,
        .specials: .allowed,
        .lookalikes: .excluded,
    ]
    public var customLists = [InclusionCondition: String]()
    
    public var maxConsecutive: Int?
    
    init() {
    }
}

extension CustomPasswordGeneratorParams: PasswordGeneratorRequirementsConvertible {
    public func toRequirements() -> PasswordGeneratorRequirements {
        assert(CustomPasswordGeneratorParams.lengthRange.contains(length), "Length is out of bounds")
        
        var conditionalSets = [ConditionalStringSet]()
        fixedSets.forEach { fixedSet, condition in
            conditionalSets.append(ConditionalStringSet(fixedSet.value, condition: condition))
        }
        customLists.forEach { condition, string in
            let customSet = StringSet.fromCharacters(of: string)
            if !customSet.isEmpty {
                conditionalSets.append(ConditionalStringSet(customSet, condition: condition))
            }
        }
        return PasswordGeneratorRequirements(
            length: length,
            sets: conditionalSets,
            maxConsecutive: maxConsecutive
        )
    }
}
