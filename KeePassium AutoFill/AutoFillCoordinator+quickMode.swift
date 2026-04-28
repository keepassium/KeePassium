//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension AutoFillCoordinator {
    internal func _findDatabase(for record: QuickTypeAutoFillRecord) -> URLReference? {
        let dbRefs = FileKeeper.shared.getAllReferences(fileType: .database, includeBackup: false)
        let matchingDatabase = dbRefs.first {
            $0.fileProvider == record.fileProvider && $0.getDescriptor() == record.fileDescriptor
        }
        return matchingDatabase
    }

    internal func _findEntry(
        matching record: QuickTypeAutoFillRecord,
        in databaseFile: DatabaseFile
    ) -> Entry? {
        let options = Settings.current.autoFillInclusionOptions
        guard let entry = databaseFile.database.root?.findEntry(byUUID: record.itemID)
        else {
            return nil
        }

        let parentGroup2 = entry.parent as? Group2
        let includeFromGroup = parentGroup2?.shouldIncludeInAutoFill(with: options) ?? true
        guard includeFromGroup, entry.isAutoFillable(with: options) else {
            return nil
        }
        return entry
    }

    private func returnQuickTypeEntry(
        matching record: QuickTypeAutoFillRecord,
        in databaseFile: DatabaseFile
    ) {
        assert(!hasUI, "This should run only in pre-UI mode")
        guard let foundEntry = _findEntry(matching: record, in: databaseFile) else {
            _cancelRequest(.credentialIdentityNotFound)
            return
        }
        log.trace("returnQuickTypeEntry")
        _returnEntry(
            foundEntry,
            from: databaseFile,
            shouldSave: false,
            keepClipboardIntact: false
        )
    }
}

extension AutoFillCoordinator: DatabaseLoaderDelegate {
    func databaseLoader(_ databaseLoader: DatabaseLoader, willLoadDatabase dbRef: URLReference) {
        assert(!hasUI, "This should run only in pre-UI mode")
    }

    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didChangeProgress progress: ProgressEx,
        for dbRef: URLReference
    ) {
    }

    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didFailLoading dbRef: URLReference,
        with error: DatabaseLoader.Error
    ) {
        assert(!hasUI, "This should run only in pre-UI mode")
        _quickTypeDatabaseLoader = nil
        switch error {
        case .cancelledByUser:
            assertionFailure("This should not be possible")
            log.error("DB loading was cancelled without UI, cancelling request.")
            _cancelRequest(.failed)
        case .invalidKey:
            log.error("DB loading failed: invalid key. Switching to UI")
            _cancelRequest(.userInteractionRequired)
        default:
            log.error("DB loading failed: \(error.localizedDescription, privacy: .public). Switching to UI")
            _cancelRequest(.userInteractionRequired)
        }
    }

    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didLoadDatabase dbRef: URLReference,
        databaseFile: DatabaseFile,
        withWarnings warnings: DatabaseLoadingWarnings
    ) {
        assert(!hasUI, "This should run only in pre-UI mode")
        _quickTypeDatabaseLoader = nil
        guard let record = _quickTypeRequiredRecord else {
            log.error("quickTypeRequiredRecord is unexpectedly nil, switching to UI")
            assertionFailure()
            _cancelRequest(.userInteractionRequired)
            return
        }
        returnQuickTypeEntry(matching: record, in: databaseFile)
    }
}
