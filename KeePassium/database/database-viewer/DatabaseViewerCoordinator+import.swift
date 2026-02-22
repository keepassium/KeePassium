//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import UniformTypeIdentifiers

extension DatabaseViewerCoordinator {
    internal func _importDatabaseFromEnpassJSON() {
        importGroupsAndEntries(type: .json) { fileURL, group in
            let importer = EnpassImporter()
            return try importer.importFromJSON(fileURL: fileURL, group: group)
        }
    }

    internal func _importDatabaseFromBitwardenJSON() {
        importGroupsAndEntries(type: .json) { fileURL, group in
            let importer = BitwardenImporter()
            return try importer.importFromJSON(fileURL: fileURL, group: group)
        }
    }

    internal func _importDatabaseFromApplePasswordsCSV() {
        importGroupsAndEntries(type: .commaSeparatedText) { fileURL, group in
            let importer = ApplePasswordsImporter()
            return (try importer.importFromCSV(fileURL: fileURL, group: group), [])
        }
    }

    internal func _importDatabaseFromOnePassword1PUX() {
        importGroupsAndEntries(type: .data) { fileURL, group in
            let importer = OnePasswordImporter()
            return try importer.importFrom1PUX(fileURL: fileURL, group: group)
        }
    }
}

extension DatabaseViewerCoordinator {
    private func importGroupsAndEntries(
        type: UTType,
        provider: @escaping (URL, Group) throws -> ([Entry], [Group])
    ) {
        guard let currentGroup = _currentGroup else {
            assertionFailure("No group selected")
            return
        }

        let importHelper = FileImportHelper()
        importHelper.handler = { [weak self] fileURL in
            defer {
                self?.fileImportHelper = nil
            }
            guard let self, let fileURL else {
                return
            }

            do {
                let (entries, groups) = try provider(fileURL, currentGroup)

                let alert = UIAlertController(
                    title: fileURL.lastPathComponent,
                    message: String.localizedStringWithFormat(
                        LString.importEntriesCountTemplate,
                        entries.count + groups.map({ $0.entries.count }).reduce(0, +)
                    ),
                    preferredStyle: .alert
                )
                alert.addAction(title: LString.actionDone, style: .default, preferred: true) { [weak self] _ in
                    guard let self else { return }
                    groups.forEach { group in
                        currentGroup.add(group: group)
                    }
                    entries.forEach { entry in
                        currentGroup.add(entry: entry)
                    }
                    saveDatabase(_databaseFile)
                }
                alert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
                _presenterForModals.present(alert, animated: true)
            } catch {
                Diag.error("Import failed [message: \(error.localizedDescription)]")
                _presenterForModals.showErrorAlert(
                    error.localizedDescription,
                    title: LString.titleFileImportError
                )
            }
        }

        self.fileImportHelper = importHelper
        importHelper.importFile(
            contentTypes: [type],
            presenter: _presenterForModals
        )
    }
}
