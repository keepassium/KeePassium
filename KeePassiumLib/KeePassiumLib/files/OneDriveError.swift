//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum OneDriveError: LocalizedError {
    case cancelledByUser
    case emptyResponse
    case misformattedResponse
    case cannotRefreshToken
    case authorizationRequired
    case serverSideError(message: String)
    case general(error: Error)
    case appInternalError(message: String)

    public var errorDescription: String? {
        switch self {
        case .cancelledByUser:
            return "Cancelled by user." 
        case .emptyResponse:
            return "Server response is empty."
        case .misformattedResponse:
            return "Unexpected server response format."
        case .cannotRefreshToken:
            return "Cannot renew access token."
        case .authorizationRequired:
            return LString.titleOneDriveRequiresSignIn
        case .serverSideError(let message):
            return message
        case .general(let error):
            let nsError = error as NSError
            if nsError.domain == "MSALErrorDomain",
               let msalDescription = nsError.userInfo["MSALErrorDescriptionKey"] as? String
            {
                return msalDescription
            }
            return error.localizedDescription
        case .appInternalError(let message):
            return message
        }
    }
}
