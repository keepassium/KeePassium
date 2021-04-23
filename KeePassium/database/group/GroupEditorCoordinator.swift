//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol GroupEditorCoordinatorDelegate: AnyObject {
    func didUpdateGroup(_ group: Group, in coordinator: GroupEditorCoordinator)
}

final class GroupEditorCoordinator: Coordinator, DatabaseSaving {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: GroupEditorCoordinatorDelegate?

    private let router: NavigationRouter
    private let database: Database
    private let parent: Group 
    private let originalGroup: Group? 
    
    private let groupEditorVC: GroupEditorVC
    
    private var group: Group

    internal var databaseExporterTemporaryURL: TemporaryFileURL?

    init(router: NavigationRouter, database: Database, parent: Group, target: Group?) {
        self.router = router
        self.database = database
        self.parent = parent
        self.originalGroup = target
        
        if let _target = target {
            group = _target.clone(makeNewUUID: false)
        } else {
            group = parent.createGroup(detached: true)
            group.name = LString.defaultNewGroupName
        }
        group.touch(.accessed)
        
        groupEditorVC = GroupEditorVC.instantiateFromStoryboard()
        groupEditorVC.delegate = self
        groupEditorVC.group = group
        if originalGroup == nil {
            groupEditorVC.title = LString.titleCreateGroup
        } else {
            groupEditorVC.title = LString.titleEditGroup
        }
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        router.push(groupEditorVC, animated: true, onPop: {
            [weak self] (viewController) in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        refresh()
    }
    
    private func refresh() {
        groupEditorVC.refresh()
    }
    
    private func abortAndDismiss() {
        router.pop(animated: true)
    }
    
    private func saveChangesAndDismiss() {
        group.touch(.modified, updateParents: false)
        if let originalGroup = originalGroup {
            group.apply(to: originalGroup, makeNewUUID: false)
            delegate?.didUpdateGroup(originalGroup, in: self)
            GroupChangeNotifications.post(groupDidChange: originalGroup)
        } else {
            parent.add(group: group)
            delegate?.didUpdateGroup(group, in: self)
            GroupChangeNotifications.post(groupDidChange: group)
        }
        
        let databaseManager = DatabaseManager.shared
        databaseManager.addObserver(self)
        databaseManager.startSavingDatabase()
    }
    
    private func showDiagnostics() {
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: router)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        addChildCoordinator(diagnosticsViewerCoordinator)
        diagnosticsViewerCoordinator.start()
    }
    
    func showIconPicker() {
        let iconPickerCoordinator = ItemIconPickerCoordinator(router: router, database: database)
        iconPickerCoordinator.item = group
        iconPickerCoordinator.dismissHandler = { [weak self] (coordinator) in
            self?.removeChildCoordinator(coordinator)
        }
        iconPickerCoordinator.delegate = self
        addChildCoordinator(iconPickerCoordinator)
        iconPickerCoordinator.start()
    }
}

extension GroupEditorCoordinator: GroupEditorDelegate {
    func didPressCancel(in groupEditor: GroupEditorVC) {
        abortAndDismiss()
    }
    
    func didPressDone(in groupEditor: GroupEditorVC) {
        groupEditor.resignFirstResponder()
        saveChangesAndDismiss()
    }
    
    func didPressChangeIcon(at popoverAnchor: PopoverAnchor, in groupEditor: GroupEditorVC) {
        showIconPicker()
    }
}

extension GroupEditorCoordinator: ItemIconPickerCoordinatorDelegate {
    func didSelectIcon(standardIcon: IconID, in coordinator: ItemIconPickerCoordinator) {
        group.iconID = standardIcon
        if let group2 = group as? Group2 {
            group2.customIconUUID = .ZERO
        }
        refresh()
    }

    func didSelectIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator) {
        guard let group2 = group as? Group2 else { return }
        group2.customIconUUID = customIcon
        refresh()
    }
    
    func didDeleteIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator) {
        if let group2 = group as? Group2,
           group2.customIconUUID == customIcon
        {
            delegate?.didUpdateGroup(group, in: self)
            refresh()
        }
    }
}

extension GroupEditorCoordinator: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        router.showProgressView(title: LString.databaseStatusSaving, allowCancelling: true)
    }

    func databaseManager(progressDidChange progress: ProgressEx) {
        router.updateProgressView(with: progress)
    }

    func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
        router.pop(animated: true)
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
            parent: groupEditorVC
        )
    }
}
