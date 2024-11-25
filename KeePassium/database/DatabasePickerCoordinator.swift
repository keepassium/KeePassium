//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabasePickerCoordinatorDelegate: AnyObject {
    func shouldAcceptDatabaseSelection(
        _ fileRef: URLReference,
        in coordinator: DatabasePickerCoordinator) -> Bool

    func didSelectDatabase(_ fileRef: URLReference?, in coordinator: DatabasePickerCoordinator)

    func shouldKeepSelection(in coordinator: DatabasePickerCoordinator) -> Bool
}

public enum DatabasePickerMode {
    case full
    case autoFill
    case light
}

final class DatabasePickerCoordinator: UIResponder, Coordinator, Refreshable {
    var childCoordinators = [Coordinator]()

    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: DatabasePickerCoordinatorDelegate?
    private(set) var selectedDatabase: URLReference?
    var shouldSelectDefaultDatabase = false

    private let router: NavigationRouter
    private let databasePickerVC: DatabasePickerVC
    private let mode: DatabasePickerMode

    private var fileKeeperNotifications: FileKeeperNotifications!

    init(router: NavigationRouter, mode: DatabasePickerMode) {
        self.router = router
        self.mode = mode
        databasePickerVC = DatabasePickerVC.instantiateFromStoryboard()
        databasePickerVC.mode = mode
        super.init()

        databasePickerVC.delegate = self
        fileKeeperNotifications = FileKeeperNotifications(observer: self)
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()

        fileKeeperNotifications.stopObserving()
    }

    func start() {
        router.push(databasePickerVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        fileKeeperNotifications.startObserving()
    }

    func refresh() {
        databasePickerVC.refresh()
    }


    public func setEnabled(_ enabled: Bool) {
        databasePickerVC.isEnabled = enabled
    }

    public func selectDatabase(_ fileRef: URLReference?, animated: Bool) {
        selectedDatabase = fileRef
        switch mode {
        case .full, .autoFill:
            Settings.current.startupDatabase = fileRef
        case .light:
            break
        }
        databasePickerVC.selectDatabase(fileRef, animated: animated)
        delegate?.didSelectDatabase(fileRef, in: self)
    }

    #if MAIN_APP
    func showAboutScreen(
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        let modalRouter = NavigationRouter.createModal(
            style: ProcessInfo.isRunningOnMac ? .formSheet : .popover,
            at: popoverAnchor)
        let aboutCoordinator = AboutCoordinator(router: modalRouter)
        aboutCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        aboutCoordinator.start()
        addChildCoordinator(aboutCoordinator)
        viewController.present(modalRouter, animated: true, completion: nil)
    }

    func showAppSettings(
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        let modalRouter = NavigationRouter.createModal(
            style: ProcessInfo.isRunningOnMac ? .formSheet : .popover,
            at: popoverAnchor)
        let settingsCoordinator = SettingsCoordinator(router: modalRouter)
        settingsCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        settingsCoordinator.start()
        addChildCoordinator(settingsCoordinator)
        viewController.present(modalRouter, animated: true, completion: nil)
    }
    #endif

    private func showDiagnostics(in viewController: UIViewController) {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: modalRouter)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        diagnosticsViewerCoordinator.start()

        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(diagnosticsViewerCoordinator)
    }

    private func hasValidDatabases() -> Bool {
        let accessibleDatabaseRefs = FileKeeper.shared
            .getAllReferences(fileType: .database, includeBackup: false)
            .filter { !$0.needsReinstatement } 
        return accessibleDatabaseRefs.count > 0
    }

    public func maybeAddExternalDatabase(presenter: UIViewController) {
        guard needsPremiumToAddDatabase() else {
            addExternalDatabase(presenter: presenter)
            return
        }

        performPremiumActionOrOfferUpgrade(for: .canUseMultipleDatabases, in: presenter) {
            [weak self, weak presenter] in 
            guard let self = self,
                  let presenter = presenter
            else {
                return
            }
            self.addExternalDatabase(presenter: presenter)
        }
    }

    public func addExternalDatabase(_ ref: URLReference? = nil, presenter: UIViewController) {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: FileType.databaseUTIs
        )
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .pageSheet
        documentPicker.directoryURL = ref?.url?.deletingLastPathComponent()
        presenter.present(documentPicker, animated: true, completion: nil)
    }

    public func maybeAddRemoteDatabase(bypassPaywall: Bool, presenter: UIViewController) {
        guard needsPremiumToAddDatabase() && !bypassPaywall else {
            presenter.ensuringNetworkAccessPermitted { [weak self, weak presenter] in
                guard let self = self, let presenter = presenter else { return }
                self.addRemoteDatabase(presenter: presenter)
            }
            return
        }

        performPremiumActionOrOfferUpgrade(for: .canUseMultipleDatabases, in: presenter) {
            [weak self, weak presenter] in
            guard let self = self,
                  let presenter = presenter
            else {
                return
            }
            presenter.ensuringNetworkAccessPermitted { [weak self, weak presenter] in
                guard let self = self, let presenter = presenter else { return }
                self.addRemoteDatabase(presenter: presenter)
            }
        }
    }

    public func addRemoteDatabase(_ oldRef: URLReference? = nil, presenter: UIViewController) {
        guard Settings.current.isNetworkAccessAllowed else {
            Diag.error("Network access denied")
            presenter.showErrorAlert(FileAccessError.networkAccessDenied)
            return
        }
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let connectionCreatorCoordinator = RemoteFilePickerCoordinator(
            oldRef: oldRef,
            router: modalRouter
        )
        connectionCreatorCoordinator.delegate = self
        connectionCreatorCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        connectionCreatorCoordinator.start()

        presenter.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(connectionCreatorCoordinator)
    }

    private func addDatabaseFile(_ url: URL, mode: FileKeeper.OpenMode) {
        FileKeeper.shared.addFile(url: url, fileType: .database, mode: .openInPlace) { [weak self] result in
            switch result {
            case .success(let fileRef):
                self?.refresh()
                self?.selectDatabase(fileRef, animated: true)
            case .failure(let fileKeeperError):
                Diag.error("Failed to import database [message: \(fileKeeperError.localizedDescription)]")
                self?.refresh()
            }
        }
    }

    #if MAIN_APP
    public func maybeCreateDatabase(presenter: UIViewController) {
        guard needsPremiumToAddDatabase() else {
            createDatabase(presenter: presenter)
            return
        }

        performPremiumActionOrOfferUpgrade(for: .canUseMultipleDatabases, in: presenter) {
            [weak self, weak presenter] in
            guard let self = self,
                  let presenter = presenter
            else {
                return
            }
            self.createDatabase(presenter: presenter)
        }
    }

    public func createDatabase(presenter: UIViewController) {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let databaseCreatorCoordinator = DatabaseCreatorCoordinator(router: modalRouter)
        databaseCreatorCoordinator.delegate = self
        databaseCreatorCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        databaseCreatorCoordinator.start()

        presenter.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(databaseCreatorCoordinator)
    }
    #endif

    private func showFileInfo(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let fileInfoCoordinator = FileInfoCoordinator(
            fileRef: fileRef,
            fileType: .database,
            allowExport: true,
            router: modalRouter)
        fileInfoCoordinator.delegate = self
        fileInfoCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        fileInfoCoordinator.start()
        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(fileInfoCoordinator)
    }

    private func showDatabaseSettings(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC
    ) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let databaseSettingsCoordinator = DatabaseSettingsCoordinator(
            fileRef: fileRef,
            router: modalRouter
        )
        databaseSettingsCoordinator.delegate = self
        databaseSettingsCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        databaseSettingsCoordinator.start()

        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(databaseSettingsCoordinator)
    }
}

extension DatabasePickerCoordinator: DatabasePickerDelegate {

    func getDefaultDatabase(
        from databases: [URLReference],
        in viewController: DatabasePickerVC
    ) -> URLReference? {
        switch mode {
        case .light:
            return nil
        case .full, .autoFill:
            break
        }

        defer {
            shouldSelectDefaultDatabase = false
        }
        guard shouldSelectDefaultDatabase,
              Settings.current.isAutoUnlockStartupDatabase
        else {
            return nil
        }

        #if AUTOFILL_EXT
        if databases.count == 1,
           let defaultDatabase = databases.first {
            return defaultDatabase
        }
        #endif
        if let startupDatabase = Settings.current.startupDatabase,
           let defaultDatabase = startupDatabase.find(in: databases)
        {
            return defaultDatabase
        }
        return nil
    }

    private func needsPremiumToAddDatabase() -> Bool {
        if hasValidDatabases() {
            let isEligible = PremiumManager.shared.isAvailable(feature: .canUseMultipleDatabases)
            return !isEligible
        } else {
            return false
        }
    }

    func needsPremiumToAddDatabase(in viewController: DatabasePickerVC) -> Bool {
        return needsPremiumToAddDatabase()
    }

    #if MAIN_APP
    func didPressHelp(at popoverAnchor: PopoverAnchor, in viewController: DatabasePickerVC) {
        showAboutScreen(at: popoverAnchor, in: viewController)
    }

    func didPressSettings(at popoverAnchor: PopoverAnchor, in viewController: DatabasePickerVC) {
        showAppSettings(at: popoverAnchor, in: viewController)
    }

    func didPressCreateDatabase(in viewController: DatabasePickerVC) {
        maybeCreateDatabase(presenter: viewController)
    }
    #endif

    func didPressPasswordGenerator(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC
    ) {
        showPasswordGenerator(at: popoverAnchor, in: viewController)
    }

    func didPressCancel(in viewController: DatabasePickerVC) {
        router.pop(viewController: databasePickerVC, animated: true)
    }

    func didPressShowDiagnostics(in viewController: DatabasePickerVC) {
        showDiagnostics(in: viewController)
    }

    func didPressAddExistingDatabase(in viewController: DatabasePickerVC) {
        maybeAddExternalDatabase(presenter: viewController)
    }

    func didPressAddRemoteDatabase(in viewController: DatabasePickerVC) {
        maybeAddRemoteDatabase(bypassPaywall: false, presenter: viewController)
    }

    func didPressRevealDatabaseInFinder(
        _ fileRef: URLReference,
        in viewController: DatabasePickerVC
    ) {
        FileExportHelper.revealInFinder(fileRef)
    }

    func didPressExportDatabase(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC
    ) {
        FileExportHelper.showFileExportSheet(fileRef, at: popoverAnchor, parent: viewController)
    }

    func didPressEliminateDatabase(
        _ fileRef: URLReference,
        shouldConfirm: Bool,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC
    ) {
        FileDestructionHelper.destroyFile(
            fileRef,
            fileType: .database,
            withConfirmation: shouldConfirm,
            at: popoverAnchor,
            parent: viewController,
            completion: { [weak self] isEliminated in
                guard let self = self else { return }
                if isEliminated && (fileRef === self.selectedDatabase) {
                    self.selectDatabase(nil, animated: false)
                }
                self.refresh()
            }
        )
    }

    func didPressFileInfo(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC
    ) {
        showFileInfo(fileRef, at: popoverAnchor, in: viewController)
    }

    func didPressDatabaseSettings(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC
    ) {
        showDatabaseSettings(fileRef, at: popoverAnchor, in: viewController)
    }

    func shouldKeepSelection(in viewController: DatabasePickerVC) -> Bool {
        return delegate?.shouldKeepSelection(in: self) ?? true
    }

    func shouldAcceptDatabaseSelection(
        _ fileRef: URLReference,
        in viewController: DatabasePickerVC
    ) -> Bool {
        return delegate?.shouldAcceptDatabaseSelection(fileRef, in: self) ?? true
    }

    func didSelectDatabase(_ fileRef: URLReference, in viewController: DatabasePickerVC) {
        selectDatabaseOrOfferPremiumUpgrade(fileRef, in: viewController)
    }

    private func selectDatabaseOrOfferPremiumUpgrade(
        _ fileRef: URLReference,
        in viewController: DatabasePickerVC
    ) {
        if fileRef == Settings.current.startupDatabase {
            selectDatabase(fileRef, animated: false)
            return
        }

        let validSortedDatabases = viewController.databaseRefs.filter {
            !$0.hasError && $0.location != .internalBackup
        }
        let isFirstDatabase = (fileRef === validSortedDatabases.first) || validSortedDatabases.isEmpty
        if isFirstDatabase || fileRef.location == .internalBackup {
            selectDatabase(fileRef, animated: false)
        } else {
            performPremiumActionOrOfferUpgrade(
                for: .canUseMultipleDatabases,
                allowBypass: true,
                in: viewController,
                actionHandler: { [weak self] in
                    self?.selectDatabase(fileRef, animated: false)
                }
            )
        }
    }
}

extension DatabasePickerCoordinator: UIDocumentPickerDelegate {
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let url = urls.first else { return }
        FileAddingHelper.ensureFileIsDatabase(url, parent: databasePickerVC) { [weak self] url in
            self?.addDatabaseFile(url, mode: .openInPlace)
        }
    }
}

#if MAIN_APP
extension DatabasePickerCoordinator: DatabaseCreatorCoordinatorDelegate {
    func didCreateDatabase(
        in databaseCreatorCoordinator: DatabaseCreatorCoordinator,
        database urlRef: URLReference
    ) {
        selectDatabase(urlRef, animated: true)
    }
}
#endif

extension DatabasePickerCoordinator: FileInfoCoordinatorDelegate {
    func didEliminateFile(_ fileRef: URLReference, in coordinator: FileInfoCoordinator) {
        refresh()
    }
}

extension DatabasePickerCoordinator: DatabaseSettingsCoordinatorDelegate {
    func didChangeDatabaseSettings(in coordinator: DatabaseSettingsCoordinator) {
        refresh()
    }
}

extension DatabasePickerCoordinator: FileKeeperObserver {
    func fileKeeper(didAddFile urlRef: URLReference, fileType: FileType) {
        guard fileType == .database else { return }
        refresh()
    }

    func fileKeeper(didRemoveFile urlRef: URLReference, fileType: FileType) {
        guard fileType == .database else { return }
        if urlRef === selectedDatabase {
            selectDatabase(nil, animated: false)
        }
        refresh()
    }
}

extension DatabasePickerCoordinator: RemoteFilePickerCoordinatorDelegate {
    func didPickRemoteFile(
        url: URL,
        credential: NetworkCredential,
        in coordinator: RemoteFilePickerCoordinator
    ) {
        CredentialManager.shared.store(credential: credential, for: url)
        addDatabaseFile(url, mode: .openInPlace)
    }

    func didSelectSystemFilePicker(in coordinator: RemoteFilePickerCoordinator) {
        maybeAddExternalDatabase(presenter: databasePickerVC)
    }
}

extension DatabasePickerCoordinator {
    func buildMenu(with builder: any UIMenuBuilder, isDatabaseShown: Bool) {
        if !isDatabaseShown {
            builder.insertChild(makeFileSortOrderMenu(), atEndOfMenu: .view)
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }

    private func makeFileSortOrderMenu() -> UIMenu {
        let actions = UIMenu.makeFileSortMenuItems(current: Settings.current.filesSortOrder) {
            [weak self] newSortOrder in
            Settings.current.filesSortOrder = newSortOrder
            self?.refresh()
            UIMenu.rebuildMainMenu()
        }
        return UIMenu(
            title: LString.titleSortFilesBy,
            identifier: .fileSortOrder,
            options: .singleSelection,
            children: actions
        )
    }
}
