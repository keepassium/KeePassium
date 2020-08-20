//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum FileAccessError: LocalizedError {
    case timeout(fileProvider: FileProvider?)
    
    case noInfoAvailable
    
    case internalError
    
    case fileProviderDoesNotRespond(fileProvider: FileProvider?)
    
    case systemError(_ originalError: Error?)
    
    public var errorDescription: String? {
        switch self {
        case .timeout(let fileProvider):
            if let fileProvider = fileProvider {
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[FileAccessError/Timeout/knownFileProvider]",
                        bundle: Bundle.framework,
                        value: "%@ does not respond.",
                        comment: "Error message: file provider does not respond to requests (quickly enough). For example: `Google Drive does not respond`"),
                    fileProvider.localizedName
                )
            } else {
                return NSLocalizedString(
                    "[FileAccessError/Timeout/genericFileProvider]",
                    bundle: Bundle.framework,
                    value: "Storage provider does not respond.",
                    comment: "Error message: storage provider app (e.g. Google Drive) does not respond to requests (quickly enough).")
            }
        case .noInfoAvailable:
            assertionFailure("Should not be shown to the user")
            return nil
        case .internalError:
            return NSLocalizedString(
                "[FileAccessError/internalError]",
                bundle: Bundle.framework,
                value: "Internal KeePassium error, please tell us about it.",
                comment: "Error message shown when there's internal inconsistency in KeePassium.")
        case .fileProviderDoesNotRespond(let fileProvider):
            if let fileProvider = fileProvider {
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[FileAccessError/NoResponse/knownFileProvider]",
                        bundle: Bundle.framework,
                        value: "%@ does not respond.",
                        comment: "Error message: file provider does not respond to requests. For example: `Google Drive does not respond.`"),
                    fileProvider.localizedName
                )
            } else {
                return NSLocalizedString(
                    "[FileAccessError/NoResponse/genericFileProvider]",
                    bundle: Bundle.framework,
                    value: "Storage provider does not respond.",
                    comment: "Error message: storage provider app (e.g. Google Drive) does not respond to requests.")
            }
        case .systemError(let originalError):
            return originalError?.localizedDescription
        }
    }
    
    public static func make(from originalError: Error, fileProvider: FileProvider?) -> FileAccessError {
        let nsError = originalError as NSError
        Diag.error("""
            Failed to access the file \
            [fileProvider: \(fileProvider?.id ?? "nil"), systemError: \(nsError.debugDescription)]
            """)
        switch (nsError.domain, nsError.code) {
        case ("NSCocoaErrorDomain", 4101):
            fallthrough
            
        case ("NSCocoaErrorDomain", 4097): fallthrough
        case ("NSCocoaErrorDomain", 4099):
            return .fileProviderDoesNotRespond(fileProvider: fileProvider)
        default:
            return .systemError(originalError)
        }
    }
}
