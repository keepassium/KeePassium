//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

internal enum OneDriveAPI {
    static var clientID: String {
        if BusinessModel.isIntuneEdition {
            return "292a80b3-139a-4165-a20d-b2d2e764e538"
        }
        switch BusinessModel.type {
        case .freemium:
            return "cd88bd1f-abdf-4d0f-921e-d8acbf02e240"
        case .prepaid:
            return "c3885b4b-5dac-43a6-af93-c869c1a8328b"
        }
    }

    static let callbackURLScheme = AppGroup.appURLScheme
    static let tokenRequestURL = URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
    static let itemFields = "id,name,size,createdDateTime,lastModifiedDateTime,folder,file,remoteItem"
    static let childrenListLimit = 500

    static let mainEndpoint = "https://graph.microsoft.com/v1.0"
    static let defaultDrivePath = "/me/drive"
    static let personalDriveRootPath = defaultDrivePath + "/root"
    static let sharedWithMeRootPath = defaultDrivePath + "/sharedWithMe"

    static let maxUploadSize = 60 * 1024 * 1024 

    internal enum Keys {
        static let accessToken = "access_token"
        static let authorization = "Authorization"
        static let code = "code"
        static let contentLength = "Content-Length"
        static let contentRange = "Content-Range"
        static let contentType = "Content-Type"
        static let createdDateTime = "createdDateTime"
        static let displayName = "displayName"
        static let driveId = "driveId"
        static let driveType = "driveType"
        static let email = "email"
        static let error = "error"
        static let errorSubcode = "error_subcode"
        static let errorDescription = "error_description"
        static let errorURI = "error_uri"
        static let expiresIn = "expires_in"
        static let id = "id"
        static let file = "file"
        static let folder = "folder"
        static let lastModifiedDateTime = "lastModifiedDateTime"
        static let message = "message"
        static let name = "name"
        static let owner = "owner"
        static let parentReference = "parentReference"
        static let path = "path"
        static let refreshToken = "refresh_token"
        static let remoteItem = "remoteItem"
        static let size = "size"
        static let suberror = "suberror"
        static let uploadUrl = "uploadUrl"
        static let user = "user"
        static let value = "value"
        static let hashes = "hashes"
        static let hash = "sha256Hash"
    }
}

extension OneDriveAPI {
    class ResponseParser {
        static func parseJSONResponse(
            operation: String,
            data: Data?,
            error: Error?
        ) -> Result<[String: Any], RemoteError> {
            if let error = error {
                Diag.error("OneDrive request failed [operation: \(operation), message: \(error.localizedDescription)]")
                return .failure(.general(error: error))
            }
            guard let data = data else {
                Diag.error("OneDrive request failed: no data received [operation: \(operation)]")
                return .failure(.emptyResponse)
            }

            guard let json = parseJSONDict(data: data) else {
                Diag.error("OneDrive request failed: misformatted response [operation: \(operation)]")
                return .failure(.emptyResponse)
            }

            if let serverError = getServerError(from: json) {
                Diag.error("OneDrive request failed: server-side error [operation: \(operation), message: \(serverError.localizedDescription)]")
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
            guard let error = json[OneDriveAPI.Keys.error] else {
                return nil
            }
            let errorDetails = json.description
            Diag.error(errorDetails)
            if let errorDict = error as? [String: Any] {
                let message = (errorDict[OneDriveAPI.Keys.message] as? String) ?? "UnknownError"
                return RemoteError.serverSideError(message: message)
            }

            let errorKind = (error as? String) ?? "OneDriveError"
            let suberrorKind = json[OneDriveAPI.Keys.suberror] as? String
            switch (errorKind, suberrorKind) {
            case ("invalid_grant", "token_expired"),
                ("invalid_grant", .none):
                Diag.warning("Authorization token expired")
                return .authorizationRequired(message: LString.titleOneDriveRequiresSignIn)
            case ("invalid_grant", _):
                Diag.warning("OneDrive authentication problem")
                return .authorizationRequired(message: LString.titleOneDriveRequiresSignIn)
            default:
                let errorDescription = (json[OneDriveAPI.Keys.errorDescription] as?  String) ?? errorKind
                Diag.warning("Server-side OneDrive error [message: \(errorDescription)]")
                return .serverSideError(message: errorDescription)
            }
        }
    }

}
