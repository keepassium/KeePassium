//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension KeyFilePickerCoordinator {
    class ItemDecorator: FilePickerItemDecorator {
        weak var coordinator: KeyFilePickerCoordinator?

        func getLeadingSwipeActions(forFile item: FilePickerItem.FileInfo) -> [UIContextualAction]? {
            return nil
        }

        func getTrailingSwipeActions(forFile item: FilePickerItem.FileInfo) -> [UIContextualAction]? {
            guard let fileRef = item.source else { return nil }
            var actions = [UIContextualAction]()

            let eliminateKeyFileAction = UIContextualAction(
                title: DestructiveFileAction.get(for: fileRef.location).title,
                image: .symbol(.trash),
                color: .destructiveTint,
                handler: { [weak coordinator] action, sourceView, actionPerformed in
                    coordinator?.didPressEliminateKeyFile(fileRef, at: sourceView.asPopoverAnchor)
                    actionPerformed(true)
                }
            )
            actions.append(eliminateKeyFileAction)
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
            at popoverAnchor: PopoverAnchor?
        ) -> UIMenu? {
            guard let fileRef = fileItem.source else { assertionFailure(); return nil }
            var menuItems = [UIMenuElement]()

            let fileInfoAction = UIAction(
                title: LString.FileInfo.menuFileInfo,
                image: .symbol(.infoCircle),
                handler: { [weak coordinator] action in
                    let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor ?? popoverAnchor
                    coordinator?.didPressFileInfo(for: fileRef, at: popoverAnchor)
                }
            )
            menuItems.append(fileInfoAction)

            let eliminateFileAction = UIAction(
                title: DestructiveFileAction.get(for: fileRef.location).title,
                image: .symbol(.trash),
                attributes: .destructive,
                handler: { [weak coordinator] action in
                    let popoverAnchor = action.presentationSourceItem?.asPopoverAnchor ?? popoverAnchor
                    coordinator?.didPressEliminateKeyFile(fileRef, at: popoverAnchor)
                }
            )
            menuItems.append(eliminateFileAction)
            return UIMenu(children: menuItems)
        }
    }
}

extension KeyFilePickerCoordinator {
    private func didPressFileInfo(for fileRef: URLReference, at popoverAnchor: PopoverAnchor?) {
        showFileInfo(fileRef, fileType: .keyFile, allowExport: false, at: popoverAnchor, in: _filePickerVC)
    }

    private func didPressEliminateKeyFile(_ fileRef: URLReference, at popoverAnchor: PopoverAnchor?) {
        eliminateKeyFile(fileRef, at: popoverAnchor, viewController: _filePickerVC)
    }
}

extension KeyFilePickerCoordinator {

    func eliminateKeyFile(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor?,
        viewController: UIViewController
    ) {
        StoreReviewSuggester.registerEvent(.trouble)

        let shouldConfirm = !fileRef.hasError

        FileDestructionHelper.destroyFile(
            fileRef,
            fileType: .keyFile,
            withConfirmation: shouldConfirm,
            at: popoverAnchor,
            parent: viewController,
            completion: { [weak self] isEliminated in
                guard isEliminated, let self else { return }
                didEliminateFile(fileRef, in: self)
            }
        )
    }
}
