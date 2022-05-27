//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class PasswordGeneratorParams: Codable, Equatable {
    public var basicModeConfig = BasicPasswordGeneratorParams()
    public var customModeConfig = CustomPasswordGeneratorParams()
    public var passphraseModeConfig = PassphraseGeneratorParams()
    
    public var lastMode = PasswordGeneratorMode.basic
    
    init() {
    }

    public static func == (lhs: PasswordGeneratorParams, rhs: PasswordGeneratorParams) -> Bool {
        return (lhs.basicModeConfig == rhs.basicModeConfig) &&
               (lhs.customModeConfig == rhs.customModeConfig) &&
               (lhs.passphraseModeConfig == rhs.passphraseModeConfig)
    }
}

extension PasswordGeneratorParams {
    public func serialize() -> Data {
        let encoder = JSONEncoder()
        let encodedData = try! encoder.encode(self)
        return encodedData
    }
    
    public static func deserialize(from data: Data?) -> PasswordGeneratorParams? {
        guard let data = data else { return nil }
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(PasswordGeneratorParams.self, from: data)
            return result
        } catch {
            Diag.error("Failed to parse password generator settings, ignoring [message: \(error.localizedDescription)]")
            return nil
        }
    }
}
