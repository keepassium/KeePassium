//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public struct LinkedDatabaseInfo {
    public let databaseRef: URLReference
    public let compositeKey: CompositeKey
}

public final class SpecialEntryParser {
    private var fileKeeperNotifications: FileKeeperNotifications!
    private var dbRefs = [URLReference]()
    private var keyFileRefs = [URLReference]()

    public init() {
        fileKeeperNotifications = FileKeeperNotifications(observer: self)
        fileKeeperNotifications.startObserving()
        updateFileRefs()
    }

    deinit {
        fileKeeperNotifications.stopObserving()
    }

    private func updateFileRefs() {
        dbRefs = FileKeeper.shared.getAllReferences(
            fileType: .database,
            includeBackup: false
        )
        keyFileRefs = FileKeeper.shared.getAllReferences(
            fileType: .keyFile,
            includeBackup: false
        )
    }

    public func extractLinkedDatabaseInfo(from entry: Entry) -> LinkedDatabaseInfo? {
        guard let possibleDatabaseName = getDatabaseFileName(from: entry),
              let dbRef = dbRefs.first(where: { $0.url?.lastPathComponent == possibleDatabaseName })
        else {
            return nil
        }

        var keyFileRef: URLReference?
        if let possibleKeyFileName = getKeyFileName(from: entry) {
            keyFileRef = keyFileRefs.first(where: { $0.url?.lastPathComponent == possibleKeyFileName })
            guard keyFileRef != nil else {
                Diag.warning("Cannot find specified key file, cancelling")
                return nil
            }
        }

        let compositeKey = CompositeKey(
            password: entry.resolvedPassword,
            keyFileRef: keyFileRef,
            challengeHandler: nil
        )
        Diag.info("Found entry with a linked database [withPassword: \(compositeKey.password.isNotEmpty), withKeyFile: \(compositeKey.keyFileRef != nil)]")
        return LinkedDatabaseInfo(databaseRef: dbRef, compositeKey: compositeKey)
    }

    private func getDatabaseFileName(from entry: Entry) -> String? {
        let urlString = entry.resolvedURL
        guard urlString.isNotEmpty,
              let url = URL(string: urlString)
        else {
            return nil
        }
        return url.lastPathComponent
    }

    private func getKeyFileName(from entry: Entry) -> String? {
        let urlString = entry.resolvedUserName
        guard urlString.isNotEmpty,
              let url = URL(string: urlString)
        else {
            return nil
        }
        return url.lastPathComponent
    }
}

extension SpecialEntryParser: FileKeeperObserver {
    public func fileKeeper(didAddFile urlRef: URLReference, fileType: FileType) {
        updateFileRefs()
    }
    public func fileKeeper(didRemoveFile urlRef: URLReference, fileType: FileType) {
        updateFileRefs()
    }
}
