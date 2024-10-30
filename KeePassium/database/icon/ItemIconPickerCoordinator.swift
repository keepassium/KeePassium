//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol ItemIconPickerCoordinatorDelegate: AnyObject {
    func didSelectIcon(standardIcon: IconID, in coordinator: ItemIconPickerCoordinator)
    func didSelectIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator)
    func didDeleteIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator)

    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL)
}

class ItemIconPickerCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    weak var delegate: ItemIconPickerCoordinatorDelegate?
    weak var item: DatabaseItem?

    private let router: NavigationRouter
    private let databaseFile: DatabaseFile
    private let database: Database
    private let iconPicker: ItemIconPicker
    private var photoPicker: PhotoPicker?
    private let customFaviconUrl: URL?

    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return router }
    var saveSuccessHandler: (() -> Void)?

    let faviconDownloader: FaviconDownloader

    init(router: NavigationRouter, databaseFile: DatabaseFile, customFaviconUrl: URL?) {
        self.router = router
        self.databaseFile = databaseFile
        self.database = databaseFile.database
        self.faviconDownloader = FaviconDownloader()
        self.customFaviconUrl = customFaviconUrl
        iconPicker = ItemIconPicker.instantiateFromStoryboard()
        iconPicker.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        refresh()
        iconPicker.selectIcon(for: item)

        router.push(iconPicker, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }

    private func refresh() {
        let supportsCustomIcons = database is Database2
        let unusedCustomIcons = findUnusedCustomIcons()
        iconPicker.isImportAllowed = supportsCustomIcons
        iconPicker.isDownloadAllowed = supportsCustomIcons
            && customFaviconUrl != nil
            && ManagedAppConfig.shared.isFaviconDownloadAllowed
        iconPicker.isDeleteUnusedAllowed = supportsCustomIcons
            && unusedCustomIcons.count > 0

        if let db2 = database as? Database2 {
            iconPicker.customIcons = db2.customIcons
        }
        iconPicker.refresh()
    }


    private func addCustomIcon(_ image: UIImage) {
        guard let db2 = database as? Database2 else {
            assertionFailure()
            return
        }

        guard let newIcon = db2.addCustomIcon(image) else {
            Diag.warning("New custom icon has no data, ignoring")
            return
        }
        refresh() 

        saveDatabase(databaseFile, onSuccess: { [weak self] in
            guard let self else { return }
            self.delegate?.didSelectIcon(customIcon: newIcon.uuid, in: self)
            self.router.pop(animated: true)
        })
    }

    private func deleteCustomIcon(uuid: UUID) {
        guard let db2 = database as? Database2 else {
            assertionFailure()
            return
        }
        db2.deleteCustomIcon(uuid: uuid)
        saveDatabase(databaseFile)
        delegate?.didDeleteIcon(customIcon: uuid, in: self)
        refresh() 
    }

    private func findUnusedCustomIcons() -> Set<UUID> {
        guard let db2 = database as? Database2 else {
            return []
        }

        var usedUUIDs = Set<UUID>()
        db2.root?.applyToAllChildren(
            groupHandler: {
                if let group2 = $0 as? Group2 {
                    usedUUIDs.insert(group2.customIconUUID)
                }
            },
            entryHandler: {
                if let entry2 = $0 as? Entry2 {
                    usedUUIDs.insert(entry2.customIconUUID)
                }
            }
        )

        if let iconUUID = (item as? Entry2)?.customIconUUID ?? (item as? Group2)?.customIconUUID {
            usedUUIDs.insert(iconUUID)
        }

        let existingUUIDs = db2.customIcons.map { $0.uuid }
        let unusedUUIDs = Set(existingUUIDs).subtracting(usedUUIDs)
        return unusedUUIDs
    }

    private func confirmDeleteUnusedCustomIcons(in viewController: UIViewController) {
        let unusedCustomIcons = findUnusedCustomIcons()
        guard unusedCustomIcons.count > 0 else {
            assertionFailure("Should have been blocked in UI")
            return
        }
        let confirmationAlert = UIAlertController.make(
            title: LString.itemIconPickerCustomIcons,
            message: String.localizedStringWithFormat(
                LString.titleUnusedIconsCountTemplate,
                unusedCustomIcons.count),
            dismissButtonTitle: LString.actionCancel
        )
        confirmationAlert.addAction(title: LString.actionDelete, style: .destructive) {
            [weak self, weak viewController] _ in
            guard let self, let viewController else { return }
            deleteUnusedCustomIcons(unusedCustomIcons, in: viewController)
        }
        viewController.present(confirmationAlert, animated: true)
    }

    private func deleteUnusedCustomIcons(_ unusedIconUUIDs: Set<UUID>, in viewController: UIViewController) {
        guard let db2 = database as? Database2 else {
            assertionFailure()
            return
        }

        unusedIconUUIDs.forEach {
            db2.deleteCustomIcon(uuid: $0)
        }
        refresh()
        saveDatabase(databaseFile)
    }
}

extension ItemIconPickerCoordinator: ItemIconPickerDelegate {
    func didPressCancel(in viewController: ItemIconPicker) {
        router.pop(animated: true)
    }

    func didSelect(standardIcon iconID: IconID, in viewController: ItemIconPicker) {
        delegate?.didSelectIcon(standardIcon: iconID, in: self)
        router.pop(animated: true)
    }

    func didSelect(customIcon uuid: UUID, in viewController: ItemIconPicker) {
        delegate?.didSelectIcon(customIcon: uuid, in: self)
        router.pop(animated: true)
    }

    func didDelete(customIcon uuid: UUID, in viewController: ItemIconPicker) {
        deleteCustomIcon(uuid: uuid)
    }

    func didPressImportIcon(in viewController: ItemIconPicker, at popoverAnchor: PopoverAnchor) {
        if photoPicker == nil {
            photoPicker = PhotoPickerFactory.makePhotoPicker()
        }
        photoPicker?.pickImage(from: iconPicker) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let pickerImage):
                if let iconImage = pickerImage?.image {
                    addCustomIcon(iconImage)
                }
            case .failure(let error):
                viewController.showErrorAlert(error, title: LString.titleError)
            }
        }
    }

    func didPressDownloadIcon(in viewController: ItemIconPicker, at popoverAnchor: PopoverAnchor) {
        guard let url = customFaviconUrl else {
            return
        }

        downloadFavicon(for: url, in: viewController) { [weak self] image in
            if let image {
                self?.addCustomIcon(image)
            }
        }
    }

    func didPressDeleteUnusedIcons(in viewController: ItemIconPicker, at popoverAnchor: PopoverAnchor) {
        confirmDeleteUnusedCustomIcons(in: viewController)
    }
}

extension ItemIconPickerCoordinator: DatabaseSaving {
    func didSave(databaseFile: DatabaseFile) {
    }

    func didRelocate(databaseFile: DatabaseFile, to newURL: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: newURL)
    }

    func getDatabaseSavingErrorParent() -> UIViewController {
        return iconPicker
    }
}

extension ItemIconPickerCoordinator: FaviconDownloading {
    var faviconDownloadingProgressHost: ProgressViewHost? { return router }
}
