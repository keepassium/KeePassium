//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol ItemIconPickerCoordinatorDelegate: class {
    func didSelectIcon(standardIcon: IconID, in coordinator: ItemIconPickerCoordinator)
    func didSelectIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator)
    func didDeleteIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator)
}

class ItemIconPickerCoordinator: Coordinator, DatabaseSaving {
    
    public static let customIconMaxSide = CGFloat(128)

    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    
    weak var delegate: ItemIconPickerCoordinatorDelegate?
    weak var item: DatabaseItem?
    
    private let router: NavigationRouter
    private weak var database: Database?
    private let iconPicker: ItemIconPicker
    private var photoPicker: PhotoPicker?
    var databaseExporterTemporaryURL: TemporaryFileURL?
    
    init(router: NavigationRouter, database: Database) {
        self.router = router
        self.database = database
        iconPicker = ItemIconPicker.instantiateFromStoryboard()
        iconPicker.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        guard let database = database else {
            assertionFailure()
            return
        }
        
        iconPicker.isImportAllowed = database is Database2
        refresh()
        iconPicker.selectIcon(for: item)
        
        router.push(iconPicker, animated: true, onPop: {
            [weak self] (viewController) in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
    
    private func refresh() {
        guard let db2 = database as? Database2 else {
            return
        }
        iconPicker.customIcons = db2.customIcons
        iconPicker.refresh()
    }
    
    
    private func addCustomIcon(_ image: UIImage) {
        guard let db2 = database as? Database2 else {
            assertionFailure()
            return
        }
        guard let pngData = image.pngData() else {
            Diag.warning("New custom icon has no data, ignoring")
            return
        }
        db2.addCustomIcon(pngData: ByteArray(data: pngData))
        refresh()
        saveDatabase()
    }
    
    private func deleteCustomIcon(uuid: UUID) {
        guard let db2 = database as? Database2 else {
            assertionFailure()
            return
        }
        db2.deleteCustomIcon(uuid: uuid)
        saveDatabase()
        delegate?.didDeleteIcon(customIcon: uuid, in: self)
        refresh() 
    }
    
    private func saveDatabase() {
        let dbm = DatabaseManager.shared
        dbm.addObserver(self)
        dbm.startSavingDatabase()
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
            case .success(let image):
                let maxSide = ItemIconPickerCoordinator.customIconMaxSide
                if let iconImage = image?.downscalingToSquare(maxSide: maxSide) {
                    self.addCustomIcon(iconImage)
                }
            case .failure(let error):
                viewController.showErrorAlert(error, title: LString.titleError)
            }
        }
    }
}

extension ItemIconPickerCoordinator: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        router.showProgressView(title: LString.databaseStatusSaving, allowCancelling: true)
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        router.updateProgressView(with: progress)
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        Diag.info("Database saving cancelled")
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
    }
    
    func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
    }
    
    func databaseManager(database urlRef: URLReference, savingError error: Error, data: ByteArray?) {
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
        showDatabaseSavingError(
            error,
            fileName: urlRef.visibleFileName,
            diagnosticsHandler: nil,
            exportableData: data,
            parent: iconPicker
        )
    }
}
