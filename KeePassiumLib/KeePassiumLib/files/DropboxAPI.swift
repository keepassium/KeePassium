//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

internal enum DropboxAPI {
    static var clientID: String {
        if BusinessModel.isIntuneEdition {
            return "ysbau47sryidrop"
        }
        switch BusinessModel.type {
        case .freemium:
            return "0der11zzfhricqu"
        case .prepaid:
            return "xploauielridw9m"
        }
    }

    static let callbackURLScheme = AppGroup.appURLScheme
    static let authRedirectURI = AppGroup.appURLScheme + "://dropbox-auth"
    static let defaultDrivePath = "/"
    static let maxUploadSize = 150 * 1024 * 1024

    static let tokenRequestURL = URL(string: "https://api.dropbox.com/oauth2/token")!
    static let itemMetadataURL = URL(string: "https://api.dropboxapi.com/2/files/get_metadata")!
    static let fileDownloadURL = URL(string: "https://content.dropboxapi.com/2/files/download")!
    static let fileUploadURL = URL(string: "https://content.dropboxapi.com/2/files/upload")!
    static let folderListURL = URL(string: "https://api.dropboxapi.com/2/files/list_folder")!
    static let folderListContinueURL = URL(string: "https://api.dropboxapi.com/2/files/list_folder/continue")!
    static let accountInfoURL = URL(string: "https://api.dropboxapi.com/2/users/get_current_account")!

    internal enum Keys {
        static let accessToken = "access_token"
        static let code = "code"
        static let expiresIn = "expires_in"
        static let refreshToken = "refresh_token"
        static let error = "error"
        static let errorSummary = "error_summary"
        static let authorization = "Authorization"
        static let contentType = "Content-Type"
        static let contentLength = "Content-Length"
        static let entries = "entries"
        static let name = "name"
        static let tag = ".tag"
        static let pathDisplay = "path_display"
        static let size = "size"
        static let clientModified = "client_modified"
        static let accountId = "account_id"
        static let email = "email"
        static let apiArg = "Dropbox-API-Arg"
        static let cursor = "cursor"
        static let hasMore = "has_more"
        static let accountType = "account_type"
        static let contentHash = "content_hash"
    }
}

extension DropboxAPI {
    class ResponseParser {
        static func parseJSONResponse(
            operation: String,
            item: DropboxItem? = nil,
            data: Data?,
            error: Error?
        ) -> Result<[String: Any], RemoteError> {
            if let error = error {
                Diag.error("Dropbox request failed [operation: \(operation), message: \(error.localizedDescription)]")
                return .failure(.general(error: error))
            }
            guard let data = data else {
                Diag.error("Dropbox request failed: no data received [operation: \(operation)]")
                return .failure(.emptyResponse)
            }

            guard let json = parseJSONDict(data: data) else {
                Diag.error("Dropbox request failed: misformatted response [operation: \(operation)]")
                if let string = String(data: data, encoding: .utf8) {
                    return .failure(.serverSideError(message: string))
                } else {
                    return .failure(.emptyResponse)
                }
            }

            if let serverError = getServerError(from: json, item: item) {
                Diag.error("Dropbox request failed: server-side error [operation: \(operation), message: \(serverError.localizedDescription)]")
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

        static func getServerError(from json: [String: Any], item: DropboxItem?) -> RemoteError? {
            guard let error = json[DropboxAPI.Keys.error] else {
                return nil
            }
            let errorDetails = json.description
            Diag.error(errorDetails)
            let message = (json[DropboxAPI.Keys.errorSummary] as? String) ?? "DropboxError"
            guard let errorDict = error as? [String: Any] else {
                return RemoteError.serverSideError(message: message)
            }
            guard let tag = errorDict[Keys.tag] as? String else {
                return RemoteError.serverSideError(message: message)
            }
            switch tag {
            case "invalid_access_token", "expired_access_token":
                Diag.warning("Authorization token expired")
                return .authorizationRequired(message: LString.titleDropboxRequiresSignIn)
            case "path":
                if let item = item {
                    Diag.warning("File does not exists anymore")
                    let error = NSError(
                        domain: NSCocoaErrorDomain,
                        code: CocoaError.fileNoSuchFile.rawValue,
                        userInfo: [
                            NSFilePathErrorKey: item.name
                        ]
                    )
                    return .general(error: error)
                } else {
                    Diag.warning("Server-side Dropbox error [message: \(message)]")
                    return .serverSideError(message: message)
                }
            default:
                Diag.warning("Server-side Dropbox error [message: \(message)]")
                return .serverSideError(message: message)
            }
        }
    }

}
