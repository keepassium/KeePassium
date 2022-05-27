//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class PasswordGenerator {
    
    public typealias ElementPreprocessingFunction = (inout [String]) -> Void
    
    public typealias ElementMergingFunction = ([String]) -> String
    
    internal var rng = SecureRandomNumberGenerator()
    
    public init() {
    }
    
    public func generate(with requirements: PasswordGeneratorRequirements) throws -> String {
        let targetLength = requirements.length
        guard targetLength >= 0 else {
            throw PasswordGeneratorError.desiredLengthTooShort(minimum: 0)
        }

        let requiredSets = try requirements.getRequiredSetsFiltered()
        if requiredSets.count > targetLength {
            throw PasswordGeneratorError.desiredLengthTooShort(minimum: requiredSets.count)
        }
        let requiredElementsSample: [String] = try requiredSets.map {
            if let result = $0.randomElement(using: &rng) {
                return result
            } else {
                assertionFailure("A required set is empty. This should have been checked before.")
                throw PasswordGeneratorError.requiredSetCompletelyExcluded
            }
        }
        
        var pickedElements = requiredElementsSample
        
        let fillerCount = targetLength - requiredElementsSample.count
        if fillerCount > 0 {
            let allowedElements = try requirements.getAllowedElementsFiltered()
            guard allowedElements.count > 0 else {
                assertionFailure("An allowed set is empty. This cannot be possible here.")
                throw PasswordGeneratorError.notEnoughElementsToSample
            }
            for _ in 0..<fillerCount {
                if let element = allowedElements.randomElement(using: &rng) {
                    pickedElements.append(element)
                } else {
                    assertionFailure("Should not be here")
                    throw PasswordGeneratorError.notEnoughElementsToSample
                }
            }
        }

        if let preprocessorFunction = requirements.elementPreprocessor {
            preprocessorFunction(&pickedElements)
        }
        
        guard canSatisfy(maxConsecutive: requirements.maxConsecutive, with: pickedElements) else {
            throw PasswordGeneratorError.maxConsecutiveNotSatisfiable
        }
        var attemptsLeft = 10
        repeat {
            pickedElements.shuffle(using: &rng)
            attemptsLeft -= 1
            if attemptsLeft < 0 {
                throw PasswordGeneratorError.maxConsecutiveNotSatisfiable
            }
        } while !isSatisfied(maxConsecutive: requirements.maxConsecutive, with: pickedElements)

        if let mergingFunction = requirements.elementMerger {
            return mergingFunction(pickedElements)
        } else {
            return pickedElements.joined()
        }
    }
    
    private func canSatisfy(maxConsecutive: Int?, with elements: [String]) -> Bool {
        guard let maxConsecutive = maxConsecutive else {
            return true
        }
        guard maxConsecutive > 0 else {
            return false
        }
        let uniqueElements = StringSet(elements)
        return (uniqueElements.count > 1) || (maxConsecutive >= elements.count)
    }
    
    private func isSatisfied(maxConsecutive: Int?, with elements: [String]) -> Bool {
        guard let maxConsecutive = maxConsecutive else {
            return true
        }
        guard maxConsecutive > 0 else {
            return false
        }
        
        var repeats = 0
        var maxRepeats = 0
        var previousElement: String? = nil
        for element in elements {
            if element == previousElement {
                repeats += 1
                continue
            }
            previousElement = element
            maxRepeats = max(maxRepeats, repeats)
            repeats = 1
        }
        maxRepeats = max(maxRepeats, repeats) 
        return maxRepeats <= maxConsecutive
    }
}

