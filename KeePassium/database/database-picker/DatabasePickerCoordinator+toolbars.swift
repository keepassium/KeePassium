//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension DatabasePickerCoordinator {
    class ToolbarDecorator: FilePickerToolbarDecorator {
        weak var coordinator: DatabasePickerCoordinator?

        func getToolbarItems() -> [UIBarButtonItem]? {
            guard let coordinator else { assertionFailure(); return nil }
            switch coordinator.mode {
            case .autoFill, .light:
                return nil
            case .full:
                break
            }

            let passGenItem = UIBarButtonItem(
                title: LString.PasswordGenerator.titleRandomGenerator,
                image: .symbol(.dieFace3),
                primaryAction: UIAction { [weak coordinator] action in
                    let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor
                    coordinator?.didPressPasswordGenerator(at: popoverAnchor)
                }
            )
            let refreshItem = UIBarButtonItem(
                systemItem: .refresh,
                primaryAction: UIAction { [weak coordinator] action in
                    coordinator?.refresh()
                }
            )
            let appSettingsItem = UIBarButtonItem(
                title: LString.titleSettings,
                image: .symbol(.gearshape),
                primaryAction: UIAction { [weak coordinator] action in
                    let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor
                    coordinator?.didPressAppSettings(at: popoverAnchor)
                }
            )

            return [
                passGenItem,
                UIBarButtonItem.flexibleSpace(),
                refreshItem,
                UIBarButtonItem.flexibleSpace(),
                appSettingsItem
            ]
        }

        func getLeadingItemGroups() -> [UIBarButtonItemGroup]? {
            guard let coordinator else { assertionFailure(); return nil }
            switch coordinator.mode {
            case .full:
                return nil
            case .autoFill, .light:
                let diagnosticAction = UIAction(title: LString.titleDiagnosticLog) { [weak coordinator] _ in
                    coordinator?.didPressShowDiagnostics()
                }
                let cancelItem = UIBarButtonItem(
                    systemItem: .cancel,
                    primaryAction: UIAction { [weak coordinator] action in
                        coordinator?.didPressCancel()
                    },
                    menu: UIMenu(children: [diagnosticAction])
                )
                let itemGroup = UIBarButtonItemGroup(barButtonItems: [cancelItem], representativeItem: nil)
                return [itemGroup]
            }
        }

        func getTrailingItemGroups() -> [UIBarButtonItemGroup]? {
            guard let coordinator else { assertionFailure(); return nil }
            let needPremium = coordinator.needsPremiumToAddDatabase()
            var menuItems = [UIMenuElement]()

            #if MAIN_APP
            switch coordinator.mode {
            case .full, .light:
                let createDatabaseAction = UIAction(
                    title: LString.titleNewDatabase,
                    image: needPremium ? .premiumBadge : .symbol(.plus),
                    handler: { [weak coordinator] action in
                        let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor
                        coordinator?.didPressCreateDatabase(at: popoverAnchor)
                    }
                )
                menuItems.append(createDatabaseAction)
            case .autoFill:
                assertionFailure("Tried to use .autoFill mode in main app")
            }
            #endif

            let appConfig = ManagedAppConfig.shared
            let addExternalDatabaseAction = UIAction(
                title: LString.actionOpenDatabase,
                image: needPremium ? .premiumBadge : .symbol(.folder),
                attributes: appConfig.areSystemFileProvidersAllowed ? [] : [.disabled],
                handler: { [weak coordinator] action in
                    let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor
                    coordinator?.didPressAddExternalDatabase(at: popoverAnchor)
                }
            )
            menuItems.append(addExternalDatabaseAction)

            let addRemoteDatabaseAction = UIAction(
                title: LString.actionConnectToServer,
                image: needPremium ? UIImage.premiumBadge : UIImage.symbol(.network),
                attributes: appConfig.areInAppFileProvidersAllowed ? [] : [.disabled],
                handler: { [weak coordinator] action in
                    let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor
                    coordinator?.didPressAddRemoteDatabase(at: popoverAnchor)
                }
            )
            menuItems.append(UIMenu(inlineChildren: [addRemoteDatabaseAction]))

            let showBackupAction = UIAction(
                title: LString.titleShowBackupFiles,
                attributes: [],
                state: Settings.current.isBackupFilesVisible ? .on : .off,
                handler: { [weak coordinator] action in
                    let areShown = (action.state == .on)
                    coordinator?.didToggleShowBackupFiles(shouldShow: !areShown)
                }
            )
            menuItems.append(showBackupAction)

            let currentSortOrder = Settings.current.filesSortOrder
            let sortMenuItems = UIMenu.makeFileSortMenuItems(
                current: currentSortOrder,
                handler: { [weak coordinator] newSortOrder in
                    coordinator?.didChangeSortOrder(to: newSortOrder)
                }
            )
            let sortOptionsMenu = UIMenu.make(
                title: LString.titleSortOrder,
                subtitle: currentSortOrder.title,
                children: sortMenuItems
            )
            menuItems.append(sortOptionsMenu)

            let listActionsMenu = UIMenu.make(children: menuItems)
            let listActionsItem = UIBarButtonItem(
                title: LString.titleMoreActions,
                image: .symbol(.ellipsisCircle),
                menu: listActionsMenu)
            let itemGroup = UIBarButtonItemGroup(barButtonItems: [listActionsItem], representativeItem: nil)
            return [itemGroup]
        }
    }
}

extension DatabasePickerCoordinator {
    private func didPressCancel() {
        dismiss()
    }

    private func didPressPasswordGenerator(at popoverAnchor: PopoverAnchor?) {
        delegate?.didPressShowRandomGenerator(at: popoverAnchor, in: _filePickerVC)
    }

    private func didPressAppSettings(at popoverAnchor: PopoverAnchor?) {
        delegate?.didPressShowAppSettings(at: popoverAnchor, in: _filePickerVC)
    }

    private func didPressShowDiagnostics() {
        delegate?.didPressShowDiagnostics(at: nil, in: _filePickerVC)
    }

    private func didToggleShowBackupFiles(shouldShow: Bool) {
        Settings.current.isBackupFilesVisible = shouldShow
        refresh()
        _filePickerVC.showNotificationIfManaged(setting: .backupFilesVisible)
    }

    private func didChangeSortOrder(to sortOrder: Settings.FilesSortOrder) {
        Settings.current.filesSortOrder = sortOrder
        refresh()
    }

    #if MAIN_APP
    private func didPressCreateDatabase(at popoverAnchor: PopoverAnchor?) {
        paywalledStartDatabaseCreator(presenter: _filePickerVC)
    }
    #endif

    private func didPressAddExternalDatabase(at popoverAnchor: PopoverAnchor?) {
        paywalledStartExternalDatabasePicker(presenter: _filePickerVC)
    }

    private func didPressAddRemoteDatabase(at popoverAnchor: PopoverAnchor?) {
        paywalledStartRemoteDatabasePicker(bypassPaywall: false, presenter: _filePickerVC)
    }
}
