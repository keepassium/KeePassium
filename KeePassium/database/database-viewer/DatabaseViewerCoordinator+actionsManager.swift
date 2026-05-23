//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension DatabaseViewerCoordinator {
    final class ActionsManager: UIResponder {
        private weak var coordinator: DatabaseViewerCoordinator?

        init(coordinator: DatabaseViewerCoordinator? = nil) {
            self.coordinator = coordinator
        }

        override func buildMenu(with builder: any UIMenuBuilder) {
            builder.insertChild(makeReloadDatabaseMenu(), atEndOfMenu: .databaseFile)
            builder.insertChild(makeDatabaseToolsMenu2(), atEndOfMenu: .databaseFile)
            builder.insertChild(makeLockDatabaseMenu(), atEndOfMenu: .databaseFile)
            builder.insertChild(makeExportDatabaseMenu(), atEndOfMenu: .databaseFile)
            builder.insertChild(makeImportDatabaseMenu(), atEndOfMenu: .databaseFile)
            builder.insertSibling(makeDatabaseToolsMenu1(), afterMenu: .passwordGenerator)
            if coordinator != nil {
                builder.insertChild(makeDatabaseItemsSortOrderMenu(), atEndOfMenu: .view)
                builder.insertSibling(makeEntrySubtitleMenu(), afterMenu: .itemsSortOrder)
            }
            builder.insertChild(makeCreateMenu(), atEndOfMenu: .edit)
            builder.insertChild(makeEditGroupMenu(), atEndOfMenu: .edit)
            builder.insertChild(makeCopyEntryFieldMenu(), atEndOfMenu: .edit)
            builder.insertChild(makeSelectMenu(), atEndOfMenu: .edit)
        }

        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            guard let coordinator else {
                return false
            }

            let permissions = coordinator._currentGroupPermissions
            switch action {
            case #selector(kpmReloadDatabase),
                #selector(kpmLockDatabase),
                #selector(kpmExportDatabaseToCSV),
                #selector(kmpImportDatabaseFromApplePasswordsCSV),
                #selector(kmpImportDatabaseFromBitwardenJSON),
                #selector(kmpImportDatabaseFromEnpassJSON),
                #selector(kmpImportDatabaseFromOnePassword1PUX):
                return true
            case #selector(kpmShowPasswordAudit):
                return permissions.contains(.auditPasswords)
            case #selector(kpmDownloadFavicons):
                return permissions.contains(.downloadFavicons)
            case #selector(kpmPrintDatabase):
                return permissions.contains(.printDatabase)
            case #selector(kpmChangeMasterKey):
                return permissions.contains(.changeMasterKey)
            case #selector(kpmShowEncryptionSettings):
                return permissions.contains(.changeEncryptionSettings)
            case #selector(kpmCreateEntry):
                return permissions.contains(.createEntry)
            case #selector(kpmCreateGroup):
                return permissions.contains(.createGroup)
            case #selector(kpmCreateSmartGroup):
                return permissions.contains(.createGroup)
            case #selector(kpmEditGroup):
                return permissions.contains(.editItem)
            case #selector(kpmSelect):
                return permissions.contains(.selectItems)
            case #selector(UIResponderStandardEditActions.selectAll(_:)):
                return permissions.contains(.selectItems) && !isTextInputFirstResponder()
            case #selector(kpmCopyEntryUserName):
                return coordinator._canCopyCurrentEntryField(EntryField.userName)
            case #selector(kpmCopyEntryPassword):
                if isFirstResponderReadyToCopy() {
                    return false
                }
                return coordinator._canCopyCurrentEntryField(EntryField.password)
            case #selector(kpmCopyEntryTOTP):
                return coordinator._canCopyCurrentEntryField(EntryField.totp)
            case #selector(kpmCopyEntryURL):
                return coordinator._canCopyCurrentEntryField(EntryField.url)
            case #selector(kpmOpenEntryURL):
                return coordinator._canOpenCurrentEntryURL()
            #if targetEnvironment(macCatalyst)
            case #selector(kpmPerformAutoType):
                return coordinator._canPerformAutoType()
            #endif
            default:
                return false
            }
        }

        override func selectAll(_ sender: Any?) {
            coordinator?._topGroupViewer?.selectAll(sender)
        }

        private func isTextInputFirstResponder() -> Bool {
            let keyWindow = UIApplication.shared.firstKeyWindow
            guard let firstResponder = keyWindow?.findFirstResponder() else {
                return false
            }
            return firstResponder is UITextField ||
                firstResponder is UITextView ||
                firstResponder is UISearchBar
        }

        private func isFirstResponderReadyToCopy() -> Bool {
            let keyWindow = UIApplication.shared.firstKeyWindow
            guard let firstResponder = keyWindow?.findFirstResponder() else {
                return false
            }

            let responderToCheck: UIResponder?
            if firstResponder is UITextView || firstResponder is UITextField {
                responderToCheck = firstResponder
            } else if let searchBar = firstResponder as? UISearchBar {
                responderToCheck = searchBar.searchTextField
            } else {
                return false
            }

            guard let actualInputView = responderToCheck else {
                return false
            }

            let canPerform = actualInputView.canPerformAction(
                #selector(UIResponderStandardEditActions.copy(_:)),
                withSender: nil)
            return canPerform
        }

        private func makeLockDatabaseMenu() -> UIMenu {
            let lockDatabaseCommand = UIKeyCommand(
                title: LString.actionLockDatabase,
                action: #selector(kpmLockDatabase),
                hotkey: .lockDatabase
            )
            return UIMenu(identifier: .lockDatabase, options: [.displayInline], children: [lockDatabaseCommand])
        }

        private func makeExportDatabaseMenu() -> UIMenu {
            let exportDatabaseCSVCommand = UICommand(
                title: "CSV",
                action: #selector(kpmExportDatabaseToCSV)
            )
            return UIMenu(
                title: LString.actionExport,
                identifier: .exportDatabase,
                children: [exportDatabaseCSVCommand])
        }

        private func makeImportDatabaseMenu() -> UIMenu {
            let importApplePasswordsCSVCommand = UICommand(
                title: LString.titleApplePasswordsCSV,
                action: #selector(kmpImportDatabaseFromApplePasswordsCSV)
            )
            let importBitwardenJSONCommand = UICommand(
                title: LString.titleBitwardenJSON,
                action: #selector(kmpImportDatabaseFromBitwardenJSON)
            )
            let importEnpassJSONCommand = UICommand(
                title: LString.titleEnpassJSON,
                action: #selector(kmpImportDatabaseFromEnpassJSON)
            )
            let importOnePassword1PUXCommand = UICommand(
                title: LString.titleOnePassword1PUX,
                action: #selector(kmpImportDatabaseFromOnePassword1PUX)
            )
            return UIMenu(
                title: LString.actionImport,
                identifier: .importDatabase,
                children: [
                    importOnePassword1PUXCommand,
                    importApplePasswordsCSVCommand,
                    importBitwardenJSONCommand,
                    importEnpassJSONCommand
                ]
            )
        }

        private func makeReloadDatabaseMenu() -> UIMenu {
            let reloadDatabaseCommand = UIKeyCommand(
                title: LString.actionReloadDatabase,
                action: #selector(kpmReloadDatabase),
                hotkey: .reloadDatabase
            )
            return UIMenu(identifier: .reloadDatabase, options: [.displayInline], children: [reloadDatabaseCommand])
        }

        private func makeDatabaseItemsSortOrderMenu() -> UIMenu {
            let canReorder = coordinator?._currentGroupPermissions.contains(.reorderItems) ?? false
            let reorderItemsAction = UIAction(
                title: LString.actionReorderItems,
                image: .symbol(.arrowUpArrowDown),
                attributes: canReorder ? [] : [.disabled],
                handler: { [weak self] _ in
                    self?.coordinator?._startReordering()
                }
            )
            let children = UIMenu.makeDatabaseItemSortMenuItems(
                current: Settings.current.groupSortOrder,
                reorderAction: reorderItemsAction,
                handler: { [weak self] newSortOrder in
                    Settings.current.groupSortOrder = newSortOrder
                    self?.coordinator?.refresh()
                }
            )
            return UIMenu(
                title: LString.titleSortItemsBy,
                identifier: .itemsSortOrder,
                options: .singleSelection,
                children: children)
        }

        private func makeEntrySubtitleMenu() -> UIMenu {
            let children = Settings.EntryListDetail.allValues.map { entryListDetail in
                let isCurrent = Settings.current.entryListDetail == entryListDetail
                return UIAction(
                    title: entryListDetail.title,
                    state: isCurrent ? .on : .off,
                    handler: { [weak self] _ in
                        Settings.current.entryListDetail = entryListDetail
                        self?.coordinator?.refresh()
                        UIMenu.rebuildMainMenu()
                    }
                )
            }
            return UIMenu(
                title: LString.titleEntrySubtitle,
                options: .singleSelection,
                children: children
            )
        }

        private func makeDatabaseToolsMenu1() -> UIMenu {
            let passwordAuditAction = UIKeyCommand(
                title: LString.titlePasswordAudit,
                action: #selector(kpmShowPasswordAudit),
                hotkey: .passwordAudit)
            let downloadFaviconsAction = UICommand(
                title: LString.actionDownloadFavicons,
                action: #selector(kpmDownloadFavicons))
            return UIMenu(inlineChildren: [
                passwordAuditAction,
                downloadFaviconsAction,
            ])
        }

        private func makeDatabaseToolsMenu2() -> UIMenu {
            let changeMasterKeyAction = UICommand(
                title: LString.actionChangeMasterKey,
                action: #selector(kpmChangeMasterKey))
            let encryptionSettingsAction = UIKeyCommand(
                title: LString.titleEncryptionSettings,
                action: #selector(kpmShowEncryptionSettings),
                hotkey: .encryptionSettings)
            let printAction = UIKeyCommand(
                title: LString.actionPrint,
                action: #selector(kpmPrintDatabase),
                hotkey: .printDatabase)
            return UIMenu(inlineChildren: [
                changeMasterKeyAction,
                encryptionSettingsAction,
                printAction
            ])
        }

        private func makeCreateMenu() -> UIMenu {
            let createEntryMenuItem = UIKeyCommand(
                title: LString.titleNewEntry,
                action: #selector(kpmCreateEntry),
                hotkey: .createEntry)
            let createGroupMenuItem = UIKeyCommand(
                title: LString.titleNewGroup,
                action: #selector(kpmCreateGroup),
                hotkey: .createGroup)
            let createSmartGroupMenuItem = UICommand(
                title: LString.titleNewSmartGroup,
                action: #selector(kpmCreateSmartGroup))
            return UIMenu(inlineChildren: [
                createEntryMenuItem,
                createGroupMenuItem, createSmartGroupMenuItem
            ])
        }

        private func makeEditGroupMenu() -> UIMenu {
            let editGroupMenuItem = UICommand(
                title: LString.titleEditGroup,
                action: #selector(kpmEditGroup))
            return UIMenu(inlineChildren: [editGroupMenuItem])
        }

        private func makeCopyEntryFieldMenu() -> UIMenu {
            let copyUserNameAction = UIKeyCommand(
                title: String.localizedStringWithFormat(
                    LString.actionCopyToClipboardTemplate,
                    LString.fieldUserName),
                action: #selector(kpmCopyEntryUserName),
                hotkey: .copyUserName)
            let copyPasswordAction = UIKeyCommand(
                title: String.localizedStringWithFormat(
                    LString.actionCopyToClipboardTemplate,
                    LString.fieldPassword),
                action: #selector(kpmCopyEntryPassword),
                hotkey: .copyPassword)
            let copyTOTPAction = UIKeyCommand(
                title: String.localizedStringWithFormat(
                    LString.actionCopyToClipboardTemplate,
                    LString.fieldOTP),
                action: #selector(kpmCopyEntryTOTP),
                hotkey: .copyTOTP)
            let copyURLAction = UIKeyCommand(
                title: String.localizedStringWithFormat(
                    LString.actionCopyToClipboardTemplate,
                    LString.fieldURL),
                action: #selector(kpmCopyEntryURL),
                hotkey: .copyURL)
            let openURLAction = UIKeyCommand(
                title: LString.actionOpenURL,
                action: #selector(kpmOpenEntryURL),
                hotkey: .openURL)

            assert(Hotkey.copyPassword == Hotkey.systemCopyToClipboard)

            return UIMenu(inlineChildren: [
                copyUserNameAction,
                copyPasswordAction,
                copyTOTPAction,
                copyURLAction,
                openURLAction
            ])
        }

        private func makeSelectMenu() -> UIMenu {
            let selectAction = UICommand(
                title: LString.actionSelect,
                action: #selector(kpmSelect))
            let selectAllAction = UIKeyCommand(
                title: LString.actionSelectAll,
                action: #selector(UIResponderStandardEditActions.selectAll(_:)),
                hotkey: .selectAll)
            return UIMenu(inlineChildren: [selectAction, selectAllAction])
        }

        @objc func kpmReloadDatabase() {
            coordinator?._reloadDatabase()
        }
        @objc func kpmLockDatabase() {
            coordinator?.closeDatabase(shouldLock: true, reason: .userRequest, animated: true, completion: nil)
        }
        @objc func kpmExportDatabaseToCSV() {
            coordinator?._confirmAndExportDatabaseToCSV()
        }
        @objc func kmpImportDatabaseFromApplePasswordsCSV() {
            coordinator?._importDatabaseFromApplePasswordsCSV()
        }
        @objc func kmpImportDatabaseFromBitwardenJSON() {
            coordinator?._importDatabaseFromBitwardenJSON()
        }
        @objc func kmpImportDatabaseFromEnpassJSON() {
            coordinator?._importDatabaseFromEnpassJSON()
        }
        @objc func kmpImportDatabaseFromOnePassword1PUX() {
            coordinator?._importDatabaseFromOnePassword1PUX()
        }
        @objc func kpmShowPasswordAudit() {
            coordinator?._showPasswordAudit()
        }
        @objc func kpmDownloadFavicons() {
            coordinator?._downloadFavicons()
        }
        @objc func kpmPrintDatabase() {
            coordinator?._showDatabasePrintDialog()
        }
        @objc func kpmChangeMasterKey() {
            coordinator?._showMasterKeyChanger()
        }
        @objc func kpmShowEncryptionSettings() {
            coordinator?._showEncryptionSettings()
        }
        @objc func kpmCreateEntry() {
            coordinator?._showEntryCreator()
        }
        @objc func kpmCreateSmartGroup() {
            coordinator?._showGroupEditor(.create(smart: true))
        }
        @objc func kpmCreateGroup() {
            coordinator?._showGroupEditor(.create(smart: false))
        }
        @objc func kpmEditGroup() {
            guard let currentGroup = coordinator?._currentGroup else {
                return
            }
            coordinator?._showGroupEditor(.modify(group: currentGroup))
        }
        @objc func kpmSelect() {
            coordinator?._startSelecting()
        }
        @objc func kpmCopyEntryUserName() {
            coordinator?._copyCurrentEntryField(EntryField.userName)
        }
        @objc func kpmCopyEntryPassword() {
            coordinator?._copyCurrentEntryField(EntryField.password)
        }
        @objc func kpmCopyEntryTOTP() {
            coordinator?._copyCurrentEntryField(EntryField.totp)
        }
        @objc func kpmCopyEntryURL() {
            coordinator?._copyCurrentEntryField(EntryField.url)
        }
        @objc func kpmOpenEntryURL() {
            coordinator?._openCurrentEntryURL()
        }
        #if targetEnvironment(macCatalyst)
        @objc func kpmPerformAutoType() {
            coordinator?._performAutoType()
        }
        #endif
    }
}
