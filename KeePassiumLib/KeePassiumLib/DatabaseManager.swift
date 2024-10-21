//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

enum DatabaseLockReason {
    case userRequest
    case timeout
}

public class DatabaseManager {
    private init() {
    }

    public static func createDatabase(
        databaseURL: URL,
        password: String,
        keyFile: URLReference?,
        challengeHandler: ChallengeHandler?,
        template templateSetupHandler: @escaping (Group2) -> Void,
        completionQueue: DispatchQueue = .main,
        completion: @escaping ((Result<DatabaseFile, String>) -> Void)
    ) {
        let db2 = Database2.makeNewV4()
        guard let root2 = db2.root as? Group2 else { fatalError() }
        templateSetupHandler(root2)

        let databaseFile = DatabaseFile(
            database: db2,
            fileURL: databaseURL,
            fileProvider: nil, 
            status: []
        )
        db2.keyHelper.createCompositeKey(
            password: password,
            keyFile: keyFile,
            challengeHandler: challengeHandler,
            completion: { result in
                switch result {
                case .success(let compositeKey):
                    db2.changeCompositeKey(to: compositeKey)
                    completionQueue.async {
                        completion(.success(databaseFile))
                    }
                case .failure(let errorMessage):
                    Diag.error("Error creating composite key for a new database [message: \(errorMessage)]")
                    completionQueue.async {
                        completion(.failure(errorMessage))
                    }
                }
            }
        )
    }

    static func shouldBackupFiles(from location: URLReference.Location) -> Bool {
        switch location {
        case .external,
             .remote,
             .internalDocuments:
            return true
        case .internalBackup,
             .internalInbox:
            return false
        }
    }

    public static func getFallbackFile(for databaseRef: URLReference) -> URLReference? {
        let latestBackupURL = FileKeeper.shared.getBackupFileURL(
            nameTemplate: databaseRef.visibleFileName,
            mode: .overwriteLatest,
            timestamp: .now
        )
        guard let latestBackupURL = latestBackupURL else {
            return nil
        }
        do {
            let ref = try URLReference(from: latestBackupURL, location: .internalBackup)
            return ref
        } catch {
            Diag.error("Failed to create reference to fallback file [message: \(error.localizedDescription)]")
            return nil
        }
    }
}
