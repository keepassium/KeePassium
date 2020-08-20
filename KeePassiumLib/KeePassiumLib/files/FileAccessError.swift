//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum FileAccessError: LocalizedError {
    case timeout
    
    case noInfoAvailable
    
    case internalError
    
    case accessError(_ originalError: Error?)
    
    public var errorDescription: String? {
        switch self {
        case .timeout:
            return NSLocalizedString(
                "[FileAccessError/timeout]",
                bundle: Bundle.framework,
                value: "Storage provider did not respond in a timely manner",
                comment: "Error message shown when file access operation has been aborted on timeout.")
        case .noInfoAvailable:
            assertionFailure("Should not be shown to the user")
            return nil
        case .internalError:
            return NSLocalizedString(
                "[FileAccessError/internalError]",
                bundle: Bundle.framework,
                value: "Internal KeePassium error, please tell us about it.",
                comment: "Error message shown when there's internal inconsistency in KeePassium.")
        case .accessError(let originalError):
            return originalError?.localizedDescription
        }
    }
}
