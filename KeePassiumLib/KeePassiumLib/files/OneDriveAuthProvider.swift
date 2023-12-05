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
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, OneDriveError>) -> Void
    )
    func acquireTokenSilent(
        token: OAuthToken,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, OneDriveError>) -> Void
    )
}
