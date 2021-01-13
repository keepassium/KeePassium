//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class UserNameHelper {
    static func getUserNameSuggestions(from database: Database, count: Int) -> [String] {
        assert(count >= 2)
        var result = [String]()
        var namesLeft = count
        if let defaultUserName = getDefaultUserName(from: database) {
            result.append(defaultUserName)
            namesLeft -= 1
        }
        result.append(contentsOf: getUniqueUserNames(from: database).prefix(namesLeft - 1))
        return result
    }
    
    static func getUniqueUserNames(from database: Database) -> [String] {
        let defaultUserName = getDefaultUserName(from: database)

        var allEntries = [Entry]()
        database.root?.collectAllEntries(to: &allEntries)
        let allUserNames = allEntries
            .filter { !$0.isDeleted }
            .compactMap { $0.resolvedUserName}
            .filter { $0.isNotEmpty && ($0 != defaultUserName) }
        
        var usageCount = [String: Int]()
        for userName in allUserNames {
            usageCount[userName] = (usageCount[userName] ?? 0) + 1
        }
        
        let uniqueUserNamesSorted = usageCount
            .sorted { $0.value > $1.value }
            .map { $0.key }
        
        return uniqueUserNamesSorted
    }
    
    static func getDefaultUserName(from database: Database) -> String? {
        if let db2 = database as? Database2, db2.defaultUserName.isNotEmpty {
            return db2.defaultUserName
        } else {
            return nil
        }
    }
    
    static func getRandomUserName() -> String {
        return UserNameGenerator.generate()
    }
    
    private class UserNameGenerator {
        static let vowels = ["a","e","i","o","u"]
        static let consonants = ["b","c","d","f","g","h","j","k","l","m","n","p","q","r","s","t","v","w","x","y","z"]
        
        static func generate(length: Int = 8) -> String {
            assert(length > 0)
            var randomIndices = [UInt8]()
            do {
                let randomBytes = try CryptoManager.getRandomBytes(count: length)
                randomIndices = randomBytes.bytesCopy()
            } catch {
                for i in 0..<length {
                    randomIndices[i] = UInt8.random(in: 0..<255)
                }
            }
            
            var chars = [String]()
            for i in 0..<length {
                if i % 2 == 0 {
                    chars.append(consonants[Int(randomIndices[i]) % consonants.count])
                } else {
                    chars.append(vowels[Int(randomIndices[i]) % vowels.count])
                }
            }
            return chars.joined()
        }
    }
}
