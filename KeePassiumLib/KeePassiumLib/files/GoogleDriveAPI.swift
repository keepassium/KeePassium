//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

internal enum GoogleDriveAPI {
    static var clientID: String {
        if BusinessModel.isIntuneEdition {
            return "563540931668-j6uf253opkpmu9jbtuk19r9n1cqe65si.apps.googleusercontent.com"
        }
        switch BusinessModel.type {
        case .freemium:
            return "563540931668-qep200es3dnjajnjcnk1dgfsdnm1v9f2.apps.googleusercontent.com"
        case .prepaid:
            return "563540931668-ig832ojb8oiko83l9no222ah4lqv7031.apps.googleusercontent.com"
        }
    }
    static var callbackURLScheme: String {
        if BusinessModel.isIntuneEdition {
            return "com.googleusercontent.apps.563540931668-j6uf253opkpmu9jbtuk19r9n1cqe65si"
        }
        switch BusinessModel.type {
        case .freemium:
            return "com.googleusercontent.apps.563540931668-qep200es3dnjajnjcnk1dgfsdnm1v9f2"
        case .prepaid:
            return "com.googleusercontent.apps.563540931668-ig832ojb8oiko83l9no222ah4lqv7031"
        }
    }

    static var authRedirectURI = callbackURLScheme + "://"
    static let authScope = [
        "https://www.googleapis.com/auth/drive",
    ]
    static let maxUploadSize = 50 * 1024 * 1024
    static let tokenRequestURL = URL(string: "https://www.googleapis.com/oauth2/v4/token")!
    static let tokenRefreshURL = URL(string: "https://oauth2.googleapis.com/token")!
    static let accountInfoURL = URL(string: "https://www.googleapis.com/drive/v3/about?fields=user(emailAddress),canCreateDrives")!

    static let fileFields = "id,mimeType,name,createdTime,modifiedTime,size,shortcutDetails,driveId,trashed,md5Checksum"

    internal enum Keys {
        static let clientID = "client_id"
        static let responseType = "response_type"
        static let scope = "scope"
        static let redirectURI = "redirect_uri"
        static let accessToken = "access_token"
        static let code = "code"
        static let expiresIn = "expires_in"
        static let refreshToken = "refresh_token"
        static let contentType = "Content-Type"
        static let contentLength = "Content-Length"
        static let error = "error"
        static let errorDescription = "error_description"
        static let message = "message"
        static let status = "status"
        static let authorization = "Authorization"
        static let files = "files"
        static let name = "name"
        static let id = "id"
        static let mimeType = "mimeType"
        static let folderMimeType = "application/vnd.google-apps.folder"
        static let createdTime = "createdTime"
        static let modifiedTime = "modifiedTime"
        static let size = "size"
        static let trashed = "trashed"
        static let email = "email"
        static let emailAddress = "emailAddress"
        static let user = "user"
        static let canCreateDrives = "canCreateDrives"
        static let hd = "hd"
        static let shortcutDetails = "shortcutDetails"
        static let targetID = "targetId"
        static let targetMimeType = "targetMimeType"
        static let driveID = "driveId"
        static let fields = "fields"
        static let nextPageToken = "nextPageToken"
        static let includeItemsFromAllDrives = "includeItemsFromAllDrives"
        static let supportsAllDrives = "supportsAllDrives"
        static let corpora = "corpora"
        static let q = "q"
        static let pageToken = "pageToken"
        static let alt = "alt"
        static let uploadType = "uploadType"
        static let parents = "parents"
        static let md5Checksum = "md5Checksum"
    }
}

extension GoogleDriveAPI {
    class ResponseParser {
        static func parseJSONResponse(
            operation: String,
            data: Data?,
            error: Error?
        ) -> Result<[String: Any], RemoteError> {
            if let error = error {
                Diag.error("Google Drive request failed [operation: \(operation), message: \(error.localizedDescription)]")
                return .failure(.general(error: error))
            }
            guard let data = data else {
                Diag.error("Google Drive request failed: no data received [operation: \(operation)]")
                return .failure(.emptyResponse)
            }

            guard let json = parseJSONDict(data: data) else {
                Diag.error("Google Drive request failed: misformatted response [operation: \(operation)]")
                return .failure(.emptyResponse)
            }

            if let serverError = getServerError(from: json) {
                Diag.error("Google Drive request failed: server-side error [operation: \(operation), message: \(serverError.localizedDescription)]")
                return .failure(serverError)
            }
            return .success(json)
        }

        static func parseJSONDict(data: Data) -> [String: Any]? {
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any] else {
                    Diag.error("Unexpected JSON format")
                    return nil
                }
                return json
            } catch {
                Diag.error("Failed to parse JSON data [message: \(error.localizedDescription)")
                return nil
            }
        }

        static func getServerError(from json: [String: Any]) -> RemoteError? {
            guard let error = json[GoogleDriveAPI.Keys.error] else {
                return nil
            }
            let errorDetails = json.description
            Diag.error(errorDetails)
            if let errorDict = error as? [String: Any] {
                let message = (errorDict[GoogleDriveAPI.Keys.message] as? String) ?? "UnknownError"
                let status = errorDict[GoogleDriveAPI.Keys.status] as? String
                let errorDescription = "status: \(status ?? "nil"), message: \(message)"
                switch status {
                case "UNAUTHENTICATED":
                    Diag.warning("User not authenticated [\(errorDescription)]")
                    return .authorizationRequired(message: LString.titleGoogleDriveRequiresSignIn)
                case "PERMISSION_DENIED":
                    return .authorizationRequired(message: message)
                default:
                    Diag.warning("Server-side Gooogle Drive error [\(errorDescription)]")
                    return RemoteError.serverSideError(message: message)
                }
            }

            let errorKind = (error as? String) ?? "GoogleDriveError"
            switch errorKind {
            case "invalid_grant":
                Diag.warning("Authorization token expired")
                return .authorizationRequired(message: LString.titleGoogleDriveRequiresSignIn)
            default:
                let errorDescription = (json[GoogleDriveAPI.Keys.errorDescription] as?  String) ?? errorKind
                Diag.warning("Server-side Google Drive error [message: \(errorDescription)]")
                return .serverSideError(message: errorDescription)
            }
        }
    }

}
