//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public protocol OneDriveAuthProvider {
    func acquireToken(
        presenter: UIViewController,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    )
    func acquireTokenSilent(
        token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    )
}
