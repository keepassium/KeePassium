//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import IntuneMAMSwift
import KeePassiumLib
import MSAL

final class MSALOneDriveAuthProvider: OneDriveAuthProvider {
    typealias CompletionHandler = (Result<OAuthToken, RemoteError>) -> Void
    internal static let redirectURI = "msauth.com.keepassium.intune://auth"

    private let msalApplication: MSALPublicClientApplication?
    private let msalInitializationError: RemoteError?

    private let config = OneDriveAuthConfig(
        redirectURI: redirectURI,
        scopes: [
            "user.read",
            "files.readwrite.all",
        ]
    )

    init() {
        do {
            var authority: MSALAuthority?
            if let authorityURLString = IntuneMAMSettings.aadAuthorityUriOverride, 
               let authorityURL = URL(string: authorityURLString)
            {
                authority = try MSALAADAuthority(url: authorityURL)
            }

            let msalConfiguration = MSALPublicClientApplicationConfig(
                clientId: config.clientID,
                redirectUri: config.redirectURI,
                authority: authority
            )
            msalConfiguration.clientApplicationCapabilities = ["ProtApp"] 

            msalApplication = try MSALPublicClientApplication(configuration: msalConfiguration)
            msalInitializationError = nil
        } catch {
            msalApplication = nil
            msalInitializationError = RemoteError.getEquivalent(for: error)

            let nsError = error as NSError
            Diag.error("Failed to initialize MSAL [message: \(nsError.description)]")
            return
        }
    }

    func acquireToken(
        presenter: UIViewController,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping CompletionHandler
    ) {
        guard let msalApplication else {
            Diag.warning("MSAL not initialized")
            completionQueue.addOperation { completion(.failure(self.msalInitializationError!)) }
            return
        }

        let webviewParameters = MSALWebviewParameters(authPresentationViewController: presenter)
        let interactiveParameters = MSALInteractiveTokenParameters(
            scopes: self.config.scopes,
            webviewParameters: webviewParameters
        )
        msalApplication.acquireToken(with: interactiveParameters) { [weak self] result, error in
            self?.handleMSALResponse(
                result,
                error: error,
                completionQueue: completionQueue,
                completion: completion
            )
        }
    }

    func acquireTokenSilent(
        token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping CompletionHandler
    ) {
        guard let msalApplication else {
            Diag.warning("MSAL not initialized")
            completionQueue.addOperation { completion(.failure(self.msalInitializationError!)) }
            return
        }

        guard let accountIdentifier = token.accountIdentifier else {
            let message = "Internal error: accountIdentifier is missing" 
            completionQueue.addOperation { completion(.failure(.appInternalError(message: message))) }
            return
        }
        guard let account = try? msalApplication.account(forIdentifier: accountIdentifier) else {
            return
        }
        let silentParameters = MSALSilentTokenParameters(scopes: config.scopes, account: account)
        msalApplication.acquireTokenSilent(with: silentParameters) { [weak self] result, error in
            self?.handleMSALResponse(
                result,
                error: error,
                completionQueue: completionQueue,
                completion: completion
            )
        }
    }

    private func handleMSALResponse(
        _ authResult: MSALResult?,
        error: Error?,
        completionQueue: OperationQueue,
        completion: @escaping CompletionHandler
    ) {
        guard let authResult, error == nil else {
            let msalError = error!
            let mappedError = RemoteError.getEquivalent(for: msalError)
            Diag.error("Failed to acquire token [message: \(msalError.localizedDescription)]")
            completionQueue.addOperation {
                completion(.failure(mappedError))
            }
            return
        }

        guard let expiresOn = authResult.expiresOn else {
            completionQueue.addOperation {
                Diag.error("MSAL token is missing expiry date")
                completion(.failure(.misformattedResponse))
            }
            return
        }

        var oauthToken = OAuthToken(
            accessToken: authResult.accessToken,
            refreshToken: "", 
            acquired: .now,
            lifespan: expiresOn.timeIntervalSinceNow
        )
        oauthToken.accountIdentifier = authResult.account.identifier
        Diag.debug("MSAL token acquired successfully")
        completionQueue.addOperation {
            completion(.success(oauthToken))
        }
    }
}

fileprivate extension RemoteError {
    static func getEquivalent(for error: Error) -> RemoteError {
        let nsError = error as NSError
        guard nsError.domain == MSALErrorDomain else {
            return .general(error: error)
        }

        switch nsError.code {
        case MSALError.userCanceled.rawValue:
            return .cancelledByUser
        case MSALError.interactionRequired.rawValue:
            return .authorizationRequired(message: LString.titleOneDriveRequiresSignIn)
        case MSALError.serverError.rawValue:
            return .serverSideError(message: nsError.localizedDescription)
        default:
            return .general(error: error)
        }
    }
}
