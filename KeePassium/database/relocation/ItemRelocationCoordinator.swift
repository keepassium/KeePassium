//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

public enum ItemRelocationMode {
    case move
    case copy
}

protocol ItemRelocationCoordinatorDelegate: class {
    func didRelocateItems(in coordinator: ItemRelocationCoordinator)
}

class ItemRelocationCoordinator: Coordinator, DatabaseSaving {
    
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    
    public weak var delegate: ItemRelocationCoordinatorDelegate?
    
    private let router: NavigationRouter
    
    private weak var database: Database?
    private let mode: ItemRelocationMode
    private var itemsToRelocate = [Weak<DatabaseItem>]()
    
    private var groupPicker: DestinationGroupPickerVC
    private weak var destinationGroup: Group?
    
    var databaseExporterTemporaryURL: TemporaryFileURL?
    
    init(router: NavigationRouter, database: Database, mode: ItemRelocationMode, itemsToRelocate: [Weak<DatabaseItem>]) {
        self.router = router
        self.database = database
        self.mode = mode
        self.itemsToRelocate = itemsToRelocate

        let groupPicker = DestinationGroupPickerVC.create(mode: mode)
        self.groupPicker = groupPicker
        groupPicker.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        guard let rootGroup = database?.root else {
            assertionFailure();
            return
        }

        groupPicker.rootGroup = rootGroup
        
        if router.navigationController.topViewController == nil {
            let leftButton = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(didPressDismissButton))
            groupPicker.navigationItem.leftBarButtonItem = leftButton
        }
        router.push(groupPicker, animated: true, onPop: {
            [weak self] (viewController) in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })

        let currentGroup = itemsToRelocate.first?.value?.parent
        groupPicker.expandGroup(currentGroup)
    }
    
    @objc private func didPressDismissButton() {
        router.dismiss(animated: true)
    }
        
    private func isAllowedDestination(_ group: Group) -> Bool {
        guard let database = group.database else {
            assertionFailure()
            return false
        }
        
        if let database1 = group.database as? Database1,
            let root1 = database1.root,
            group === root1
        {
            for item in itemsToRelocate {
                if item.value is Entry1 {
                    return false
                }
            }
        }
        
        for item in itemsToRelocate {
            guard let groupToMove = item.value else { continue }
            if groupToMove === group || groupToMove.isAncestor(of: group) {
                return false
            }
        }
        
        let backupGroup = database.getBackupGroup(createIfMissing: false)
        return (group !== backupGroup)
    }
    
    private func moveItems(to destinationGroup: Group) {
        for weakItem in itemsToRelocate {
            guard let strongItem = weakItem.value else { continue }
            if let entry = strongItem as? Entry {
                entry.move(to: destinationGroup)
            } else if let group = strongItem as? Group {
                group.move(to: destinationGroup)
            } else {
                assertionFailure()
            }
            strongItem.touch(.accessed, updateParents: true)
        }
        delegate?.didRelocateItems(in: self)
    }

    private func copyItems(to destinationGroup: Group) {
        for weakItem in itemsToRelocate {
            guard let strongItem = weakItem.value else { continue }
            if let entry = strongItem as? Entry {
                let cloneEntry = entry.clone(makeNewUUID: true)
                cloneEntry.move(to: destinationGroup)
            } else if let group = strongItem as? Group {
                let cloneGroup = group.deepClone(makeNewUUIDs: true)
                cloneGroup.move(to: destinationGroup)
            } else {
                assertionFailure()
            }
            strongItem.touch(.accessed, updateParents: true)
        }
        delegate?.didRelocateItems(in: self)
    }
    
    private func notifyContentChanged() {
        for item in itemsToRelocate {
            if let entry = item.value as? Entry, let group = entry.parent {
                EntryChangeNotifications.post(entryDidChange: entry)
                GroupChangeNotifications.post(groupDidChange: group)
            } else if let group = item.value as? Group {
                GroupChangeNotifications.post(groupDidChange: group)
            }
        }
        if let destinationGroup = destinationGroup {
            GroupChangeNotifications.post(groupDidChange: destinationGroup)
        }
    }
    
    private func showDiagnostics() {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: modalRouter)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        addChildCoordinator(diagnosticsViewerCoordinator)
        diagnosticsViewerCoordinator.start()
        router.present(modalRouter, animated: true, completion: nil)
    }
}

extension ItemRelocationCoordinator: DestinationGroupPickerDelegate {
    func didPressCancel(in groupPicker: DestinationGroupPickerVC) {
        router.pop(viewController: groupPicker, animated: true)
    }
    
    func shouldSelectGroup(_ group: Group, in groupPicker: DestinationGroupPickerVC) -> Bool {
        return isAllowedDestination(group)
    }
    
    func didSelectGroup(_ group: Group, in groupPicker: DestinationGroupPickerVC) {
        destinationGroup = group
        switch mode {
        case .move:
            moveItems(to: group)
        case .copy:
            copyItems(to: group)
        }
        DatabaseManager.shared.addObserver(self)
        DatabaseManager.shared.startSavingDatabase()
    }
}



extension ItemRelocationCoordinator: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        router.showProgressView(title: LString.databaseStatusSaving, allowCancelling: false)
    }

    func databaseManager(progressDidChange progress: ProgressEx) {
        router.updateProgressView(with: progress)
    }

    func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
        notifyContentChanged()
        router.pop(viewController: groupPicker, animated: true)
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
    }

    func databaseManager(
        database urlRef: URLReference,
        savingError error: Error,
        data: ByteArray?)
    {
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
        showDatabaseSavingError(
            error,
            fileName: urlRef.visibleFileName,
            diagnosticsHandler: { [weak self] in
                self?.showDiagnostics()
            },
            exportableData: data,
            parent: router.navigationController
        )
    }
}
