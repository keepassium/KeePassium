//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public extension KeyHelper {

    func createCompositeKey(
        password: String,
        keyFile keyFileRef: URLReference?,
        challengeHandler: ChallengeHandler?,
        timeout: Timeout = Timeout(duration: FileDataProvider.defaultTimeoutDuration),
        completionQueue: DispatchQueue = .main,
        completion: @escaping ((Result<CompositeKey, String>) -> Void)
    ) {
        guard let keyFileRef = keyFileRef else {
            buildCompositeKey(
                password: password,
                keyFileData: SecureBytes.empty(),
                challengeHandler: challengeHandler,
                completionQueue: completionQueue,
                completion: completion
            )
            return
        }

        FileDataProvider.read(keyFileRef, timeout: timeout, completionQueue: nil) { result in
            assert(!Thread.isMainThread)
            switch result {
            case .success(let keyFileData):
                self.buildCompositeKey(
                    password: password,
                    keyFileData: SecureBytes.from(keyFileData),
                    challengeHandler: challengeHandler,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let fileAccessError):
                Diag.error("Failed to open key file [error: \(fileAccessError.localizedDescription)]")
                completionQueue.async {
                    completion(.failure(LString.Error.failedToOpenKeyFile))
                }
            }
        }
    }

    private func buildCompositeKey(
        password: String,
        keyFileData: SecureBytes,
        challengeHandler: ChallengeHandler?,
        completionQueue: DispatchQueue,
        completion: @escaping ((Result<CompositeKey, String>) -> Void)
    ) {
        let passwordData = self.getPasswordData(password: password)
        if passwordData.isEmpty && keyFileData.isEmpty && challengeHandler == nil {
            Diag.error("Password and key file are both empty")
            completionQueue.async {
                completion(.failure(LString.Error.passwordAndKeyFileAreBothEmpty))
            }
        }

        do {
            let staticComponents = try self.combineComponents(
                passwordData: passwordData, 
                keyFileData: keyFileData    
            ) 
            let compositeKey = CompositeKey(
                staticComponents: staticComponents,
                challengeHandler: challengeHandler)
            Diag.debug("New composite key created successfully")
            completionQueue.async {
                completion(.success(compositeKey))
            }
        } catch let error as KeyFileError {
            Diag.error("Key file error [reason: \(error.localizedDescription)]")
            completionQueue.async {
                completion(.failure(error.localizedDescription))
            }
        } catch {
            let message = "Caught unrecognized exception" 
            assertionFailure(message)
            Diag.error(message)
            completionQueue.async {
                completion(.failure(message))
            }
        }
    }
}
