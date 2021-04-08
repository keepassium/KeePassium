//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib


protocol AppLockSetupCellDelegate: class {
    func didPressEnableAppLock(in cell: AppLockSetupCell)
    func didPressClose(in cell: AppLockSetupCell)
}

class AppLockSetupCell: UITableViewCell {
    @IBOutlet weak var dismissButton: UIButton!

    weak var delegate: AppLockSetupCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        dismissButton.accessibilityLabel = LString.actionDismiss
    }
    
    @IBAction func didPressEnableAppLock(_ sender: Any) {
        delegate?.didPressEnableAppLock(in: self)
    }
    
    @IBAction func didPressClose(_ sender: UIButton) {
        delegate?.didPressClose(in: self)
    }
}


class ChooseDatabaseVC: TableViewControllerWithContextActions, DynamicFileList, Refreshable {
    
    private enum CellID: String {
        case fileItem = "FileItemCell"
        case noFiles = "NoFilesCell"
        case appLockSetup = "AppLockSetupCell"
    }
    @IBOutlet weak var addDatabaseBarButton: UIBarButtonItem!
    @IBOutlet weak var sortOrderButton: UIBarButtonItem!
    
    private var _isEnabled = true
    var isEnabled: Bool {
        get { return _isEnabled }
        set {
            _isEnabled = newValue
            let alpha: CGFloat = _isEnabled ? 1.0 : 0.5
            navigationController?.navigationBar.isUserInteractionEnabled = _isEnabled
            navigationController?.navigationBar.alpha = alpha
            tableView.isUserInteractionEnabled = _isEnabled
            tableView.alpha = alpha
            if let toolbarItems = toolbarItems {
                for item in toolbarItems {
                    item.isEnabled = _isEnabled
                }
            }
        }
    }
    
    private var databaseRefs: [URLReference] = []
    
    private weak var databaseUnlocker: UnlockDatabaseVC?
    
    private var fileKeeperNotifications: FileKeeperNotifications!
    private var settingsNotifications: SettingsNotifications!
    
    private let fileInfoReloader = FileInfoReloader()
    
    private let premiumUpgradeHelper = PremiumUpgradeHelper()
    
    private var isJustLaunched = true
    
    internal var ongoingUpdateAnimations = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        splitViewController?.preferredDisplayMode = .allVisible
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 44.0
        tableView.rowHeight = UITableView.automaticDimension
        
        fileKeeperNotifications = FileKeeperNotifications(observer: self)
        settingsNotifications = SettingsNotifications(observer: self)
        
        if !ProcessInfo.isRunningOnMac {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
            self.refreshControl = refreshControl
        }
        clearsSelectionOnViewWillAppear = false
        
        updateDetailView(onlyInTwoPaneMode: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let splitVC = splitViewController else { fatalError() }
        if !splitVC.isCollapsed {
            navigationItem.backBarButtonItem = UIBarButtonItem(
                title: LString.actionCloseDatabase,
                style: .plain,
                target: nil,
                action: nil
            )
        }
        databaseUnlocker = nil
        if !isJustLaunched {
            updateDetailView(onlyInTwoPaneMode: true)
        }
        isJustLaunched = false
        settingsNotifications.startObserving()
        fileKeeperNotifications.startObserving()
        processPendingFileOperations()
        refresh()
    }

    override func viewDidDisappear(_ animated: Bool) {
        fileKeeperNotifications.stopObserving()
        settingsNotifications.stopObserving()
        super.viewDidDisappear(animated)
    }
    
    func updateDetailView(onlyInTwoPaneMode: Bool) {
        refresh()

        let isTwoPaneMode = !(splitViewController?.isCollapsed ?? true)
        if onlyInTwoPaneMode && !isTwoPaneMode {
            return
        }

        if databaseRefs.isEmpty {
            databaseUnlocker = nil
            let rootNavVC = splitViewController?.viewControllers.last as? UINavigationController
            let detailNavVC = rootNavVC?.topViewController as? UINavigationController
            let topDetailVC = detailNavVC?.topViewController
            if topDetailVC is WelcomeVC {
                return
            }
            let welcomeVC = WelcomeVC.make(delegate: self)
            let wrapperNavVC = UINavigationController(rootViewController: welcomeVC)
            showDetailViewController(wrapperNavVC, sender: self)
            return
        }

        if let databaseUnlocker = databaseUnlocker {
            if !databaseRefs.contains(databaseUnlocker.databaseRef) {
                tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
                showDetailViewController(PlaceholderVC.make(), sender: self)
                return
            }
        }
        
        let canAutoSelectDatabase = isTwoPaneMode || Settings.current.isAutoUnlockStartupDatabase
        
        guard let startDatabase = Settings.current.startupDatabase,
            let selRow = databaseRefs.firstIndex(of: startDatabase),
            canAutoSelectDatabase else
        {
            tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
            return
        }

        let selectIndexPath = IndexPath(row: selRow, section: 0)
        DispatchQueue.main.async { [weak self] in
            self?.tableView.selectRow(at: selectIndexPath, animated: true, scrollPosition: .none)
            self?.didSelectDatabase(urlRef: startDatabase)
        }
    }
    

    @objc
    private func didPullToRefresh() {
        if !tableView.isDragging {
            refreshControl?.endRefreshing()
            refresh()
        }
    }
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if refreshControl?.isRefreshing ?? false {
            refreshControl?.endRefreshing()
            refresh()
        }
    }
    
    func refresh() {
        refreshSortOrderButton()
        
        databaseRefs = FileKeeper.shared.getAllReferences(
            fileType: .database,
            includeBackup: Settings.current.isBackupFilesVisible)
        sortFileList()

        fileInfoReloader.getInfo(
            for: databaseRefs,
            update: { [weak self] (ref) in
                guard let self = self else { return }
                self.sortAndAnimateFileInfoUpdate(refs: &self.databaseRefs, in: self.tableView)
            },
            completion: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + self.sortingAnimationDuration) {
                    [weak self] in
                    self?.sortFileList()
                }
            }
        )
    }
    
    fileprivate func sortFileList() {
        let fileSortOrder = Settings.current.filesSortOrder
        databaseRefs.sort { return fileSortOrder.compare($0, $1) }
        tableView.reloadData()
    }
    
    private func refreshSortOrderButton() {
        sortOrderButton.image = Settings.current.filesSortOrder.toolbarIcon
    }
    
    func getIndexPath(for fileIndex: Int) -> IndexPath {
        return IndexPath(row: fileIndex, section: 0)
    }
    
    private func shouldShowAppLockSetup() -> Bool {
        let settings = Settings.current
        if settings.isHideAppLockSetupReminder {
            return false
        }
        let isDataVulnerable = settings.isRememberDatabaseKey && !settings.isAppLockEnabled
        return isDataVulnerable
    }
    
    
    @IBAction func didPressSortButton(_ sender: Any) {
        let vc = SettingsFileSortingVC.make(popoverFromBar: sender as? UIBarButtonItem)
        present(vc, animated: true, completion: nil)
    }

    @IBAction func didPressSettingsButton(_ sender: Any) {
        let settingsVC = SettingsVC.make(popoverFromBar: sender as? UIBarButtonItem)
        present(settingsVC, animated: true, completion: nil)
    }
    
    @IBAction func didPressHelpButton(_ sender: Any) {
        tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
        let aboutVC = AboutVC.make()
        showDetailViewController(aboutVC, sender: self)
    }
    
    func didPressAppLockSetup() {
        let passcodeInputVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeInputVC.delegate = self
        passcodeInputVC.mode = .setup
        passcodeInputVC.modalPresentationStyle = .formSheet
        passcodeInputVC.isCancelAllowed = true
        present(passcodeInputVC, animated: true, completion: nil)
    }
    
    @IBAction func didPressAddDatabase(_ sender: Any) {
        let existingNonBackupDatabaseRefs = databaseRefs.filter {
            ($0.location != .internalBackup) && 
                !($0.hasPermissionError257 || $0.hasFileMissingError) 
        }
        if existingNonBackupDatabaseRefs.count > 0 {
            premiumUpgradeHelper.performActionOrOfferUpgrade(.canUseMultipleDatabases, in: self) {
                [weak self] in
                self?.handleDidPressAddDatabase()
            }
        } else {
            handleDidPressAddDatabase()
        }
    }
    
    private func handleDidPressAddDatabase() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: LString.actionOpenDatabase, style: .default) {
            [weak self] _ in
            self?.didPressOpenDatabase()
        })
        
        actionSheet.addAction(UIAlertAction(title: LString.actionCreateDatabase, style: .default) {
            [weak self] _ in
            self?.didPressCreateDatabase()
        })
        
        actionSheet.addAction(UIAlertAction(
            title: LString.actionCancel,
            style: .cancel,
            handler: nil)
        )
            
        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = addDatabaseBarButton
        }
        present(actionSheet, animated: true, completion: nil)
    }
    
    func didPressOpenDatabase() {
        let picker = UIDocumentPickerViewController(
            documentTypes: FileType.databaseUTIs,
            in: .open)
        picker.delegate = self
        picker.modalPresentationStyle = .pageSheet
        present(picker, animated: true, completion: nil)
    }
    
    var databaseCreatorCoordinator: DatabaseCreatorCoordinator?
    func didPressCreateDatabase() {
        assert(databaseCreatorCoordinator == nil)
        
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        databaseCreatorCoordinator = DatabaseCreatorCoordinator(router: modalRouter)
        databaseCreatorCoordinator!.delegate = self
        databaseCreatorCoordinator?.dismissHandler = { [weak self] coordinator in
            self?.databaseCreatorCoordinator = nil
        }
        databaseCreatorCoordinator!.start()
        present(modalRouter, animated: true, completion: nil)
    }

    func didPressExportDatabase(at indexPath: IndexPath) {
        let urlRef = databaseRefs[indexPath.row]
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        FileExportHelper.showFileExportSheet(urlRef, at: popoverAnchor, parent: self)
    }
        
    func didPressDeleteDatabase(at indexPath: IndexPath) {
        StoreReviewSuggester.registerEvent(.trouble)
        
        let urlRef = databaseRefs[indexPath.row]
        if urlRef.hasError {
            removeDatabaseFile(urlRef: urlRef)
            return
        }
        
        let message: String
        let destructiveAction: UIAlertAction
        if urlRef.location.isInternal {
            message = LString.confirmDatabaseDeletion
            destructiveAction = UIAlertAction(
                title: LString.actionDeleteFile,
                style: .destructive)
            {
                [unowned self] _ in
                
                Settings.current.startupDatabase = nil
                self.updateDetailView(onlyInTwoPaneMode: true)
                self.deleteDatabaseFile(urlRef: urlRef)
            }
        } else {
            message = LString.confirmDatabaseRemoval
            destructiveAction = UIAlertAction(title: LString.actionRemoveFile, style: .destructive)
            {
                [unowned self] _ in
                Settings.current.startupDatabase = nil
                self.updateDetailView(onlyInTwoPaneMode: true)
                self.removeDatabaseFile(urlRef: urlRef)
            }
        }
        let confirmationAlert = UIAlertController.make(
            title: urlRef.visibleFileName,
            message: message,
            dismissButtonTitle: LString.actionCancel)
        confirmationAlert.addAction(destructiveAction)
        present(confirmationAlert, animated: true, completion: nil)
    }
    
    private func didSelectDatabase(urlRef: URLReference) {
        Settings.current.startupDatabase = urlRef
        if databaseUnlocker != nil {
            databaseUnlocker?.databaseRef = urlRef
            return
        }
        let unlockDatabaseVC = UnlockDatabaseVC.make(databaseRef: urlRef)
        unlockDatabaseVC.isJustLaunched = isJustLaunched 
        showDetailViewController(unlockDatabaseVC, sender: self)
        databaseUnlocker = unlockDatabaseVC
    }


    private func deleteDatabaseFile(urlRef: URLReference) {
        if urlRef == Settings.current.startupDatabase {
            Settings.current.startupDatabase = nil
        }

        do {
            try FileKeeper.shared.deleteFile(
                urlRef,
                fileType: .database,
                ignoreErrors: urlRef.hasError)
            refresh()
        } catch {
            Diag.error("Failed to delete database file [reason: \(error.localizedDescription)]")
            showErrorAlert(error)
        }
        DatabaseSettingsManager.shared.removeSettings(for: urlRef, onlyIfUnused: true)
    }
    
    private func removeDatabaseFile(urlRef: URLReference) {
        if urlRef == Settings.current.startupDatabase {
            Settings.current.startupDatabase = nil
        }
        FileKeeper.shared.removeExternalReference(urlRef, fileType: .database)
        DatabaseSettingsManager.shared.removeSettings(for: urlRef, onlyIfUnused: true)
    }
    
    private func processPendingFileOperations() {
        FileKeeper.shared.processPendingOperations(
            success: nil,
            error: { [weak self] (error) in
                self?.showErrorAlert(error)
            }
        )
    }
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func numberOfRows() -> Int {
        let contentCellCount = max(databaseRefs.count, 1)
        if shouldShowAppLockSetup() {
            return contentCellCount + 1
        } else {
            return contentCellCount
        }
    }
    
    private func getCellType(for indexPath: IndexPath) -> CellID {
        if indexPath.row < databaseRefs.count {
            return .fileItem
        }
        if shouldShowAppLockSetup() && indexPath.row == (numberOfRows() - 1) {
            return .appLockSetup
        }
        return .noFiles
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfRows()
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        let cellType = getCellType(for: indexPath)
        switch cellType {
        case .noFiles:
            let cell = tableView
                .dequeueReusableCell(withIdentifier: cellType.rawValue, for: indexPath)
            return cell
        case .fileItem:
            let cell = FileListCellFactory.dequeueReusableCell(
                from: tableView,
                withIdentifier: cellType.rawValue,
                for: indexPath,
                for: .database)
            let dbRef = databaseRefs[indexPath.row]
            cell.showInfo(from: dbRef)
            cell.isAnimating = dbRef.isRefreshingInfo
            cell.accessoryTapHandler = { [weak self, indexPath] cell in
                guard let self = self else { return }
                self.tableView(self.tableView, accessoryButtonTappedForRowWith: indexPath)
            }
            return cell
        case .appLockSetup:
            let cell = tableView
                .dequeueReusableCell(withIdentifier: cellType.rawValue, for: indexPath)
                as! AppLockSetupCell
            cell.delegate = self
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if splitViewController?.isCollapsed ?? false {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        switch getCellType(for: indexPath) {
        case .noFiles:
            break
        case .fileItem:
            let selectedRef = databaseRefs[indexPath.row]
            didSelectDatabase(urlRef: selectedRef)
        case .appLockSetup:
            break
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        accessoryButtonTappedForRowWith indexPath: IndexPath)
    {
        let cellType = getCellType(for: indexPath)
        guard cellType == .fileItem else {
            assertionFailure()
            return
        }
        let urlRef = databaseRefs[indexPath.row]
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        let databaseInfoVC = FileInfoVC.make(urlRef: urlRef, fileType: .database, at: popoverAnchor)
        databaseInfoVC.canExport = true
        databaseInfoVC.didDeleteCallback = { [weak self, weak databaseInfoVC] in
            self?.refresh()
            databaseInfoVC?.dismiss(animated: true, completion: nil)
        }
        present(databaseInfoVC, animated: true, completion: nil)
    }
    
       
    override func getContextActionsForRow(
        at indexPath: IndexPath,
        forSwipe: Bool
    ) -> [ContextualAction] {
        let cellType = getCellType(for: indexPath)
        let isEditableRow = cellType == .fileItem
        guard isEditableRow else { return [] }

        let urlRef = databaseRefs[indexPath.row]
        let exportAction = ContextualAction(
            title: LString.actionExport,
            imageName: .squareAndArrowUp,
            style: .default,
            color: UIColor.actionTint,
            handler: { [weak self, indexPath] in
                self?.didPressExportDatabase(at: indexPath)
            }
        )
        
        let destructiveActionTitle = DestructiveFileAction.get(for: urlRef.location).title
        let destructiveAction = ContextualAction(
            title: destructiveActionTitle,
            imageName: .trash,
            style: .destructive,
            color: UIColor.destructiveTint,
            handler: { [weak self, indexPath] in
                self?.didPressDeleteDatabase(at: indexPath)
            }
        )
        
        return [exportAction, destructiveAction]
    }
}

extension ChooseDatabaseVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        switch key {
        case .filesSortOrder, .backupFilesVisible:
            refresh()
        case .appLockEnabled, .rememberDatabaseKey:
            tableView.reloadSections([0], with: .automatic)
        default:
            break
        }
    }
}

extension ChooseDatabaseVC: FileKeeperObserver {
    func fileKeeper(didAddFile urlRef: URLReference, fileType: FileType) {
        guard fileType == .database else { return }
        Settings.current.startupDatabase = urlRef
        updateDetailView(onlyInTwoPaneMode: false)
    }

    func fileKeeper(didRemoveFile urlRef: URLReference, fileType: FileType) {
        guard fileType == .database else { return }
        updateDetailView(onlyInTwoPaneMode: false)
    }

    func fileKeeperHasPendingOperation() {
        if isViewLoaded {
            processPendingFileOperations()
        }
    }
}

extension ChooseDatabaseVC: UIDocumentPickerDelegate {
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL])
    {
        guard let url = urls.first else { return }
        FileAddingHelper.ensureDatabaseFile(url: url, parent: self) { [weak self] (url) in
            guard let self = self else { return }
            switch controller.documentPickerMode {
            case .open:
                FileKeeper.shared.prepareToAddFile(url: url, fileType: .database, mode: .openInPlace)
            case .import:
                FileKeeper.shared.prepareToAddFile(url: url, fileType: .database, mode: .import)
            default:
                assertionFailure("Unexpected document picker mode")
            }
            self.processPendingFileOperations()
            self.navigationController?.popToViewController(self, animated: true) 
        }
    }
}

extension ChooseDatabaseVC: DatabaseCreatorCoordinatorDelegate {
    func didPressCancel(in databaseCreatorCoordinator: DatabaseCreatorCoordinator) {
        presentedViewController?.dismiss(animated: true) { 
            self.databaseCreatorCoordinator = nil
        }
    }
    
    func didCreateDatabase(
        in databaseCreatorCoordinator: DatabaseCreatorCoordinator,
        database urlRef: URLReference)
    {
        presentedViewController?.dismiss(animated: true) { 
            self.databaseCreatorCoordinator = nil
        }
        navigationController?.popToViewController(self, animated: true) 
        Settings.current.startupDatabase = urlRef
        updateDetailView(onlyInTwoPaneMode: false)
    }
}

extension ChooseDatabaseVC: WelcomeDelegate {
    func didPressCreateDatabase(in welcomeVC: WelcomeVC) {
        didPressCreateDatabase()
    }

    func didPressAddExistingDatabase(in welcomeVC: WelcomeVC) {
        didPressOpenDatabase()
    }
}

extension ChooseDatabaseVC: PasscodeInputDelegate {
    func passcodeInputDidCancel(_ sender: PasscodeInputVC) {
        do {
            try Keychain.shared.removeAppPasscode() 
        } catch {
            Diag.error(error.localizedDescription)
            showErrorAlert(error, title: LString.titleKeychainError)
            return
        }
        sender.dismiss(animated: true, completion: nil)
        tableView.reloadData()
    }
    
    func passcodeInput(_sender: PasscodeInputVC, canAcceptPasscode passcode: String) -> Bool {
        return passcode.count > 0
    }
    
    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode passcode: String) {
        sender.dismiss(animated: true) {
            [weak self] in
            do {
                try Keychain.shared.setAppPasscode(passcode)
                Settings.current.isBiometricAppLockEnabled = true
                self?.tableView.reloadData()
            } catch {
                Diag.error(error.localizedDescription)
                self?.showErrorAlert(error, title: LString.titleKeychainError)
            }
        }
    }
}

extension ChooseDatabaseVC: AppLockSetupCellDelegate {
    func didPressClose(in cell: AppLockSetupCell) {
        Settings.current.isHideAppLockSetupReminder = true
        tableView.reloadSections([0], with: .automatic)
    }
    
    func didPressEnableAppLock(in cell: AppLockSetupCell) {
        didPressAppLockSetup()
    }
}
