//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum DatabaseError: LocalizedError {
    case loadError(reason: LoadErrorReason)
    case invalidKey
    case saveError(reason: String)
    
    public enum LoadErrorReason: LocalizedError {
        case headerError(reason: String)
        case cryptoError(_ reason: CryptoError)
        case keyFileError(_ reason: KeyFileError)
        case challengeResponseError(_ reason: ChallengeResponseError)
        case formatError(reason: String)
        case gzipError(reason: String)
        public var errorDescription: String? {
            switch self {
            case .headerError(let reason):
                return reason
            case .cryptoError(let underlyingError):
                return underlyingError.localizedDescription
            case .keyFileError(let underlyingError):
                return underlyingError.localizedDescription
            case .challengeResponseError(let underlyingError):
                return underlyingError.localizedDescription
            case .formatError(let reason):
                return reason
            case .gzipError(let reason):
                return reason
            }
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .loadError:
            return NSLocalizedString(
                "[DatabaseError] Cannot open database",
                bundle: Bundle.framework,
                value: "Cannot open database",
                comment: "Error message while opening a database")
        case .invalidKey:
            return NSLocalizedString(
                "[DatabaseError] Invalid password or key file",
                bundle: Bundle.framework,
                value: "Invalid password or key file",
                comment: "Error message: user provided a wrong master key for decryption.")
        case .saveError:
            return NSLocalizedString(
                "[DatabaseError] Cannot save database",
                bundle: Bundle.framework,
                value: "Cannot save database",
                comment: "Error message while saving a database")
        }
    }
    public var failureReason: String? {
        switch self {
        case .loadError(let reason):
            return reason.localizedDescription
        case .saveError(let reason):
            return reason
        default:
            return nil
        }
    }
}
