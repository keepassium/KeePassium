//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum KeyFileError: LocalizedError {
    case unsupportedFormat
    case keyFileCorrupted
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return NSLocalizedString(
                "[KeyFileError/UnsupportedFormat/title]",
                bundle: Bundle.framework,
                value: "Unsupported key file format",
                comment: "Error message: unsupported/unknown format of a key file")
        case .keyFileCorrupted:
            return NSLocalizedString(
                "[KeyFileError/Corrupted/title]",
                bundle: Bundle.framework,
                value: "Key file is corrupted",
                comment: "Error message when the key file is misformatted or damaged")
        }
    }
}
