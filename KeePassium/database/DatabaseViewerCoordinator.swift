//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseViewerCoordinatorDelegate: AnyObject {
    func didLeaveDatabase(in coordinator: DatabaseViewerCoordinator)
}

final class DatabaseViewerCoordinator: Coordinator, DatabaseSaving {
    
    private enum DatabaseLockReason: CustomStringConvertible {
        case userRequest
        case loadingWarning
        
        var description: String {
            switch self {
            case .userRequest:
                return "User request"
            case .loadingWarning:
                return "Loading warning"
            }
        }
    }
    
    var childCoordinators = [Coordinator]()
    
    weak var delegate: DatabaseViewerCoordinatorDelegate?
    var dismissHandler: CoordinatorDismissHandler?

    private let primaryRouter: NavigationRouter
    private let secondaryRouter: NavigationRouter
    private let database: Database
    private let databaseRef: URLReference
    private let loadingWarnings: DatabaseLoadingWarnings?
    
    private weak var currentGroup: Group?
    private weak var currentEntry: Entry?
    
    private let splitViewController: UISplitViewController
    private var isSplitViewCollapsed: Bool {
        return splitViewController.isCollapsed
    }
    
    private var progressOverlay: ProgressOverlay?
    private var settingsNotifications: SettingsNotifications!
    var databaseExporterTemporaryURL: TemporaryFileURL?
    
    init(
        splitViewController: UISplitViewController,
        primaryRouter: NavigationRouter,
        secondaryRouter: NavigationRouter,
        database: Database,
        databaseRef: URLReference,
        loadingWarnings: DatabaseLoadingWarnings?
    ) {
        self.splitViewController = splitViewController
        self.primaryRouter = primaryRouter
        self.secondaryRouter = secondaryRouter
        self.database = database
        self.databaseRef = databaseRef
        self.loadingWarnings = loadingWarnings
    }
    
    deinit {
        settingsNotifications.stopObserving()
        
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        settingsNotifications = SettingsNotifications(observer: self)

        showGroup(database.root)
        showEntry(nil)
        
        settingsNotifications.startObserving()
        
        if loadingWarnings != nil {
            showLoadingWarnings(loadingWarnings!)
        } else {
            StoreReviewSuggester.maybeShowAppReview(
                appVersion: AppInfo.version,
                occasion: .didOpenDatabase)
        }
    }
    
    func refresh() {
        let topPrimaryVC = primaryRouter.navigationController.topViewController
        let topSecondaryVC = secondaryRouter.navigationController.topViewController
        (topPrimaryVC as? Refreshable)?.refresh()
        (topSecondaryVC as? Refreshable)?.refresh()
    }
    
    private func getPresenterForModals() -> UIViewController {
        return splitViewController
    }
    
    private func showLoadingWarnings(_ warnings: DatabaseLoadingWarnings) {
        guard !warnings.isEmpty else { return }
        
        let presentingVC = getPresenterForModals()
        DatabaseLoadingWarningsVC.present(
            with: warnings,
            in: presentingVC,
            onLockDatabase: { [weak self] in
                self?.lockDatabase(reason: .loadingWarning)
            }
        )
        StoreReviewSuggester.registerEvent(.trouble)
    }
    
    private func showDiagnostics() {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: modalRouter)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        diagnosticsViewerCoordinator.start()
        
        getPresenterForModals().present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(diagnosticsViewerCoordinator)
    }
    
    private func showGroup(_ group: Group?) {
        guard let group = group else {
            Diag.error("The group is nil")
            assertionFailure()
            return
        }

        let previousGroup = currentGroup
        currentGroup = group

        group.touch(.accessed)
        let groupViewerVC = GroupViewerVC.instantiateFromStoryboard()
        groupViewerVC.delegate = self
        groupViewerVC.group = group
        primaryRouter.push(groupViewerVC, animated: true, onPop: {
            [weak self, previousGroup] viewController in
            guard let self = self else { return }
            self.currentGroup = previousGroup
            if previousGroup == nil { 
                self.dismissHandler?(self)
                self.delegate?.didLeaveDatabase(in: self)
            }
        })
    }

    private func selectEntry(_ entry: Entry?) {
        guard let groupViewerVC = primaryRouter.navigationController.topViewController
                as? GroupViewerVC
        else {
            assertionFailure()
            return
        }
        
        groupViewerVC.selectEntry(entry, animated: false)
        showEntry(entry)
    }
    
    private func showEntry(_ entry: Entry?) {
        currentEntry = entry
        guard let entry = entry else {
            let placeholderVC = PlaceholderVC.instantiateFromStoryboard()
            secondaryRouter.resetRoot(placeholderVC, animated: false, onPop: nil)
            return
        }
        let viewEntryVC = ViewEntryVC.make(with: entry)
        secondaryRouter.resetRoot(viewEntryVC, animated: false, onPop: nil)
    }
    
    
    private func lockDatabase(reason: DatabaseLockReason) {
        DatabaseManager.shared.closeDatabase(clearStoredKey: true, ignoreErrors: false) {
            [weak self] (error) in
            if let error = error {
                self?.getPresenterForModals().showErrorAlert(error)
            } else {
                Diag.debug("Database locked [reason: \(reason)]")
            }
        }
    }
    
    private func showGroupListSettings(at popoverAnchor: PopoverAnchor, in viewController: UIViewController) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let groupListSettingsVC = SettingsItemListVC.instantiateFromStoryboard()
        modalRouter.push(groupListSettingsVC, animated: false, onPop: nil)
        viewController.present(modalRouter, animated: true, completion: nil)
    }

    private func showAppSettings(at popoverAnchor: PopoverAnchor, in viewController: UIViewController) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let appSettingsVC = SettingsVC.instantiateFromStoryboard()
        modalRouter.push(appSettingsVC, animated: false, onPop: nil)
        viewController.present(modalRouter, animated: true, completion: nil)
    }
    
    private func showMasterKeyChanger(
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        Diag.info("Will change master key")
        
        let vc = ChangeMasterKeyVC.make(dbRef: databaseRef)
        viewController.present(vc, animated: true, completion: nil)
    }
    
    private func showGroupEditor(for groupToEdit: Group?, at popoverAnchor: PopoverAnchor?) {
        Diag.info("Will edit group")
        guard let parent = currentGroup else {
            Diag.warning("Parent group is not defined")
            assertionFailure()
            return
        }
        
        let modalRouter = NavigationRouter.createModal(style: .formSheet, at: popoverAnchor)
        let groupEditorCoordinator = GroupEditorCoordinator(
            router: modalRouter,
            database: database,
            parent: parent,
            target: groupToEdit)
        groupEditorCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        groupEditorCoordinator.delegate = self
        groupEditorCoordinator.start()
        
        getPresenterForModals().present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(groupEditorCoordinator)
    }
    
    private func showEntryEditor(for entryToEdit: Entry?, at popoverAnchor: PopoverAnchor?) {
        Diag.info("Will edit entry")
        guard let parent = currentGroup else {
            Diag.warning("Parent group is not definted")
            assertionFailure()
            return
        }
        
        let modalRouter = NavigationRouter.createModal(style: .formSheet, at: popoverAnchor)
        let entryFieldEditorCoordinator = EntryFieldEditorCoordinator(
            router: modalRouter,
            database: database,
            parent: parent,
            target: entryToEdit
        )
        entryFieldEditorCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        entryFieldEditorCoordinator.delegate = self
        entryFieldEditorCoordinator.start()
        modalRouter.dismissAttemptDelegate = entryFieldEditorCoordinator
        
        getPresenterForModals().present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(entryFieldEditorCoordinator)
    }
    
    private func showItemRelocator(
        for item: DatabaseItem,
        mode: ItemRelocationMode,
        at popoverAnchor: PopoverAnchor
    ) {
        Diag.info("Will relocate item [mode: \(mode)]")
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let itemRelocationCoordinator = ItemRelocationCoordinator(
            router: modalRouter,
            database: database,
            mode: mode,
            itemsToRelocate: [Weak(item)])
        itemRelocationCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        itemRelocationCoordinator.delegate = self
        itemRelocationCoordinator.start()
        
        getPresenterForModals().present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(itemRelocationCoordinator)
    }
    
    func saveDatabase() {
        DatabaseManager.shared.addObserver(self)
        DatabaseManager.shared.startSavingDatabase()
    }
}

extension DatabaseViewerCoordinator: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else {
            return
        }
        refresh()
    }
}

extension DatabaseViewerCoordinator: GroupViewerDelegate {
    func didPressListSettings(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC) {
        showGroupListSettings(at: popoverAnchor, in: viewController)
    }
        
    func didPressLockDatabase(in viewController: GroupViewerVC) {
        lockDatabase(reason: .userRequest)
    }

    func didPressChangeMasterKey(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC) {
        showMasterKeyChanger(at: popoverAnchor, in: viewController)
    }
    
    func didPressSettings(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC) {
        showAppSettings(at: popoverAnchor, in: viewController)
    }

    func didSelectGroup(_ group: Group?, in viewController: GroupViewerVC) -> Bool {
        showGroup(group)
        
        return false
    }
    
    func didSelectEntry(_ entry: Entry?, in viewController: GroupViewerVC) -> Bool {
        showEntry(entry)
        
        let shouldRemainSelected = !isSplitViewCollapsed
        return shouldRemainSelected
    }

    func didPressCreateGroup(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC) {
        showGroupEditor(for: nil, at: popoverAnchor)
    }

    func didPressCreateEntry(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC) {
        showEntryEditor(for: nil, at: popoverAnchor)
    }
    
    func didPressEditGroup(
        _ group: Group,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    ) {
        showGroupEditor(for: group, at: popoverAnchor)
    }

    func didPressEditEntry(
        _ entry: Entry,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    ) {
        showEntryEditor(for: entry, at: popoverAnchor)
    }
    
    func didPressDeleteGroup(
        _ group: Group,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    ) {
        database.delete(group: group)
        group.touch(.accessed)
        saveDatabase()
    }
    
    func didPressDeleteEntry(
        _ entry: Entry,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    ) {
        database.delete(entry: entry)
        entry.touch(.accessed)
        let isDeletedCurrentEntry = entry === currentEntry
        if isDeletedCurrentEntry {
            selectEntry(nil)
            showEntry(nil)
        }
        saveDatabase()
    }
    
    func didPressRelocateItem(
        _ item: DatabaseItem,
        mode: ItemRelocationMode,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    ) {
        showItemRelocator(for: item, mode: mode, at: popoverAnchor)
    }
    
    func getActionPermissions(for group: Group) -> DatabaseItemActionPermissions {
        var result = DatabaseItemActionPermissions()
        let isRecycleBin = (group === group.database?.getBackupGroup(createIfMissing: false))

        result.canCreateGroup = !group.isDeleted

        if group is Group1 {
            result.canCreateEntry = !group.isDeleted && !group.isRoot
        } else {
            result.canCreateEntry = !group.isDeleted
        }
        
        if isRecycleBin {
            result.canEdit = group is Group2
        } else {
            result.canEdit = !group.isDeleted
        }
        
        result.canDelete = !group.isRoot
        
        result.canMove = !group.isRoot
        if (group is Group1) && isRecycleBin {
            result.canMove = false
        }
        return result
    }
    
    func getActionPermissions(for entry: Entry) -> DatabaseItemActionPermissions {
        var result = DatabaseItemActionPermissions()
        result.canCreateGroup = false
        result.canCreateEntry = false
        result.canEdit = !entry.isDeleted
        result.canDelete = true 
        result.canMove = true
        return result
    }
}

extension DatabaseViewerCoordinator: ProgressViewHost {
    public func showProgressView(title: String, allowCancelling: Bool) {
        progressOverlay = ProgressOverlay.addTo(
            splitViewController.view,
            title: title,
            animated: true)
        progressOverlay?.isCancellable = allowCancelling
    }
    
    public func updateProgressView(with progress: ProgressEx) {
        assert(progressOverlay != nil)
        progressOverlay?.update(with: progress)
    }
    
    public func hideProgressView() {
        progressOverlay?.dismiss(animated: true) { [weak self] finished in
            guard let self = self else { return }
            self.progressOverlay?.removeFromSuperview()
            self.progressOverlay = nil
        }
    }
}

extension DatabaseViewerCoordinator: DatabaseManagerObserver {
    
    public func databaseManager(willSaveDatabase urlRef: URLReference) {
        showProgressView(title: LString.databaseStatusSaving, allowCancelling: false)
    }

    public func databaseManager(progressDidChange progress: ProgressEx) {
        updateProgressView(with: progress)
    }

    public func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        DatabaseManager.shared.removeObserver(self)
        refresh()
        hideProgressView()
    }

    public func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        refresh()
        hideProgressView()
    }
    
    public func databaseManager(
        database urlRef: URLReference,
        savingError error: Error,
        data: ByteArray?
    ) {
        DatabaseManager.shared.removeObserver(self)
        refresh()
        hideProgressView()
        
        showDatabaseSavingError(
            error,
            fileName: urlRef.visibleFileName,
            diagnosticsHandler: { [weak self] in
                self?.showDiagnostics()
            },
            exportableData: data,
            parent: getPresenterForModals()
        )
    }
}

extension DatabaseViewerCoordinator: GroupEditorCoordinatorDelegate {
    func didUpdateGroup(_ group: Group, in coordinator: GroupEditorCoordinator) {
        refresh()
        StoreReviewSuggester.maybeShowAppReview(appVersion: AppInfo.version, occasion: .didEditItem)
    }
}

extension DatabaseViewerCoordinator: EntryFieldEditorCoordinatorDelegate {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryFieldEditorCoordinator) {
        refresh()
        selectEntry(entry)
        StoreReviewSuggester.maybeShowAppReview(appVersion: AppInfo.version, occasion: .didEditItem)
    }
}

extension DatabaseViewerCoordinator: ItemRelocationCoordinatorDelegate {
    func didRelocateItems(in coordinator: ItemRelocationCoordinator) {
        refresh()
    }
}
