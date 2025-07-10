//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension KeyFilePickerCoordinator {
    class ToolbarDecorator: FilePickerToolbarDecorator {
        weak var coordinator: KeyFilePickerCoordinator?

        func getToolbarItems() -> [UIBarButtonItem]? {
            return nil
        }

        func getLeadingItemGroups() -> [UIBarButtonItemGroup]? {
            guard let coordinator else { assertionFailure(); return nil }
            let cancelItem = UIBarButtonItem(
                systemItem: .cancel,
                primaryAction: UIAction { [weak coordinator] action in
                    coordinator?.didPressCancel()
                },
            )
            let itemGroup = UIBarButtonItemGroup(barButtonItems: [cancelItem], representativeItem: nil)
            return [itemGroup]
        }

        func getTrailingItemGroups() -> [UIBarButtonItemGroup]? {
            guard let coordinator else { assertionFailure(); return nil }
            var barItems = [UIBarButtonItem]()
            if ProcessInfo.isRunningOnMac {
                let refreshAction = UIBarButtonItem(
                    systemItem: .refresh,
                    primaryAction: UIAction { [weak coordinator] action in
                        coordinator?.refresh()
                    }
                )
                barItems.append(refreshAction)
            }
            let addKeyFileBarButton = UIBarButtonItem(
                title: LString.actionAddKeyFile,
                image: .symbol(.plus),
                primaryAction: nil,
                menu: coordinator._makeAddKeyFileMenu()
            )
            barItems.append(addKeyFileBarButton)
            return [UIBarButtonItemGroup(barButtonItems: barItems, representativeItem: nil)]
        }
    }

    internal func _makeAddKeyFileMenu() -> UIMenu {
        let createKeyFileAction = UIAction(
            title: LString.actionCreateKeyFile,
            image: .symbol(.plus),
            handler: { [weak self] action in
                let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor
                self?.didPressCreateKeyFile(at: popoverAnchor)
            }
        )
        let importKeyFileAction = UIAction(
            title: LString.actionImportKeyFile,
            subtitle: LString.importKeyFileDescription,
            image: .symbol(.folderBadgePlus),
            handler: { [weak self] action in
                let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor
                self?.didPressImportKeyFile(at: popoverAnchor)
            }
        )
        let useKeyFileAction = UIAction(
            title: LString.actionUseKeyFile,
            subtitle: LString.useKeyFileDescription,
            image: .symbol(.folder),
            handler: { [weak self] action in
                let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor
                self?.didPressUseKeyFile(at: popoverAnchor)
            }
        )
        return UIMenu(children: [
            importKeyFileAction,
            useKeyFileAction,
            UIMenu(inlineChildren: [createKeyFileAction])
        ])
    }
}

extension KeyFilePickerCoordinator {
    private func didPressCancel() {
        dismiss()
    }

    private func didPressImportKeyFile(at popoverAnchor: PopoverAnchor?) {
        startAddingKeyFile(mode: .import, presenter: _filePickerVC)
    }

    private func didPressUseKeyFile(at popoverAnchor: PopoverAnchor?) {
        startAddingKeyFile(mode: .use, presenter: _filePickerVC)
    }

    private func didPressCreateKeyFile(at popoverAnchor: PopoverAnchor?) {
        startCreatingKeyFile(presenter: _filePickerVC)
    }
}
