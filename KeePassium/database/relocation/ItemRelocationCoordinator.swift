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
    func didFinish(_ coordinator: ItemRelocationCoordinator)
}

class ItemRelocationCoordinator: Coordinator {
    
    var childCoordinators = [Coordinator]()
    
    public weak var delegate: ItemRelocationCoordinatorDelegate?
    
    public let parentViewController: UIViewController
    private weak var database: Database?
    private let mode: ItemRelocationMode
    public var itemsToRelocate = [Weak<DatabaseItem>]()
    
    private let navigationController: UINavigationController
    private var groupPicker: DestinationGroupPickerVC
    private weak var destinationGroup: Group?
    private var savingProgressOverlay: ProgressOverlay?
    
    init(database: Database, mode: ItemRelocationMode, parentViewController: UIViewController) {
        self.database = database
        self.mode = mode
        self.parentViewController = parentViewController

        let groupPicker = DestinationGroupPickerVC.create(mode: mode)
        self.groupPicker = groupPicker
        navigationController = UINavigationController(rootViewController: groupPicker)
        navigationController.modalPresentationStyle = .pageSheet
        
        navigationController.presentationController?.delegate = groupPicker
        groupPicker.delegate = self
    }
    
    func start() {
        guard let database = database,
            let rootGroup = database.root
            else { return }

        groupPicker.rootGroup = rootGroup
        parentViewController.present(navigationController, animated: true) { [weak self] in
            let currentGroup = self?.itemsToRelocate.first?.value?.parent
            self?.groupPicker.expandGroup(currentGroup)
        }
                
        DatabaseManager.shared.addObserver(self)
    }
    
    func stop() {
        DatabaseManager.shared.removeObserver(self)
        navigationController.dismiss(animated: true) { 
            self.delegate?.didFinish(self)
        }
    }
    
    private func isAllowedDestination(_ group: Group) -> Bool {
        guard let database = group.database else { return false }
        
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
}

extension ItemRelocationCoordinator: DestinationGroupPickerDelegate {
    func didPressCancel(in groupPicker: DestinationGroupPickerVC) {
        stop()
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
        DatabaseManager.shared.startSavingDatabase()
    }
}

extension ItemRelocationCoordinator: ProgressViewHost {
    
    func showSavingProgressView() {
        showProgressView(title: LString.databaseStatusSaving, allowCancelling: false)
    }
    public func showProgressView(title: String, allowCancelling: Bool) {
        assert(savingProgressOverlay == nil)
        savingProgressOverlay = ProgressOverlay.addTo(
            navigationController.view,
            title: title,
            animated: true)
        savingProgressOverlay?.isCancellable = allowCancelling
        if #available(iOS 13, *) {
            navigationController.isModalInPresentation = true
        }
        navigationController.setNavigationBarHidden(true, animated: true)
    }
    
    public func updateProgressView(with progress: ProgressEx) {
        savingProgressOverlay?.update(with: progress)
    }
    
    public func hideProgressView() {
        guard savingProgressOverlay != nil else { return }
        navigationController.setNavigationBarHidden(false, animated: true)
        if #available(iOS 13, *) {
            navigationController.isModalInPresentation = false
        }
        savingProgressOverlay?.dismiss(animated: true) {
            [weak self] (finished) in
            guard let self = self else { return }
            self.savingProgressOverlay?.removeFromSuperview()
            self.savingProgressOverlay = nil
        }
    }
}

extension ItemRelocationCoordinator: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        showSavingProgressView()
    }

    func databaseManager(progressDidChange progress: ProgressEx) {
        updateProgressView(with: progress)
    }

    func databaseManager(didSaveDatabase urlRef: URLReference) {
        hideProgressView()
        notifyContentChanged()
        stop()
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        hideProgressView()
    }

    func databaseManager(
        database urlRef: URLReference,
        savingError message: String,
        reason: String?)
    {
        hideProgressView()

        let errorAlert = UIAlertController(title: message, message: reason, preferredStyle: .alert)
        let showDetailsAction = UIAlertAction(title: LString.actionShowDetails, style: .default) {
            [weak self] _ in
            let diagnosticsViewer = ViewDiagnosticsVC.make()
            self?.navigationController.present(diagnosticsViewer, animated: true, completion: nil)
        }
        let cancelAction = UIAlertAction(
            title: LString.actionDismiss,
            style: .cancel,
            handler: nil)
        errorAlert.addAction(showDetailsAction)
        errorAlert.addAction(cancelAction)
        navigationController.present(errorAlert, animated: true, completion: nil)
    }
}
