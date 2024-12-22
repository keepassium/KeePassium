//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

public enum DatabaseCloseReason: CustomStringConvertible {
    case userRequest
    case databaseTimeout
    case appLevelOperation

    public var description: String {
        switch self {
        case .userRequest:
            return "User request"
        case .databaseTimeout:
            return "Database timeout"
        case .appLevelOperation:
            return "App-level operation"
        }
    }
}

protocol DatabaseViewerCoordinatorDelegate: AnyObject {
    func didLeaveDatabase(in coordinator: DatabaseViewerCoordinator)

    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL)

    func didPressReinstateDatabase(_ fileRef: URLReference, in coordinator: DatabaseViewerCoordinator)

    func didPressReloadDatabase(
        _ databaseFile: DatabaseFile,
        originalRef: URLReference,
        in coordinator: DatabaseViewerCoordinator
    )

    func didPressSwitchTo(
        databaseRef: URLReference,
        compositeKey: CompositeKey,
        in coordinator: DatabaseViewerCoordinator
    )
}

final class DatabaseViewerCoordinator: Coordinator {
    private let vcAnimationDuration = 0.3

    var childCoordinators = [Coordinator]()

    weak var delegate: DatabaseViewerCoordinatorDelegate?
    var dismissHandler: CoordinatorDismissHandler?

    public var currentGroupUUID: UUID? { currentGroup?.uuid }

    private let primaryRouter: NavigationRouter
    private let placeholderRouter: NavigationRouter
    private var entryViewerRouter: NavigationRouter?

    private let originalRef: URLReference
    private let databaseFile: DatabaseFile
    private let database: Database

    private let loadingWarnings: DatabaseLoadingWarnings?
    private var announcements = [AnnouncementItem]()

    private var canEditDatabase: Bool {
        return !databaseFile.status.contains(.readOnly)
    }

    private var initialGroupUUID: UUID?
    fileprivate weak var currentGroup: Group?
    fileprivate weak var currentEntry: Entry?
    private weak var rootGroupViewer: GroupViewerVC?
    private var topGroupViewer: GroupViewerVC? {
        primaryRouter.navigationController.topViewController as? GroupViewerVC
    }

    private let splitViewController: RootSplitVC
    private weak var oldSplitDelegate: UISplitViewControllerDelegate?
    private var isSplitViewCollapsed: Bool {
        return splitViewController.isCollapsed
    }

    private var oldPrimaryRouterDetailDismissalHandler:
        NavigationRouter.CollapsedDetailDismissalHandler?

    private var progressOverlay: ProgressOverlay?
    private var settingsNotifications: SettingsNotifications!

    var hasUnsavedBulkChanges = false
    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return self }
    var saveSuccessHandler: (() -> Void)?

    let faviconDownloader: FaviconDownloader
    let specialEntryParser: SpecialEntryParser

    private(set) var actionsManager: DatabaseViewerActionsManager!
    var currentGroupPermissions: DatabaseViewerPermissionManager.Permissions {
        if let currentGroup {
            return DatabaseViewerPermissionManager.getPermissions(for: currentGroup, in: databaseFile)
        } else {
            return []
        }
    }

    init(
        splitViewController: RootSplitVC,
        primaryRouter: NavigationRouter,
        originalRef: URLReference,
        databaseFile: DatabaseFile,
        context: DatabaseReloadContext?,
        loadingWarnings: DatabaseLoadingWarnings?
    ) {
        self.splitViewController = splitViewController
        self.primaryRouter = primaryRouter

        self.originalRef = originalRef
        self.databaseFile = databaseFile
        self.database = databaseFile.database
        self.loadingWarnings = loadingWarnings

        self.initialGroupUUID = context?.groupUUID

        let placeholderVC = PlaceholderVC.instantiateFromStoryboard()
        let placeholderWrapperVC = RouterNavigationController(rootViewController: placeholderVC)
        self.placeholderRouter = NavigationRouter(placeholderWrapperVC)

        faviconDownloader = FaviconDownloader()
        specialEntryParser = SpecialEntryParser()

        actionsManager = DatabaseViewerActionsManager(coordinator: self)
    }

    deinit {
        settingsNotifications.stopObserving()

        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        oldSplitDelegate = splitViewController.delegate
        splitViewController.delegate = self

        oldPrimaryRouterDetailDismissalHandler = primaryRouter.collapsedDetailDismissalHandler
        primaryRouter.collapsedDetailDismissalHandler = { [weak self] dismissedVC in
            guard let self = self else { return }
            if dismissedVC === self.entryViewerRouter?.navigationController {
                self.showEntry(nil)
            }
        }

        settingsNotifications = SettingsNotifications(observer: self)

        showInitialGroups(replacingTopVC: splitViewController.isCollapsed)
        showEntry(nil)

        settingsNotifications.startObserving()

        updateAnnouncements()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2 * vcAnimationDuration) { [weak self] in
            self?.showInitialMessages()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
    }

    public func stop(animated: Bool, completion: (() -> Void)?) {
        guard let rootGroupViewer = rootGroupViewer else {
            assertionFailure("Group viewer already deallocated")
            Diag.debug("Group viewer is already deallocated, ignoring")
            return
        }
        primaryRouter.dismissModals(animated: animated) { [self, rootGroupViewer] in 
            self.primaryRouter.pop(
                viewController: rootGroupViewer,
                animated: animated,
                completion: completion
            )
        }
    }

    func refresh() {
        updateAnnouncements()
        if let topPrimaryVC = primaryRouter.navigationController.topViewController {
            (topPrimaryVC as? Refreshable)?.refresh()
        }
        if let topSecondaryVC = entryViewerRouter?.navigationController.topViewController {
            (topSecondaryVC as? Refreshable)?.refresh()
        }

        UIMenu.rebuildMainMenu()
    }

    func reorder() {
        guard let groupViewerVC = topGroupViewer else {
            assertionFailure()
            return
        }
        groupViewerVC.reorder()
    }

    private func getPresenterForModals() -> UIViewController {
        return splitViewController.presentedViewController ?? splitViewController
    }

    @objc
    private func appDidBecomeActive(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.maybeCheckDatabaseForExternalChanges()
        }
    }
}

extension DatabaseViewerCoordinator {
    private func showInitialMessages() {
        if loadingWarnings != nil {
            showLoadingWarnings(loadingWarnings!)
        }
        if announcements.isEmpty {
            StoreReviewSuggester.maybeShowAppReview(
                appVersion: AppInfo.version,
                occasion: .didOpenDatabase
            )
        }
    }

    private func showLoadingWarnings(_ warnings: DatabaseLoadingWarnings) {
        guard !warnings.isEmpty else { return }

        let presentingVC = getPresenterForModals()
        DatabaseLoadingWarningsVC.present(
            warnings,
            in: presentingVC,
            onLockDatabase: { [weak self] in
                self?.closeDatabase(
                    shouldLock: true,
                    reason: .userRequest,
                    animated: true,
                    completion: nil
                )
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

    private func startAppProtectionSetup() {
        let passcodeInputVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeInputVC.delegate = self
        passcodeInputVC.mode = .setup
        passcodeInputVC.modalPresentationStyle = .formSheet
        passcodeInputVC.isCancelAllowed = true
        getPresenterForModals().present(passcodeInputVC, animated: true, completion: nil)
    }

    private func showInitialGroups(replacingTopVC: Bool) {
        guard let initialGroupUUID,
              let initialGroup = database.root?.findGroup(byUUID: initialGroupUUID)
        else {
            showGroup(database.root, replacingTopVC: replacingTopVC, animated: true)
            return
        }

        var groupStack = [Group]()
        var currentGroup: Group? = initialGroup
        while let subgroup = currentGroup {
            groupStack.append(subgroup)
            currentGroup = currentGroup?.parent
        }
        groupStack.reverse() 

        let rootGroup = groupStack.removeFirst()
        showGroup(rootGroup, replacingTopVC: replacingTopVC, animated: false)

        groupStack.forEach { subgroup in
            DispatchQueue.main.async {
                self.showGroup(subgroup, animated: false)
            }
        }
    }

    private func showGroup(_ group: Group?, replacingTopVC: Bool = false, animated: Bool) {
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
        groupViewerVC.canDownloadFavicons = database is Database2
        groupViewerVC.canChangeEncryptionSettings = database is Database2
        groupViewerVC.permissions = currentGroupPermissions

        let isCustomTransition = replacingTopVC && animated
        if isCustomTransition {
            primaryRouter.prepareCustomTransition(
                duration: vcAnimationDuration,
                type: .fade,
                timingFunction: .easeOut
            )
        }
        primaryRouter.push(
            groupViewerVC,
            animated: animated && !isCustomTransition,
            replaceTopViewController: replacingTopVC,
            onPop: { [weak self, previousGroup] in
                guard let self = self else { return }
                self.currentGroup = previousGroup
                if previousGroup == nil { 
                    self.showEntry(nil) 
                    self.splitViewController.delegate = self.oldSplitDelegate
                    self.primaryRouter.collapsedDetailDismissalHandler =
                        self.oldPrimaryRouterDetailDismissalHandler
                    self.dismissHandler?(self)
                    self.delegate?.didLeaveDatabase(in: self)
                }
                UIMenu.rebuildMainMenu()
            }
        )

        if rootGroupViewer == nil {
            rootGroupViewer = groupViewerVC
        }

        UIMenu.rebuildMainMenu()
    }

    private func selectEntry(_ entry: Entry?) {
        focusOnEntry(entry)
        showEntry(entry)
    }

    private func focusOnEntry(_ entry: Entry?) {
        guard let groupViewerVC = topGroupViewer else {
            assertionFailure()
            return
        }
        groupViewerVC.selectEntry(entry, animated: false)
    }

    private func showEntry(_ entry: Entry?) {
        defer {
            UIMenu.rebuildMainMenu()
        }
        currentEntry = entry
        guard let entry = entry else {
            if !splitViewController.isCollapsed {
                splitViewController.setDetailRouter(placeholderRouter)
            }
            entryViewerRouter?.popAll()
            entryViewerRouter = nil
            childCoordinators.removeAll(where: { $0 is EntryViewerCoordinator })
            return
        }

        if let existingCoordinator = childCoordinators.first(where: { $0 is EntryViewerCoordinator }) {
            let entryViewerCoordinator = existingCoordinator as! EntryViewerCoordinator 
            entryViewerCoordinator.setEntry(
                entry,
                isHistoryEntry: false,
                canEditEntry: canEditDatabase && !entry.isDeleted
            )
            guard let entryViewerRouter = self.entryViewerRouter else {
                Diag.error("Coordinator without a router, aborting")
                assertionFailure()
                return
            }
            splitViewController.setDetailRouter(entryViewerRouter)
            return
        }

        let entryViewerRouter = NavigationRouter(RouterNavigationController())
        let entryViewerCoordinator = EntryViewerCoordinator(
            entry: entry,
            databaseFile: databaseFile,
            isHistoryEntry: false,
            canEditEntry: canEditDatabase && !entry.isDeleted,
            router: entryViewerRouter,
            progressHost: self 
        )
        entryViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
            self?.entryViewerRouter = nil
        }
        entryViewerCoordinator.delegate = self
        entryViewerCoordinator.start()
        addChildCoordinator(entryViewerCoordinator)

        self.entryViewerRouter = entryViewerRouter
        splitViewController.setDetailRouter(entryViewerRouter)
    }

    public func reloadDatabase() {
        delegate?.didPressReloadDatabase(databaseFile, originalRef: originalRef, in: self)
    }

    public func closeDatabase(
        shouldLock: Bool,
        reason: DatabaseCloseReason,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        if shouldLock {
            DatabaseSettingsManager.shared.updateSettings(for: originalRef) {
                $0.clearMasterKey()
            }
        }
        Diag.debug("Database closed [locked: \(shouldLock), reason: \(reason)]")
        stop(animated: animated, completion: completion)
    }

    private func showAppSettings(at popoverAnchor: PopoverAnchor, in viewController: UIViewController) {
        let modalRouter = NavigationRouter.createModal(
            style: ProcessInfo.isRunningOnMac ? .formSheet : .popover,
            at: popoverAnchor)
        let settingsCoordinator = SettingsCoordinator(router: modalRouter)
        settingsCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        settingsCoordinator.start()
        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(settingsCoordinator)
    }

    func showPasswordAudit(in viewController: UIViewController? = nil) {
        let presenter = viewController ?? getPresenterForModals()
        guard ManagedAppConfig.shared.isPasswordAuditAllowed else {
            assertionFailure("This action should have been disabled in UI")
            presenter.showManagedFeatureBlockedNotification()
            return
        }
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let passwordAuditCoordinator = PasswordAuditCoordinator(
            databaseFile: databaseFile,
            router: modalRouter
        )
        passwordAuditCoordinator.delegate = self
        passwordAuditCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
            self?.refresh()
        }
        passwordAuditCoordinator.start()
        presenter.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(passwordAuditCoordinator)
    }

    func showEncryptionSettings(in viewController: UIViewController? = nil) {
        let presenter = viewController ?? getPresenterForModals()
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let encryptionSettingsCoordinator = EncryptionSettingsCoordinator(
            databaseFile: databaseFile,
            router: modalRouter
        )
        encryptionSettingsCoordinator.delegate = self
        encryptionSettingsCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
            self?.refresh()
        }
        encryptionSettingsCoordinator.start()
        presenter.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(encryptionSettingsCoordinator)
    }

    private func downloadFavicons(for entries: [Entry], in viewController: UIViewController) {
        downloadFavicons(for: entries, in: viewController) { [weak self] downloadedFavicons in
            guard let downloadedFavicons,
                  let db2 = self?.database as? Database2,
                  let databaseFile = self?.databaseFile
            else {
                return
            }

            downloadedFavicons.forEach {
                guard let entry2 = $0.entry as? Entry2 else {
                    return
                }

                guard let icon = db2.addCustomIcon($0.image) else {
                    Diag.error("Failed to add favicon to database")
                    return
                }
                db2.setCustomIcon(icon, for: entry2)
            }
            self?.refresh()

            let alert = UIAlertController(
                title: databaseFile.visibleFileName,
                message: String.localizedStringWithFormat(
                    LString.faviconUpdateStatsTemplate,
                    entries.count,
                    downloadedFavicons.count),
                preferredStyle: .alert
            )
            alert.addAction(title: LString.actionSaveDatabase, style: .default, preferred: true) { [weak self] _ in
                self?.saveDatabase(databaseFile)
            }
            viewController.present(alert, animated: true)
        }
    }

    func downloadFavicons(in viewController: UIViewController? = nil) {
        var allEntries = [Entry]()
        databaseFile.database.root?.collectAllEntries(to: &allEntries)

        let presenter = viewController ?? getPresenterForModals()
        downloadFavicons(for: allEntries, in: presenter)
    }

    func showMasterKeyChanger(in viewController: UIViewController? = nil) {
        Diag.info("Will change master key")
        let presenter = viewController ?? getPresenterForModals()

        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let databaseKeyChangeCoordinator = DatabaseKeyChangerCoordinator(
            databaseFile: databaseFile,
            router: modalRouter
        )
        databaseKeyChangeCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        databaseKeyChangeCoordinator.delegate = self
        databaseKeyChangeCoordinator.start()
        presenter.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(databaseKeyChangeCoordinator)
    }

    private func showGroupEditor(_ mode: GroupEditorCoordinator.Mode, at popoverAnchor: PopoverAnchor?) {
        Diag.info("Will edit group")
        guard let parent = currentGroup else {
            Diag.warning("Parent group is not defined")
            assertionFailure()
            return
        }

        let modalRouter = NavigationRouter.createModal(style: .formSheet, at: popoverAnchor)
        let groupEditorCoordinator = GroupEditorCoordinator(
            router: modalRouter,
            databaseFile: databaseFile,
            parent: parent,
            mode: mode
        )
        groupEditorCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        groupEditorCoordinator.delegate = self
        groupEditorCoordinator.start()

        getPresenterForModals().present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(groupEditorCoordinator)
    }

    func showGroupEditor(_ mode: GroupEditorCoordinator.Mode) {
        primaryRouter.dismissModals(animated: true) { [self] in
            showGroupEditor(mode, at: nil)
        }
    }

    private func showEntryEditor(
        for entryToEdit: Entry?,
        at popoverAnchor: PopoverAnchor?,
        onDismiss: (() -> Void)? = nil
    ) {
        Diag.info("Will edit entry")
        guard let parent = currentGroup else {
            Diag.warning("Parent group is not definted")
            assertionFailure()
            return
        }

        let modalRouter = NavigationRouter.createModal(style: .formSheet, at: popoverAnchor)
        let entryFieldEditorCoordinator = EntryFieldEditorCoordinator(
            router: modalRouter,
            databaseFile: databaseFile,
            parent: parent,
            target: entryToEdit
        )
        entryFieldEditorCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
            onDismiss?()
        }
        entryFieldEditorCoordinator.delegate = self
        entryFieldEditorCoordinator.start()
        modalRouter.dismissAttemptDelegate = entryFieldEditorCoordinator

        getPresenterForModals().present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(entryFieldEditorCoordinator)
    }

    func showEntryEditor() {
        primaryRouter.dismissModals(animated: true) { [self] in
            showEntryEditor(for: nil, at: nil)
        }
    }

    private func showItemRelocator(
        for items: [DatabaseItem],
        mode: ItemRelocationMode,
        at popoverAnchor: PopoverAnchor
    ) {
        Diag.info("Will relocate item [mode: \(mode)]")
        let modalRouter = NavigationRouter.createModal(style: .formSheet, at: popoverAnchor)
        let itemRelocationCoordinator = ItemRelocationCoordinator(
            router: modalRouter,
            databaseFile: databaseFile,
            mode: mode,
            itemsToRelocate: items.map({ Weak($0) }))
        itemRelocationCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        itemRelocationCoordinator.delegate = self
        itemRelocationCoordinator.start()

        getPresenterForModals().present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(itemRelocationCoordinator)
    }

    func showDatabasePrintDialog() {
        guard ManagedAppConfig.shared.isDatabasePrintAllowed else {
            getPresenterForModals().showManagedFeatureBlockedNotification()
            Diag.error("Blocked by organization's policy, cancelling")
            return
        }
        Diag.info("Will print database")
        let databaseFormatter = DatabasePrintFormatter()
        guard let formattedText = databaseFormatter.toAttributedString(
            database: database,
            title: databaseFile.visibleFileName)
        else {
            Diag.info("Could not format database for printing, skipping")
            return
        }

        if ProcessInfo.isRunningOnMac {
            showProgressView(title: "", allowCancelling: false, animated: false)
            let indefiniteProgress = ProgressEx()
            indefiniteProgress.totalUnitCount = -1
            indefiniteProgress.status = LString.databaseStatusPreparingPrintPreview
            updateProgressView(with: indefiniteProgress)
        }

        let printFormatter = UISimpleTextPrintFormatter(attributedText: formattedText)
        printFormatter.perPageContentInsets = UIEdgeInsets(
            top: 72,
            left: 72,
            bottom: 72,
            right: 72
        )

        let printController = UIPrintInteractionController.shared
        printController.printFormatter = printFormatter
        printController.present(animated: true, completionHandler: { [weak self] _, _, _ in
            printController.printFormatter = nil
            if ProcessInfo.isRunningOnMac {
                self?.hideProgressView(animated: false)
            }
            Diag.debug("Print dialog closed")
        })
        Diag.debug("Preparing print preview")
    }

    func confirmAndExportDatabaseToCSV() {
        let alert = UIAlertController.make(
            title: LString.titleFileExport,
            message: LString.titlePlainTextDatabaseExport,
            dismissButtonTitle: LString.actionCancel
        )
        alert.addAction(title: LString.actionContinue, style: .default, preferred: true) { [weak self] _ in
            self?.exportDatabaseToCSV()
        }
        getPresenterForModals().present(alert, animated: true, completion: nil)
    }

    private func exportDatabaseToCSV() {
        guard let root = database.root else {
            Diag.error("Failed to export database, there is no root group")
            return
        }

        let csvFileName = databaseFile.fileURL
            .deletingPathExtension()
            .appendingPathExtension("csv")
            .lastPathComponent
        let exporter = DatabaseCSVExporter()
        let csv = exporter.export(root: root)
        fileExportHelper = FileExportHelper(data: ByteArray(utf8String: csv), fileName: csvFileName)
        fileExportHelper!.handler = { [weak self] _ in
            self?.fileExportHelper = nil
        }
        fileExportHelper!.saveAs(presenter: getPresenterForModals())
    }

    func canCopyCurrentEntryField(_ fieldName: String) -> Bool {
        guard let value = currentEntry?.getField(fieldName)?.resolvedValue else {
            return false
        }
        return value.isNotEmpty
    }

    func copyCurrentEntryField(_ fieldName: String) {
        guard let currentEntry else { return }
        guard let value = currentEntry.getField(fieldName)?.resolvedValue else {
            assertionFailure("Unexpected field name")
            return
        }
        Clipboard.general.copyWithTimeout(value)
    }

    func startSelection() {
        guard let groupViewerVC = topGroupViewer else {
            assertionFailure()
            return
        }
        groupViewerVC.select()
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
    func didPressLockDatabase(in viewController: GroupViewerVC) {
        closeDatabase(shouldLock: true, reason: .userRequest, animated: true, completion: nil)
    }

    func didPressChangeMasterKey(in viewController: GroupViewerVC) {
        showMasterKeyChanger(in: viewController)
    }

    func didPressPrintDatabase(in viewController: GroupViewerVC) {
        showDatabasePrintDialog()
    }

    func didPressReloadDatabase(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC) {
        reloadDatabase()
    }

    func didPressSettings(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC) {
        showAppSettings(at: popoverAnchor, in: viewController)
    }

    func didPressPasswordAudit(in viewController: GroupViewerVC) {
        showPasswordAudit(in: viewController)
    }

    func didPressFaviconsDownload(in viewController: GroupViewerVC) {
        downloadFavicons(in: viewController)
    }

    func didPressEncryptionSettings(in viewController: GroupViewerVC) {
        showEncryptionSettings(in: viewController)
    }

    func didPressPasswordGenerator(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC) {
        showPasswordGenerator(at: popoverAnchor, in: viewController)
    }

    func didSelectGroup(_ group: Group?, in viewController: GroupViewerVC) -> Bool {
        showGroup(group, animated: true)

        return false
    }

    func didSelectEntry(_ entry: Entry?, in viewController: GroupViewerVC) -> Bool {
        showEntry(entry)

        let shouldRemainSelected = !isSplitViewCollapsed
        return shouldRemainSelected
    }

    func didPressCreateGroup(smart: Bool, at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC) {
        showGroupEditor(.create(smart: smart), at: popoverAnchor)
    }

    func didPressCreateEntry(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC) {
        showEntryEditor(for: nil, at: popoverAnchor)
    }

    func didPressEditGroup(
        _ group: Group,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    ) {
        showGroupEditor(.modify(group: group), at: popoverAnchor)
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
        saveDatabase(databaseFile)
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
        saveDatabase(databaseFile)
    }

    func didPressRelocateItems(
        _ items: [DatabaseItem],
        mode: ItemRelocationMode,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    ) {
        showItemRelocator(for: items, mode: mode, at: popoverAnchor)
    }

    func didPressDeleteItems(_ items: [DatabaseItem], in viewController: GroupViewerVC) {
        items.compactMap({ $0 as? Entry }).forEach {
            database.delete(entry: $0)
        }
        items.compactMap({ $0 as? Group }).forEach {
            database.delete(group: $0)
        }
        items.forEach {
            $0.touch(.accessed)
        }
        hasUnsavedBulkChanges = true
    }

    func didPressEmptyRecycleBinGroup(
        _ recycleBinGroup: Group,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    ) {
        recycleBinGroup.groups.forEach {
            database.delete(group: $0)
        }
        recycleBinGroup.entries.forEach {
            database.delete(entry: $0)
        }
        recycleBinGroup.touch(.accessed)
        saveDatabase(databaseFile)
    }

    func didReorderItems(in group: Group, groups: [Group], entries: [Entry]) {
        let areGroupsReordered = !group.groups.elementsEqual(groups, by: { $0.uuid == $1.uuid })
        let areEntriesReordered = !group.entries.elementsEqual(entries, by: { $0.uuid == $1.uuid })
        guard areGroupsReordered || areEntriesReordered else {
            return
        }
        group.touch(.modified)
        group.groups = groups
        group.entries = entries
        hasUnsavedBulkChanges = true
    }

    func didFinishBulkUpdates(in viewController: GroupViewerVC) {
        guard hasUnsavedBulkChanges else {
            return
        }
        saveDatabase(databaseFile) { [weak self] in
            guard let self else { return }
            hasUnsavedBulkChanges = false
            refresh()
        }
    }

    func didPressFaviconsDownload(
        _ entries: [Entry],
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    ) {
        downloadFavicons(for: entries, in: viewController)
    }

    func shouldProvidePermissions(for item: DatabaseItem, in viewController: GroupViewerVC)
        -> DatabaseViewerPermissionManager.Permissions
    {
        return DatabaseViewerPermissionManager.getPermissions(for: item, in: databaseFile)
    }
}

extension DatabaseViewerCoordinator: ProgressViewHost {
    public func showProgressView(title: String, allowCancelling: Bool, animated: Bool) {
        if progressOverlay != nil {
            progressOverlay?.title = title
            progressOverlay?.isCancellable = allowCancelling
            return
        }
        progressOverlay = ProgressOverlay.addTo(
            splitViewController.view,
            title: title,
            animated: animated)
        progressOverlay?.isCancellable = allowCancelling
        progressOverlay?.unresponsiveCancelHandler = { [weak self] in
            self?.showDiagnostics()
        }
    }

    public func updateProgressView(with progress: ProgressEx) {
        assert(progressOverlay != nil)
        progressOverlay?.update(with: progress)
    }

    public func hideProgressView(animated: Bool) {
        progressOverlay?.dismiss(animated: animated) { [weak self] _ in
            guard let self = self else { return }
            self.progressOverlay?.removeFromSuperview()
            self.progressOverlay = nil
        }
    }
}

extension DatabaseViewerCoordinator: DatabaseSaving {
    func canCancelSaving(databaseFile: DatabaseFile) -> Bool {
        return false
    }

    func didCancelSaving(databaseFile: DatabaseFile) {
        refresh()
    }

    func didSave(databaseFile: DatabaseFile) {
        refresh()
    }

    func didFailSaving(databaseFile: DatabaseFile) {
        refresh()
    }

    func didRelocate(databaseFile: DatabaseFile, to newURL: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: newURL)
    }

    func getDatabaseSavingErrorParent() -> UIViewController {
        getPresenterForModals()
    }

    func getDiagnosticsHandler() -> (() -> Void)? {
        return showDiagnostics
    }
}

extension DatabaseViewerCoordinator: EntryViewerCoordinatorDelegate {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryViewerCoordinator) {
        refresh()
    }

    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: url)
    }

    func didPressOpenLinkedDatabase(_ info: LinkedDatabaseInfo, in coordinator: EntryViewerCoordinator) {
        delegate?.didPressSwitchTo(
            databaseRef: info.databaseRef,
            compositeKey: info.compositeKey,
            in: self
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
        if isSplitViewCollapsed {
            let isNewEntry = coordinator.isCreating
            if isNewEntry {
                Settings.current.entryViewerPage = 0
                selectEntry(entry) 
            } else {
                focusOnEntry(entry) 
            }
        } else {
            selectEntry(entry)
        }
        StoreReviewSuggester.maybeShowAppReview(appVersion: AppInfo.version, occasion: .didEditItem)
    }
}

extension DatabaseViewerCoordinator: ItemRelocationCoordinatorDelegate {
    func didRelocateItems(in coordinator: ItemRelocationCoordinator) {
        getPresenterForModals().showSuccessNotification(
            LString.actionDone,
            icon: .arrowshapeTurnUpForward
        )
        refresh()
    }
}

extension DatabaseViewerCoordinator: DatabaseKeyChangerCoordinatorDelegate {
    func didChangeDatabaseKey(in coordinator: DatabaseKeyChangerCoordinator) {
        getPresenterForModals().showNotification(LString.masterKeySuccessfullyChanged)
    }
}

extension DatabaseViewerCoordinator: PasscodeInputDelegate {
    func passcodeInputDidCancel(_ sender: PasscodeInputVC) {
        guard sender.mode == .setup else {
            return
        }
        do {
            try Keychain.shared.removeAppPasscode() 
        } catch {
            Diag.error(error.localizedDescription)
            getPresenterForModals().showErrorAlert(error, title: LString.titleKeychainError)
            return
        }
        sender.dismiss(animated: true, completion: nil)
        refresh()
    }

    func passcodeInput(_sender: PasscodeInputVC, canAcceptPasscode passcode: String) -> Bool {
        return passcode.count > 0
    }

    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode passcode: String) {
        sender.dismiss(animated: true) { [weak self] in
            do {
                let keychain = Keychain.shared
                try keychain.setAppPasscode(passcode)
                keychain.prepareBiometricAuth(true)
                Settings.current.isBiometricAppLockEnabled = true
                self?.refresh()
            } catch {
                Diag.error(error.localizedDescription)
                self?.getPresenterForModals()
                    .showErrorAlert(error, title: LString.titleKeychainError)
            }
        }
    }
}

extension DatabaseViewerCoordinator: UISplitViewControllerDelegate {
    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController
    ) -> Bool {
        if secondaryViewController === placeholderRouter.navigationController {
            return true 
        }
        return false
    }

    func splitViewController(
        _ splitViewController: UISplitViewController,
        separateSecondaryFrom primaryViewController: UIViewController
    ) -> UIViewController? {
        if let entryViewerRouter = entryViewerRouter {
            return entryViewerRouter.navigationController
        }
        return placeholderRouter.navigationController
    }

    func primaryViewController(forExpanding splitViewController: UISplitViewController) -> UIViewController? {
        return primaryRouter.navigationController
    }
    func primaryViewController(forCollapsing splitViewController: UISplitViewController) -> UIViewController? {
        return primaryRouter.navigationController
    }
}

extension DatabaseViewerCoordinator {

    private func updateAnnouncements() {
        guard let rootGroupViewer = rootGroupViewer else {
            assertionFailure()
            return
        }

        announcements.removeAll()
        if let appLockSetupAnnouncement = maybeMakeAppLockSetupAnnouncement(for: rootGroupViewer) {
            announcements.append(appLockSetupAnnouncement)
        }

        let status = databaseFile.status
        if status.contains(.localFallback) {
            announcements.append(makeFallbackDatabaseAnnouncement(for: rootGroupViewer))
        } else {
            if status.contains(.readOnly) {
                announcements.append(makeReadOnlyDatabaseAnnouncement(for: rootGroupViewer))
            }
        }

        if announcements.isEmpty, 
           let donationAnnouncement = maybeMakeDonationAnnouncement(for: rootGroupViewer) {
            announcements.append(donationAnnouncement)
        }
        rootGroupViewer.announcements = announcements
    }

    private func shouldOfferAppLockSetup() -> Bool {
        let settings = Settings.current
        if settings.isHideAppLockSetupReminder {
            return false
        }
        let isDataVulnerable = settings.isRememberDatabaseKey && !settings.isAppLockEnabled
        return isDataVulnerable
    }

    private func maybeMakeAppLockSetupAnnouncement(
        for viewController: GroupViewerVC
    ) -> AnnouncementItem? {
        guard  shouldOfferAppLockSetup() else {
            return nil
        }
        let announcement = AnnouncementItem(
            title: LString.titleAppProtection,
            body: LString.appProtectionDescription,
            actionTitle: LString.callToActionActivateAppProtection,
            image: .symbol(.appProtection),
            onDidPressAction: { [weak self] _ in
                self?.startAppProtectionSetup()
            },
            onDidPressClose: { [weak self] _ in
                Settings.current.isHideAppLockSetupReminder = true
                self?.updateAnnouncements()
            }
        )
        return announcement
    }

    private func makeFallbackDatabaseAnnouncement(
        for viewController: GroupViewerVC
    ) -> AnnouncementItem {
        let actionTitle: String?
        switch originalRef.error {
        case .authorizationRequired(_, let recoveryAction):
            actionTitle = recoveryAction
        default:
            actionTitle = nil
        }
        return AnnouncementItem(
            title: LString.databaseIsFallbackCopy,
            body: originalRef.error?.errorDescription,
            actionTitle: actionTitle,
            image: .symbol(.iCloudSlash),
            onDidPressAction: { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.didPressReinstateDatabase(originalRef, in: self)
                self.updateAnnouncements()
            }
        )
    }

    private func makeReadOnlyDatabaseAnnouncement(
        for viewController: GroupViewerVC
    ) -> AnnouncementItem {
        return AnnouncementItem(
            title: nil,
            body: LString.databaseIsReadOnly,
            actionTitle: nil,
            image: nil
        )
    }

    private func maybeMakeDonationAnnouncement(
        for viewController: GroupViewerVC
    ) -> AnnouncementItem? {
        let premiumStatus = PremiumManager.shared.status
        guard TipBox.shouldSuggestDonation(status: premiumStatus) else {
            return nil
        }

        let announcement = AnnouncementItem(
            title: nil,
            body: LString.tipBoxDescription2,
            actionTitle: LString.tipBoxCallToAction2,
            image: .symbol(.heart)?.withTintColor(.systemRed, renderingMode: .alwaysOriginal),
            onDidPressAction: { [weak self] _ in
                self?.showTipBox()
                self?.updateAnnouncements()
            },
            onDidPressClose: { [weak self] _ in
                TipBox.registerTipBoxSeen()
                self?.updateAnnouncements()
            }
        )
        return announcement
    }
}

extension DatabaseViewerCoordinator {
    func showTipBox() {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let tipBoxCoordinator = TipBoxCoordinator(router: modalRouter)
        tipBoxCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        tipBoxCoordinator.start()
        addChildCoordinator(tipBoxCoordinator)
        getPresenterForModals().present(modalRouter, animated: true, completion: nil)
    }
}

extension DatabaseViewerCoordinator: PasswordAuditCoordinatorDelegate {
    func didPressEditEntry(
        _ entry: KeePassiumLib.Entry,
        at popoverAnchor: PopoverAnchor,
        onDismiss: @escaping () -> Void
    ) {
        showEntryEditor(for: entry, at: popoverAnchor, onDismiss: onDismiss)
    }
}

extension DatabaseViewerCoordinator: EncryptionSettingsCoordinatorDelegate { }

extension DatabaseViewerCoordinator: FaviconDownloading {
    var faviconDownloadingProgressHost: ProgressViewHost? { return self }
}

extension DatabaseViewerCoordinator {
    private func maybeCheckDatabaseForExternalChanges() {
        let dbRef = originalRef
        guard let groupViewerVC = topGroupViewer else {
            return
        }

        let behavior = DatabaseSettingsManager.shared.getExternalUpdateBehavior(dbRef)
        switch behavior {
        case .dontCheck:
            return
        case .checkAndNotify, .checkAndReload:
            break
        }

        let currentHash: FileInfo.ContentHash?
        if let fileInfo = dbRef.getCachedInfoSync(canFetch: false) {
            currentHash = fileInfo.hash
            guard currentHash != nil else {
                Diag.debug("File provider does not support content hash, skipping")
                return
            }
        } else {
            Diag.info("Current content hash unknown, but should be. Checking again")
            currentHash = nil
        }

        groupViewerVC.databaseChangesCheckStatus = .inProgress
        let timeoutDuration = DatabaseSettingsManager.shared.getFallbackTimeout(dbRef, forAutoFill: false)
        FileDataProvider.readFileInfo(
            dbRef,
            canUseCache: false,
            timeout: Timeout(duration: timeoutDuration),
            completionQueue: .main
        ) { [weak self, weak groupViewerVC] result in
            guard let self, let groupViewerVC else {
                return
            }
            switch result {
            case let .success(info):
                guard let newHash = info.hash else {
                    groupViewerVC.databaseChangesCheckStatus = .idle
                    return
                }
                if newHash != currentHash {
                    processDatabaseChange(behavior: behavior, viewController: groupViewerVC)
                } else {
                    Diag.info("Database is up to date")
                    groupViewerVC.databaseChangesCheckStatus = .upToDate
                }
            case let .failure(error):
                Diag.error("Reading database file info failed [message: \(error.localizedDescription)]")
                groupViewerVC.databaseChangesCheckStatus = .failed
            }
        }
    }

    private func processDatabaseChange(behavior: ExternalUpdateBehavior, viewController: GroupViewerVC) {
        viewController.databaseChangesCheckStatus = .idle
        switch behavior {
        case .dontCheck:
            assertionFailure("Should not happen")
        case .checkAndNotify:
            Diag.info("Database changed elsewhere, suggesting reload")
            let toastHost = getPresenterForModals()
            let action = ToastAction(title: LString.actionReloadDatabase) { [weak self] in
                guard let self else { return }
                toastHost.hideAllToasts()
                delegate?.didPressReloadDatabase(databaseFile, originalRef: originalRef, in: self)
            }
            toastHost.showNotification(
                LString.databaseChangedExternallyMessage,
                title: nil,
                action: action
            )
        case .checkAndReload:
            Diag.info("Database changed elsewhere, reloading automatically")
            delegate?.didPressReloadDatabase(databaseFile, originalRef: originalRef, in: self)
        }
    }
}

final class DatabaseViewerActionsManager: UIResponder {
    private weak var coordinator: DatabaseViewerCoordinator?

    init(coordinator: DatabaseViewerCoordinator? = nil) {
        self.coordinator = coordinator
    }

    override func buildMenu(with builder: any UIMenuBuilder) {
        builder.insertChild(makeReloadDatabaseMenu(), atEndOfMenu: .databaseFile)
        builder.insertChild(makeDatabaseToolsMenu2(), atEndOfMenu: .databaseFile)
        builder.insertChild(makeLockDatabaseMenu(), atEndOfMenu: .databaseFile)
        builder.insertChild(makeExportDatabaseMenu(), atEndOfMenu: .databaseFile)
        builder.insertSibling(makeDatabaseToolsMenu1(), afterMenu: .passwordGenerator)
        if coordinator != nil {
            builder.insertChild(makeDatabaseItemsSortOrderMenu(), atEndOfMenu: .view)
            builder.insertSibling(makeEntrySubtitleMenu(), afterMenu: .itemsSortOrder)
        }
        builder.insertChild(makeCreateMenu(), atEndOfMenu: .edit)
        builder.insertChild(makeEditGroupMenu(), atEndOfMenu: .edit)
        builder.insertChild(makeCopyEntryFieldMenu(), atEndOfMenu: .edit)
        builder.insertChild(makeSelectMenu(), atEndOfMenu: .edit)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard let coordinator else {
            return false
        }

        let permissions = coordinator.currentGroupPermissions
        switch action {
        case #selector(kpmReloadDatabase),
             #selector(kpmLockDatabase),
             #selector(kpmExportDatabaseToCSV):
            return true
        case #selector(kpmShowPasswordAudit):
            return permissions.contains(.auditPasswords)
        case #selector(kpmDownloadFavicons):
            return permissions.contains(.downloadFavicons)
        case #selector(kpmPrintDatabase):
            return permissions.contains(.printDatabase)
        case #selector(kpmChangeMasterKey):
            return permissions.contains(.changeMasterKey)
        case #selector(kpmShowEncryptionSettings):
            return permissions.contains(.changeEncryptionSettings)
        case #selector(kpmCreateEntry):
            return permissions.contains(.createEntry)
        case #selector(kpmCreateGroup):
            return permissions.contains(.createGroup)
        case #selector(kpmCreateSmartGroup):
            return permissions.contains(.createGroup)
        case #selector(kpmEditGroup):
            return permissions.contains(.editItem)
        case #selector(kpmSelect):
            return permissions.contains(.selectItems)
        case #selector(kpmCopyEntryUserName):
            return coordinator.canCopyCurrentEntryField(EntryField.userName)
        case #selector(kpmCopyEntryPassword):
            return coordinator.canCopyCurrentEntryField(EntryField.password)
        case #selector(kpmCopyEntryURL):
            return coordinator.canCopyCurrentEntryField(EntryField.url)
        default:
            return false
        }
    }

    private func makeLockDatabaseMenu() -> UIMenu {
        let lockDatabaseCommand = UIKeyCommand(
            title: LString.actionLockDatabase,
            action: #selector(kpmLockDatabase),
            hotkey: .lockDatabase
        )
        return UIMenu(identifier: .lockDatabase, options: [.displayInline], children: [lockDatabaseCommand])
    }

    private func makeExportDatabaseMenu() -> UIMenu {
        let exportDatabaseCSVCommand = UICommand(
            title: "CSV",
            action: #selector(kpmExportDatabaseToCSV)
        )
        return UIMenu(
            title: LString.actionExport,
            identifier: .exportDatabase,
            children: [exportDatabaseCSVCommand])
    }

    private func makeReloadDatabaseMenu() -> UIMenu {
        let reloadDatabaseCommand = UIKeyCommand(
            title: LString.actionReloadDatabase,
            action: #selector(kpmReloadDatabase),
            hotkey: .reloadDatabase
        )
        return UIMenu(identifier: .reloadDatabase, options: [.displayInline], children: [reloadDatabaseCommand])
    }

    private func makeDatabaseItemsSortOrderMenu() -> UIMenu {
        let canReorder = coordinator?.currentGroupPermissions.contains(.reorderItems) ?? false
        let reorderItemsAction = UIAction(
            title: LString.actionReorderItems,
            image: .symbol(.arrowUpArrowDown),
            attributes: canReorder ? [] : [.disabled],
            handler: { [weak self] _ in
                self?.coordinator?.reorder()
            }
        )
        let children = UIMenu.makeDatabaseItemSortMenuItems(
            current: Settings.current.groupSortOrder,
            reorderAction: reorderItemsAction,
            handler: { [weak self] newSortOrder in
                Settings.current.groupSortOrder = newSortOrder
                self?.coordinator?.refresh()
            }
        )
        return UIMenu(
            title: LString.titleSortItemsBy,
            identifier: .itemsSortOrder,
            options: .singleSelection,
            children: children)
    }

    private func makeEntrySubtitleMenu() -> UIMenu {
        let children = Settings.EntryListDetail.allValues.map { entryListDetail in
            let isCurrent = Settings.current.entryListDetail == entryListDetail
            return UIAction(
                title: entryListDetail.title,
                state: isCurrent ? .on : .off,
                handler: { [weak self] _ in
                    Settings.current.entryListDetail = entryListDetail
                    self?.coordinator?.refresh()
                    UIMenu.rebuildMainMenu()
                }
            )
        }
        return UIMenu(
            title: LString.titleEntrySubtitle,
            options: .singleSelection,
            children: children
        )
    }

    private func makeDatabaseToolsMenu1() -> UIMenu {
        let passwordAuditAction = UIKeyCommand(
            title: LString.titlePasswordAudit,
            action: #selector(kpmShowPasswordAudit),
            hotkey: .passwordAudit)
        let downloadFaviconsAction = UICommand(
            title: LString.actionDownloadFavicons,
            action: #selector(kpmDownloadFavicons))
        return UIMenu(inlineChildren: [
            passwordAuditAction,
            downloadFaviconsAction,
        ])
    }

    private func makeDatabaseToolsMenu2() -> UIMenu {
        let changeMasterKeyAction = UICommand(
            title: LString.actionChangeMasterKey,
            action: #selector(kpmChangeMasterKey))
        let encryptionSettingsAction = UIKeyCommand(
            title: LString.titleEncryptionSettings,
            action: #selector(kpmShowEncryptionSettings),
            hotkey: .encryptionSettings)
        let printAction = UIKeyCommand(
            title: LString.actionPrint,
            action: #selector(kpmPrintDatabase),
            hotkey: .printDatabase)
        return UIMenu(inlineChildren: [
            changeMasterKeyAction,
            encryptionSettingsAction,
            printAction
        ])
    }

    private func makeCreateMenu() -> UIMenu {
        let createEntryMenuItem = UIKeyCommand(
            title: LString.titleNewEntry,
            action: #selector(kpmCreateEntry),
            hotkey: .createEntry)
        let createGroupMenuItem = UIKeyCommand(
            title: LString.titleNewGroup,
            action: #selector(kpmCreateGroup),
            hotkey: .createGroup)
        let createSmartGroupMenuItem = UICommand(
            title: LString.titleNewSmartGroup,
            action: #selector(kpmCreateSmartGroup))
        return UIMenu(inlineChildren: [
            createEntryMenuItem,
            createGroupMenuItem, createSmartGroupMenuItem
        ])
    }

    private func makeEditGroupMenu() -> UIMenu {
        let editGroupMenuItem = UICommand(
            title: LString.titleEditGroup,
            action: #selector(kpmEditGroup))
        return UIMenu(inlineChildren: [editGroupMenuItem])
    }

    private func makeCopyEntryFieldMenu() -> UIMenu {
        let copyUserNameAction = UIKeyCommand(
            title: String.localizedStringWithFormat(
                LString.actionCopyToClipboardTemplate,
                LString.fieldUserName),
            action: #selector(kpmCopyEntryUserName),
            hotkey: .copyUserName)
        let copyPasswordAction = UIKeyCommand(
            title: String.localizedStringWithFormat(
                LString.actionCopyToClipboardTemplate,
                LString.fieldPassword),
            action: #selector(kpmCopyEntryPassword),
            hotkey: .copyPassword)
        let copyURLAction = UIKeyCommand(
            title: String.localizedStringWithFormat(
                LString.actionCopyToClipboardTemplate,
                LString.fieldURL),
            action: #selector(kpmCopyEntryURL),
            hotkey: .copyURL)
        return UIMenu(inlineChildren: [copyUserNameAction, copyPasswordAction, copyURLAction])
    }

    private func makeSelectMenu() -> UIMenu {
        let selectAction = UICommand(
            title: LString.actionSelect,
            action: #selector(kpmSelect))
        return UIMenu(inlineChildren: [selectAction])
    }

    @objc func kpmReloadDatabase() {
        coordinator?.reloadDatabase()
    }
    @objc func kpmLockDatabase() {
        coordinator?.closeDatabase(shouldLock: true, reason: .userRequest, animated: true, completion: nil)
    }
    @objc func kpmExportDatabaseToCSV() {
        coordinator?.confirmAndExportDatabaseToCSV()
    }
    @objc func kpmShowPasswordAudit() {
        coordinator?.showPasswordAudit()
    }
    @objc func kpmDownloadFavicons() {
        coordinator?.downloadFavicons()
    }
    @objc func kpmPrintDatabase() {
        coordinator?.showDatabasePrintDialog()
    }
    @objc func kpmChangeMasterKey() {
        coordinator?.showMasterKeyChanger()
    }
    @objc func kpmShowEncryptionSettings() {
        coordinator?.showEncryptionSettings()
    }
    @objc func kpmCreateEntry() {
        coordinator?.showEntryEditor()
    }
    @objc func kpmCreateSmartGroup() {
        coordinator?.showGroupEditor(.create(smart: true))
    }
    @objc func kpmCreateGroup() {
        coordinator?.showGroupEditor(.create(smart: false))
    }
    @objc func kpmEditGroup() {
        guard let currentGroup = coordinator?.currentGroup else {
            return
        }
        coordinator?.showGroupEditor(.modify(group: currentGroup))
    }
    @objc func kpmSelect() {
        coordinator?.startSelection()
    }
    @objc func kpmCopyEntryUserName() {
        coordinator?.copyCurrentEntryField(EntryField.userName)
    }
    @objc func kpmCopyEntryPassword() {
        coordinator?.copyCurrentEntryField(EntryField.password)
    }
    @objc func kpmCopyEntryURL() {
        coordinator?.copyCurrentEntryField(EntryField.url)
    }
}
