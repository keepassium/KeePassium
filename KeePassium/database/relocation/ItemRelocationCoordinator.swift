//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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

protocol ItemRelocationCoordinatorDelegate: AnyObject {
    func didRelocateItems(in coordinator: ItemRelocationCoordinator)
    
    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL)
}

class ItemRelocationCoordinator: Coordinator {
    
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    
    public weak var delegate: ItemRelocationCoordinatorDelegate?
    
    private let router: NavigationRouter
    
    private let sourceDatabaseFile: DatabaseFile
    private let sourceDatabase: Database
    private var targetDatabaseFile: DatabaseFile
    private var targetDatabase: Database
    private let mode: ItemRelocationMode
    private var itemsToRelocate = [Weak<DatabaseItem>]()
    
    private let groupPicker: DestinationGroupPickerVC
    private var databasePickerCoordinator: DatabasePickerCoordinator?
    private var externalGroupPicker: DestinationGroupPickerVC?
    private weak var destinationGroup: Group?
    
    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return router }
    
    private var postSavingPhase: (()->Void)?
    
    init(
        router: NavigationRouter,
        databaseFile: DatabaseFile,
        mode: ItemRelocationMode,
        itemsToRelocate: [Weak<DatabaseItem>]
    ) {
        self.router = router
        self.sourceDatabaseFile = databaseFile
        self.sourceDatabase = databaseFile.database
        self.targetDatabaseFile = databaseFile
        self.targetDatabase = databaseFile.database
        self.mode = mode
        self.itemsToRelocate = itemsToRelocate

        self.groupPicker = DestinationGroupPickerVC.create(mode: mode)
        groupPicker.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        guard let rootGroup = targetDatabase.root else {
            assertionFailure();
            return
        }

        groupPicker.rootGroup = rootGroup
        router.push(groupPicker, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })

        let currentGroup = itemsToRelocate.first?.value?.parent
        groupPicker.expandGroup(currentGroup)
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

extension ItemRelocationCoordinator {
    
    private func isAllowedDestination(_ group: Group) -> Bool {
        guard group.database === targetDatabase else {
            assertionFailure()
            return false
        }
        
        if let database1 = targetDatabase as? Database1,
            let root1 = database1.root,
            group === root1
        {
            for item in itemsToRelocate {
                if item.value is Entry1 {
                    return false
                }
            }
        }
        
        if sourceDatabase === targetDatabase {
            let hasImmovableItems = itemsToRelocate.contains {
                guard let itemToMove = $0.value else { return false }
                return itemToMove === group || itemToMove.isAncestor(of: group)
            }
            if hasImmovableItems {
                return false
            }
        }
        return true
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
    
    
    private func relocateWithinDatabase(to destinationGroup: Group) {
        assert(sourceDatabase === targetDatabase)
        switch mode {
        case .move:
            moveItemsWithingDatabase(to: destinationGroup)
        case .copy:
            copyItemsWithinDatabase(to: destinationGroup)
        }
        Diag.info("Saving the database")
        postSavingPhase = nil 
        saveDatabase(sourceDatabaseFile)
    }
    
    private func moveItemsWithingDatabase(to destinationGroup: Group) {
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

    private func copyItemsWithinDatabase(to destinationGroup: Group) {
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
    
    
    private func relocateAcrossDatabases(to destinationGroup: Group) {
        assert(sourceDatabase !== targetDatabase)
        switch mode {
        case .move:
            crossDatabaseCopyItems(to: destinationGroup)
            Diag.info("Saving target database")
            postSavingPhase = { [self] in
                Diag.debug("Updating source database")
                deleteItemsFromSourceDatabase()
                saveDatabase(sourceDatabaseFile)
            }
            saveDatabase(targetDatabaseFile)
        case .copy:
            crossDatabaseCopyItems(to: destinationGroup)
            Diag.info("Saving target database")
            postSavingPhase = nil 
            saveDatabase(targetDatabaseFile)
        }
    }
    
    private func deleteItemsFromSourceDatabase() {
        itemsToRelocate
            .compactMap({ $0.value })
            .forEach { item in
                if let entry = item as? Entry {
                    sourceDatabase.delete(entry: entry)
                } else if let group = item as? Group {
                    sourceDatabase.delete(group: group)
                } else {
                    assertionFailure()
                }
            }
    }
    
    private func crossDatabaseCopyItems(to destinationGroup: Group) {
        itemsToRelocate
            .compactMap({ $0.value })
            .forEach { item in
                if let entry = item as? Entry {
                    crossDatabaseCopy(entry: entry, to: destinationGroup)
                } else if let group = item as? Group {
                    crossDatabaseCopy(group: group, to: destinationGroup)
                } else {
                    assertionFailure()
                }
            }
    }
    
    private func crossDatabaseCopy(entry: Entry, to destinationGroup: Group) {
        let cloneEntry = entry.clone(makeNewUUID: true)
        destinationGroup.add(entry: cloneEntry)
        cloneEntry.touch(.modified, updateParents: false) 
        
        guard let sourceDatabase2 = sourceDatabase as? Database2,
              let targetDatabase2 = targetDatabase as? Database2,
              let entry2 = cloneEntry as? Entry2
        else {
            return
        }
        
        crossDatabaseCopyCustomIcons(
            from: sourceDatabase2,
            to: targetDatabase2,
            groups: [],
            entries: [entry2]
        )
    }
    
    private func crossDatabaseCopy(group: Group, to destinationGroup: Group) {
        let cloneGroup = group.deepClone(makeNewUUIDs: true)
        destinationGroup.add(group: cloneGroup)
        cloneGroup.touch(.modified, updateParents: false) 
        
        guard let sourceDatabase2 = sourceDatabase as? Database2,
              let targetDatabase2 = targetDatabase as? Database2,
              let cloneGroup2 = cloneGroup as? Group2
        else {
            return
        }
        var groups: [Group] = [cloneGroup2]
        var entries = [Entry]()
        cloneGroup2.collectAllChildren(groups: &groups, entries: &entries)
        
        let groups2 = groups.map { $0 as! Group2 }
        let entries2 = entries.map { $0 as! Entry2 }
        crossDatabaseCopyCustomIcons(
            from: sourceDatabase2,
            to: targetDatabase2,
            groups: groups2,
            entries: entries2
        )
    }
    
    private func crossDatabaseCopyCustomIcons(
        from sourceDatabase: Database2,
        to targetDatabase: Database2,
        groups: [Group2],
        entries: [Entry2]
    ) {
        var sourceIcons = [CustomIcon2]()
        sourceIcons.append(contentsOf: entries.compactMap {
            sourceDatabase.getCustomIcon(with: $0.customIconUUID)
        })
        sourceIcons.append(contentsOf: groups.compactMap {
            sourceDatabase.getCustomIcon(with: $0.customIconUUID)
        })
        
        var sourceIconsByUUID = [UUID: CustomIcon2]()
        sourceIcons.forEach {
            sourceIconsByUUID[$0.uuid] = $0
        }
        let uniqueSourceIcons = sourceIconsByUUID.values
        
        var newIconUUIDs = [UUID: UUID]()
        uniqueSourceIcons.forEach {
            let newIcon = targetDatabase.addCustomIcon(pngData: $0.data)
            newIconUUIDs[$0.uuid] = newIcon.uuid
        }
        
        entries.forEach {
            $0.customIconUUID = newIconUUIDs[$0.customIconUUID] ?? .ZERO
        }
        groups.forEach {
            $0.customIconUUID = newIconUUIDs[$0.customIconUUID] ?? .ZERO
        }
    }
}

extension ItemRelocationCoordinator: DestinationGroupPickerDelegate {
    func didPressCancel(in groupPicker: DestinationGroupPickerVC) {
        router.dismiss(animated: true, completion: nil)
    }
    
    func shouldSelectGroup(_ group: Group, in groupPicker: DestinationGroupPickerVC) -> Bool {
        return isAllowedDestination(group)
    }
    
    func didSelectGroup(_ group: Group, in groupPicker: DestinationGroupPickerVC) {
        destinationGroup = group
        if sourceDatabase === targetDatabase {
            relocateWithinDatabase(to: group)
        } else {
            relocateAcrossDatabases(to: group)
        }
    }
    
    func didPressSwitchDatabase(
        at popoverAnchor: PopoverAnchor,
        in groupPicker: DestinationGroupPickerVC
    ) {
        performPremiumActionOrOfferUpgrade(
            for: .canRelocateAcrossDatabases,
            allowBypass: false,
            in: groupPicker,
            actionHandler: { [weak self] in
                self?.pickDifferentDatabase()
            }
        )
    }
}

extension ItemRelocationCoordinator: DatabaseSaving {
    func canCancelSaving(databaseFile: DatabaseFile) -> Bool {
        return false
    }
    
    func didSave(databaseFile: DatabaseFile) {
        if let postSavingPhase = postSavingPhase {
            Diag.info("Starting post-save phase")
            self.postSavingPhase = nil
            postSavingPhase()
            return
        }
        delegate?.didRelocateItems(in: self)
        notifyContentChanged()
        router.pop(viewController: groupPicker, animated: true)
    }
    
    func didRelocate(databaseFile: DatabaseFile, to newURL: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: newURL)
    }
    
    func getDatabaseSavingErrorParent() -> UIViewController {
        return router.navigationController
    }
    
    func getDiagnosticsHandler() -> (() -> Void)? {
        return showDiagnostics
    }
}

extension ItemRelocationCoordinator {
    private func pickDifferentDatabase() {
        let databasePickerCoordinator = DatabasePickerCoordinator(router: router, mode: .light)
        databasePickerCoordinator.delegate = self
        databasePickerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.databasePickerCoordinator = nil
            self?.removeChildCoordinator(coordinator)
        }
        databasePickerCoordinator.start()
        addChildCoordinator(databasePickerCoordinator)

        self.databasePickerCoordinator = databasePickerCoordinator
    }
    
    private func unlockDatabase(_ fileRef: URLReference) {
        let databaseUnlockerCoordinator = DatabaseUnlockerCoordinator(
            router: router,
            databaseRef: fileRef
        )
        databaseUnlockerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        databaseUnlockerCoordinator.delegate = self
        databaseUnlockerCoordinator.start()
        addChildCoordinator(databaseUnlockerCoordinator)
    }
    
    private func showTargetDatabase(
        _ databaseFile: DatabaseFile,
        at fileRef: URLReference,
        warnings: DatabaseLoadingWarnings
    ) {
        targetDatabaseFile = databaseFile
        targetDatabase = databaseFile.database
        assert(externalGroupPicker == nil)
        let externalGroupPicker = DestinationGroupPickerVC.create(
            mode: mode,
            canSwitchDatabase: false
        )
        externalGroupPicker.delegate = self
        externalGroupPicker.rootGroup = databaseFile.database.root
        externalGroupPicker.expandGroup(databaseFile.database.root)
        externalGroupPicker.refresh()
        router.push(externalGroupPicker, animated: true, replaceTopViewController: true, onPop: {
            [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        self.externalGroupPicker = externalGroupPicker
        
        if targetDatabase is Database1 && sourceDatabase is Database2 {
            warnings.addIssue(.lesserTargetFormat)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showLoadingWarnings(warnings, for: databaseFile)
        }
    }
    
    private func showLoadingWarnings(
        _ warnings: DatabaseLoadingWarnings,
        for databaseFile: DatabaseFile
    ) {
        guard !warnings.isEmpty else { return }
        
        DatabaseLoadingWarningsVC.present(
            warnings,
            in: externalGroupPicker ?? groupPicker,
            onLockDatabase: { [weak self] in
                self?.router.dismiss(animated: true, completion: nil)
            }
        )
        StoreReviewSuggester.registerEvent(.trouble)
    }
}

extension ItemRelocationCoordinator: DatabasePickerCoordinatorDelegate {    
    func shouldAcceptDatabaseSelection(
        _ fileRef: URLReference,
        in coordinator: DatabasePickerCoordinator
    ) -> Bool {
        let isReadOnly = DatabaseSettingsManager.shared.isReadOnly(fileRef)
        if isReadOnly {
            router.navigationController.showNotification(LString.databaseIsReadOnly)
        }
        return !isReadOnly
    }
    
    func didSelectDatabase(_ fileRef: URLReference?, in coordinator: DatabasePickerCoordinator) {
        guard let fileRef = fileRef else { return }
        assert(!DatabaseSettingsManager.shared.isReadOnly(fileRef), "Cannot relocate to read-only DB")
        router.navigationController.hideAllToasts()
        unlockDatabase(fileRef)
    }
    
    func shouldKeepSelection(in coordinator: DatabasePickerCoordinator) -> Bool {
        return false
    }
}

extension ItemRelocationCoordinator: DatabaseUnlockerCoordinatorDelegate {
    func shouldDismissFromKeyboard(_ coordinator: DatabaseUnlockerCoordinator) -> Bool {
        return true
    }
    
    func shouldAutoUnlockDatabase(
        _ fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) -> Bool {
        return true
    }
    
    func willUnlockDatabase(_ fileRef: URLReference, in coordinator: DatabaseUnlockerCoordinator) {
    }
    
    func didNotUnlockDatabase(_ fileRef: URLReference, with message: String?, reason: String?, in coordinator: DatabaseUnlockerCoordinator) {
    }
    
    func shouldChooseFallbackStrategy(
        for fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) -> UnreachableFileFallbackStrategy {
        return .showError 
    }
    
    func didUnlockDatabase(
        databaseFile: DatabaseFile,
        at fileRef: URLReference,
        warnings: DatabaseLoadingWarnings,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        showTargetDatabase(databaseFile, at: fileRef, warnings: warnings)
    }
    
    func didPressReinstateDatabase(
        _ fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        guard let databasePickerCoordinator = databasePickerCoordinator else {
            Diag.warning("No database picker found, cancelling")
            return
        }
        
        router.pop(animated: true, completion: { [weak self] in
            guard let self = self else { return }
            databasePickerCoordinator.addExistingDatabase(
                presenter: self.router.navigationController
            )
        })
    }
}
