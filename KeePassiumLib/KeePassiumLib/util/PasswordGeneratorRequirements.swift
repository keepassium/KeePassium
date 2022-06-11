//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

protocol PasswordGeneratorRequirementsConvertible {
    func toRequirements() -> PasswordGeneratorRequirements
}

public struct PasswordGeneratorRequirements {
    let length: Int
    let sets: [ConditionalStringSet]
    
    let maxConsecutive: Int?
    
    let elementPreprocessor: PasswordGenerator.ElementPreprocessingFunction?
    let elementMerger: PasswordGenerator.ElementMergingFunction?
    
    public init(
        length: Int,
        sets: [ConditionalStringSet],
        maxConsecutive: Int?,
        elementPreprocessor: PasswordGenerator.ElementPreprocessingFunction? = nil,
        elementMerger: PasswordGenerator.ElementMergingFunction? = nil
    ) {
        self.length = length
        self.sets = sets.filter { $0.condition != .inactive }
        self.maxConsecutive = maxConsecutive
        self.elementPreprocessor = elementPreprocessor
        self.elementMerger = elementMerger
    }
    
    func getExcludedSets() -> [StringSet] {
        let result = sets
            .filter { $0.condition == .excluded }
            .map { $0.set }
        return result
    }
    
    func getExcludedElements() -> Set<String> {
        let excludedSets = getExcludedSets()
        var result = StringSet()
        excludedSets.forEach {
            result.formUnion($0)
        }
        return result
    }
    
    func getRequiredSetsFiltered() throws -> [StringSet] {
        let excludedElements = getExcludedElements()
        let requiredSets = sets.filter { $0.condition == .required }
        let result = requiredSets.map {
            return $0.set.subtracting(excludedElements)
        }
        guard result.allSatisfy({ !$0.isEmpty }) else {
            throw PasswordGeneratorError.requiredSetCompletelyExcluded
        }
        return result
    }
    
    func getAllowedElementsFiltered() throws -> StringSet {
        let excludedElements = getExcludedElements()
        let allowedSets = sets
            .filter { $0.condition != .excluded }
            .map { $0.set }
        let allowedSetsFiltered = allowedSets.map {
            return $0.subtracting(excludedElements)
        }
        var result = StringSet()
        allowedSetsFiltered.forEach {
            result.formUnion($0)
        }
        if result.isEmpty {
            throw PasswordGeneratorError.notEnoughElementsToSample
        }
        return result
    }
}
