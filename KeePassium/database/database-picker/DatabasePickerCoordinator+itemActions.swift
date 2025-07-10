//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension DatabasePickerCoordinator {
    class ItemDecorator: FilePickerItemDecorator {
        weak var coordinator: DatabasePickerCoordinator?

        func getLeadingSwipeActions(forFile item: FilePickerItem.FileInfo) -> [UIContextualAction]? {
            return nil
        }

        func getTrailingSwipeActions(forFile item: FilePickerItem.FileInfo) -> [UIContextualAction]? {
            guard let fileRef = item.source else { return nil }
            var actions = [UIContextualAction]()

            let eliminateDatabaseAction = UIContextualAction(
                title: DestructiveFileAction.get(for: fileRef.location).title,
                image: .symbol(.trash),
                color: .destructiveTint,
                handler: { [weak coordinator] action, sourceView, actionPerformed in
                    coordinator?.didPressEliminateDatabase(fileRef, at: sourceView.asPopoverAnchor)
                    actionPerformed(true)
                }
            )
            actions.append(eliminateDatabaseAction)

            if ProcessInfo.isRunningOnMac {
                let revealInFinderAction = UIContextualAction(
                    title: LString.actionRevealInFinder,
                    image: .symbol(.folder),
                    color: .actionTint,
                    handler: { [weak coordinator] action, sourceView, actionPerformed in
                        coordinator?.didPressRevealInFinder(fileRef, at: sourceView.asPopoverAnchor)
                        actionPerformed(true)
                    }
                )
                actions.append(revealInFinderAction)
            } else {
                let exportDatabaseAction = UIContextualAction(
                    title: LString.actionExport,
                    image: .symbol(.squareAndArrowUp),
                    color: .actionTint,
                    handler: { [weak coordinator] action, sourceView, actionPerformed in
                        coordinator?.didPressExportDatabase(fileRef, at: sourceView.asPopoverAnchor)
                        actionPerformed(true)
                    }
                )
                actions.append(exportDatabaseAction)
            }
            return actions
        }

        func getAccessories(for fileItem: FilePickerItem.FileInfo) -> [UICellAccessory]? {
            let fileMenuAccessory = UICellAccessory.customView(configuration: .init(
                customView: makeFileMenuButton(for: fileItem),
                placement: .trailing(displayed: .always),
                tintColor: .actionTint,
                maintainsFixedSize: false)
            )
            return [fileMenuAccessory]
        }

        func getContextMenu(for item: FilePickerItem.FileInfo, at popoverAnchor: PopoverAnchor) -> UIMenu? {
            return makeFileMenu(for: item, at: popoverAnchor)
        }

        private func makeFileMenuButton(for fileItem: FilePickerItem.FileInfo) -> UIButton {
            var buttonConfig = UIButton.Configuration.borderless()
            buttonConfig.image = .symbol(.ellipsis)
            let fileMenuButton = UIButton(configuration: buttonConfig)
            fileMenuButton.accessibilityLabel = LString.actionShowDetails
            fileMenuButton.menu = makeFileMenu(for: fileItem, at: fileMenuButton.asPopoverAnchor)
            fileMenuButton.showsMenuAsPrimaryAction = true
            fileMenuButton.sizeToFit()
            return fileMenuButton
        }

        private func makeFileMenu(
            for fileItem: FilePickerItem.FileInfo,
            at popoverAnchor: PopoverAnchor
        ) -> UIMenu? {
            guard let fileRef = fileItem.source else { assertionFailure(); return nil }
            var menuItems = [UIMenuElement]()
            let dbSettingsAction = UIAction(
                title: LString.titleDatabaseSettings,
                image: .symbol(.gearshape2),
                handler: { [weak coordinator] action in
                    let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor ?? popoverAnchor
                    coordinator?.didPressDatabaseSettings(for: fileRef, at: popoverAnchor)
                }
            )
            menuItems.append(UIMenu(inlineChildren: [dbSettingsAction]))

            let fileInfoAction = UIAction(
                title: LString.FileInfo.menuFileInfo,
                image: .symbol(.infoCircle),
                handler: { [weak coordinator] action in
                    let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor ?? popoverAnchor
                    coordinator?.didPressFileInfo(for: fileRef, at: popoverAnchor)
                }
            )
            menuItems.append(fileInfoAction)

            if ProcessInfo.isRunningOnMac {
                let revealInFinderAction = UIAction(
                    title: LString.actionRevealInFinder,
                    image: .symbol(.folder),
                    handler: { [weak coordinator] action in
                        let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor ?? popoverAnchor
                        coordinator?.didPressRevealInFinder(fileRef, at: popoverAnchor)
                    }
                )
                menuItems.append(revealInFinderAction)
            } else {
                let exportFileAction = UIAction(
                    title: LString.actionExport,
                    image: .symbol(.squareAndArrowUp),
                    handler: { [weak coordinator] action in
                        let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor ?? popoverAnchor
                        coordinator?.didPressExportDatabase(fileRef, at: popoverAnchor)
                    }
                )
                menuItems.append(exportFileAction)
            }

            let eliminateFileAction = UIAction(
                title: DestructiveFileAction.get(for: fileRef.location).title,
                image: .symbol(.trash),
                attributes: .destructive,
                handler: { [weak coordinator] action in
                    let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor ?? popoverAnchor
                    coordinator?.didPressEliminateDatabase(fileRef, at: popoverAnchor)
                }
            )
            menuItems.append(eliminateFileAction)
            return UIMenu(children: menuItems)
        }
    }
}

extension DatabasePickerCoordinator {
    private func didPressDatabaseSettings(for fileRef: URLReference, at popoverAnchor: PopoverAnchor?) {
        showDatabaseSettings(fileRef, at: popoverAnchor, in: _filePickerVC)
    }

    private func didPressFileInfo(for fileRef: URLReference, at popoverAnchor: PopoverAnchor?) {
        showFileInfo(fileRef, fileType: .database, allowExport: true, at: popoverAnchor, in: _filePickerVC)
    }

    private func didPressRevealInFinder(_ fileRef: URLReference, at popoverAnchor: PopoverAnchor?) {
        revealInFinder(fileRef)
    }

    private func didPressExportDatabase(_ fileRef: URLReference, at popoverAnchor: PopoverAnchor?) {
        guard let popoverAnchor else {
            Diag.error("Popover anchor is nil, cancelling")
            assertionFailure()
            return
        }
        exportDatabase(fileRef, at: popoverAnchor, in: _filePickerVC)
    }

    private func didPressEliminateDatabase(_ fileRef: URLReference, at popoverAnchor: PopoverAnchor?) {
        eliminateDatabase(fileRef, at: popoverAnchor, viewController: _filePickerVC)
    }
}

extension DatabasePickerCoordinator {
    func revealInFinder(
        _ fileRef: URLReference
    ) {
        assert(ProcessInfo.isRunningOnMac)
        FileExportHelper.revealInFinder(fileRef)
    }

    func exportDatabase(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        FileExportHelper.showFileExportSheet(fileRef, at: popoverAnchor, parent: viewController)
    }

    func eliminateDatabase(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor?,
        viewController: UIViewController
    ) {
        StoreReviewSuggester.registerEvent(.trouble)

        let shouldConfirm = !fileRef.hasError

        FileDestructionHelper.destroyFile(
            fileRef,
            fileType: .database,
            withConfirmation: shouldConfirm,
            at: popoverAnchor,
            parent: viewController,
            completion: { [weak self] isEliminated in
                guard let self else { return }
                if fileRef == _selectedDatabase {
                    selectDatabase(nil, animated: false)
                    delegate?.didSelectDatabase(nil, cause: nil, in: self)
                }
                refresh()
            }
        )
    }
}
