//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import AuthenticationServices

class BasicOneDriveAuthProvider: NSObject, OneDriveAuthProvider {
    private enum TokenOperation: CustomStringConvertible {
        case authorization(code: String)
        case refresh(token: OAuthToken)
        var description: String {
            switch self {
            case .authorization:
                return "tokenAuth"
            case .refresh:
                return "tokenRefresh"
            }
        }
    }

    private let config = OneDriveAuthConfig(
        redirectURI: "\(AppGroup.appURLScheme)://onedrive-auth",
        scopes: ["user.read", "files.readwrite.all", "offline_access"]
    )

    private let urlSession: URLSession
    private var presentationAnchors = [ObjectIdentifier: Weak<ASPresentationAnchor>]()

    init(urlSession: URLSession) {
        self.urlSession = urlSession
        super.init()
    }
}

extension BasicOneDriveAuthProvider {
    func acquireToken(
        presenter: UIViewController,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, OneDriveError>) -> Void
    ) {
        Diag.info("Authenticating with OneDrive")
        let webAuthSession = ASWebAuthenticationSession(
            url: getAuthURL(config: config),
            callbackURLScheme: OneDriveAPI.callbackURLScheme,
            completionHandler: { [self] (callbackURL: URL?, error: Error?) in
                handleAuthResponse(
                    callbackURL: callbackURL,
                    error: error,
                    completionQueue: completionQueue,
                    completion: completion
                )
            }
        )
        presentationAnchors[ObjectIdentifier(webAuthSession)] = Weak(presenter.view.window!)
        webAuthSession.presentationContextProvider = self
        webAuthSession.prefersEphemeralWebBrowserSession = false

        webAuthSession.start()
    }

    private func handleAuthResponse(
        callbackURL: URL?,
        error: Error?,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, OneDriveError>) -> Void
    ) {
        if let error = error as NSError? {
            let isCancelled =
            (error.domain == ASWebAuthenticationSessionErrorDomain) &&
            (error.code == ASWebAuthenticationSessionError.canceledLogin.rawValue)
            if isCancelled {
                completionQueue.addOperation {
                    Diag.info("Authentication cancelled by user")
                    completion(.failure(.cancelledByUser))
                }
            } else {
                completionQueue.addOperation {
                    Diag.error("Authentication failed [message: \(error.localizedDescription)]")
                    completion(.failure(.general(error: error)))
                }
            }
            return
        }

        guard let callbackURL = callbackURL,
              let urlComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
              let queryItems = urlComponents.queryItems
        else {
            completionQueue.addOperation {
                Diag.error("Authentication failed: empty or misformatted callback URL")
                completion(.failure(.emptyResponse))
            }
            return
        }

        let error = queryItems.getValue(name: OneDriveAPI.Keys.error)
        let errorSubcode = queryItems.getValue(name: OneDriveAPI.Keys.errorSubcode)
        switch (error, errorSubcode) {
        case ("access_denied", "cancel"):
            completionQueue.addOperation {
                Diag.error("Access denied, authentication cancelled")
                completion(.failure(.cancelledByUser))
            }
            return
        default:
            break
        }

        if let errorDescription = queryItems
            .getValue(name: OneDriveAPI.Keys.errorDescription)?
            .removingPercentEncoding?
            .replacingOccurrences(of: "+", with: " ")
        {
            completionQueue.addOperation {
                Diag.error("Authentication failed: \(errorDescription)")
                completion(.failure(.serverSideError(message: errorDescription)))
            }
            return
        }

        guard let codeItem = queryItems[OneDriveAPI.Keys.code],
              let authCodeString = codeItem.value
        else {
            completionQueue.addOperation {
                Diag.error("Authentication failed: OAuth token not found in response")
                completion(.failure(.misformattedResponse))
            }
            return
        }
        getToken(
            operation: .authorization(code: authCodeString),
            completionQueue: completionQueue,
            completion: completion)
    }
}

extension BasicOneDriveAuthProvider {
    func acquireTokenSilent(
        token: OAuthToken,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, OneDriveError>) -> Void
    ) {
        if Date.now < (token.acquired + token.halflife) {
            completionQueue.addOperation {
                completion(.success(token))
            }
        } else if token.refreshToken.isEmpty {
            completionQueue.addOperation {
                Diag.error("OAuth token expired and there is no refresh token")
                completion(.failure(.cannotRefreshToken))
            }
        } else {
            getToken(
                operation: .refresh(token: token),
                completionQueue: completionQueue,
                completion: completion
            )
        }
    }
}

extension BasicOneDriveAuthProvider {
    private func getAuthURL(config: OneDriveAuthConfig) -> URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "login.microsoftonline.com"
        urlComponents.path = "/common/oauth2/v2.0/authorize"
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "prompt", value: "select_account"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
        ]
        return urlComponents.url!
    }

    private func getToken(
        operation: TokenOperation,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, OneDriveError>) -> Void
    ) {
        Diag.debug("Acquiring OAuth token [operation: \(operation)]")
        var urlRequest = URLRequest(url: OneDriveAPI.tokenRequestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/x-www-form-urlencoded; charset=UTF-8",
            forHTTPHeaderField: OneDriveAPI.Keys.contentType)

        var postParams = [
            "client_id=\(config.clientID)",
            "redirect_uri=\(config.redirectURI)",
        ]

        let refreshToken: String?
        switch operation {
        case .authorization(let authCode):
            refreshToken = nil
            postParams.append("code=\(authCode)")
            postParams.append("grant_type=authorization_code")
        case .refresh(let token):
            refreshToken = token.refreshToken
            postParams.append("refresh_token=\(token.refreshToken)")
            postParams.append("grant_type=refresh_token")
        }

        let postData = postParams
            .joined(separator: "&")
            .data(using: .ascii, allowLossyConversion: false)!
        let postLength = "\(postData.count)"
        urlRequest.setValue(postLength, forHTTPHeaderField: OneDriveAPI.Keys.contentLength)
        urlRequest.httpBody = postData

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = OneDriveAPI.ResponseParser
                    .parseJSONResponse(operation: operation.description, data: data, error: error)
            switch result {
            case .success(let json):
                if let token = self.parseTokenResponse(json: json, currentRefreshToken: refreshToken) {
                    Diag.debug("OAuth token acquired successfully [operation: \(operation)]")
                    completionQueue.addOperation {
                        completion(.success(token))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
            }
        }
        dataTask.resume()
    }

    private func parseTokenResponse(json: [String: Any], currentRefreshToken: String?) -> OAuthToken? {
        guard let accessToken = json[OneDriveAPI.Keys.accessToken] as? String else {
            Diag.error("Failed to parse token response: access_token missing")
            return nil
        }
        guard let expires_in = json[OneDriveAPI.Keys.expiresIn] as? Int else {
            Diag.error("Failed to parse token response: expires_in missing")
            return nil
        }
        let newRefreshToken = json[OneDriveAPI.Keys.refreshToken] as? String
        guard let refreshToken = (newRefreshToken ?? currentRefreshToken) else {
            Diag.error("Failed to parse token response: refresh_token missing")
            return nil
        }

        let token = OAuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            acquired: Date.now,
            lifespan: TimeInterval(expires_in)
        )
        return token
    }
}

extension BasicOneDriveAuthProvider: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let sessionObjectID = ObjectIdentifier(session)
        return presentationAnchors[sessionObjectID]!.value!
    }
}
