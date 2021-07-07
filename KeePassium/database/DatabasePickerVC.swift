//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib


protocol AppLockSetupCellDelegate: AnyObject {
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


protocol DatabasePickerDelegate: AnyObject {
    func didPressSetupAppLock(in viewController: DatabasePickerVC)
    
    #if MAIN_APP
    func didPressHelp(at popoverAnchor: PopoverAnchor, in viewController: DatabasePickerVC)
    func didPressListOptions(at popoverAnchor: PopoverAnchor, in viewController: DatabasePickerVC)
    func didPressSettings(at popoverAnchor: PopoverAnchor, in viewController: DatabasePickerVC)
    #else
    func didPressCancel(in viewController: DatabasePickerVC)
    #endif

    func didPressAddDatabaseOptions(at popoverAnchor: PopoverAnchor, in viewController: DatabasePickerVC)
    func didPressAddExistingDatabase(at popoverAnchor: PopoverAnchor, in viewController: DatabasePickerVC)
    #if MAIN_APP
    func didPressCreateDatabase(at popoverAnchor: PopoverAnchor, in viewController: DatabasePickerVC)
    #endif

    func didPressExportDatabase(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC)
    func didPressEliminateDatabase(
        _ fileRef: URLReference,
        shouldConfirm: Bool,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC)
    func didPressDatabaseProperties(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC)

    func shouldKeepSelection(in viewController: DatabasePickerVC) -> Bool
    
    func getDefaultDatabase(
        from databases: [URLReference],
        in viewController: DatabasePickerVC)
        -> URLReference?
    
    func didSelectDatabase(_ fileRef: URLReference, in viewController: DatabasePickerVC)
}

final class DatabasePickerVC: TableViewControllerWithContextActions, Refreshable {
    
    private enum CellID: String {
        case fileItem = "FileItemCell"
        case noFiles = "NoFilesCell"
        case appLockSetup = "AppLockSetupCell"
    }
    @IBOutlet private weak var addDatabaseBarButton: UIBarButtonItem!
    @IBOutlet private weak var sortOrderButton: UIBarButtonItem!
    
    public weak var delegate: DatabasePickerDelegate?
    
    private var _isEnabled = true
    var isEnabled: Bool {
        get { return _isEnabled }
        set {
            _isEnabled = newValue
            let alpha: CGFloat = _isEnabled ? 1.0 : 0.5
            navigationController?.navigationBar.isUserInteractionEnabled = _isEnabled
            navigationItem.leftBarButtonItems?.forEach { $0.isEnabled = _isEnabled }
            navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = _isEnabled }
            tableView.isUserInteractionEnabled = _isEnabled
            tableView.alpha = alpha
            if let toolbarItems = toolbarItems {
                for item in toolbarItems {
                    item.isEnabled = _isEnabled
                }
            }
        }
    }
    
    private(set) var databaseRefs: [URLReference] = []
    private var selectedRef: URLReference?
    
    private var settingsNotifications: SettingsNotifications!
    
    private let fileInfoReloader = FileInfoReloader()
    
    internal var ongoingUpdateAnimations = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = 44.0
        tableView.rowHeight = UITableView.automaticDimension
        
        settingsNotifications = SettingsNotifications(observer: self)
        
        if !ProcessInfo.isRunningOnMac {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
            self.refreshControl = refreshControl
        }
        clearsSelectionOnViewWillAppear = false
        
        #if AUTOFILL_EXT
        let cancelBarButton = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didPressCancel(_:)))
        navigationItem.leftBarButtonItem = cancelBarButton
        #endif
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if MAIN_APP
        navigationController?.setToolbarHidden(false, animated: false)
        #else
        navigationController?.setToolbarHidden(true, animated: false)
        #endif
        settingsNotifications.startObserving()
        refresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        settingsNotifications.stopObserving()
        super.viewWillDisappear(animated)
        selectedRef = nil
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
        sortOrderButton.image = Settings.current.filesSortOrder.toolbarIcon
        
        databaseRefs = FileKeeper.shared.getAllReferences(
            fileType: .database,
            includeBackup: Settings.current.isBackupFilesVisible)
        sortFileList()
        
        if let defaultDatabase = delegate?.getDefaultDatabase(from: databaseRefs, in: self) {
            selectDatabase(defaultDatabase, animated: false)
            delegate?.didSelectDatabase(defaultDatabase, in: self)
        }

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
        if let selectedRef = selectedRef,
           delegate?.shouldKeepSelection(in: self) ?? false
        {
            selectDatabase(selectedRef, animated: false)
        }
    }
    
    private func getIndexPath(for fileRef: URLReference) -> IndexPath? {
        guard let originalInstance = fileRef.find(in: databaseRefs, fallbackToNamesake: false),
              let fileIndex = databaseRefs.firstIndex(of: originalInstance)
        else {
            return nil
        }
        return getIndexPath(for: fileIndex)
    }
    
    public func selectDatabase(_ fileRef: URLReference?, animated: Bool) {
        selectedRef = fileRef
        if let fileRef = fileRef,
           let indexPathToSelect = getIndexPath(for: fileRef)
        {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.selectRow(at: indexPathToSelect, animated: animated, scrollPosition: .none)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.selectRow(at: nil, animated: animated, scrollPosition: .none)
            }
        }
    }
    
    
    #if MAIN_APP
    @IBAction func didPressSortButton(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressListOptions(at: popoverAnchor, in: self)
    }

    @IBAction func didPressSettingsButton(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressSettings(at: popoverAnchor, in: self)
    }
    
    @IBAction func didPressHelpButton(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressHelp(at: popoverAnchor, in: self)
    }
    #else
    @objc func didPressCancel(_ sender: UIBarButtonItem) {
        delegate?.didPressCancel(in: self)
    }
    #endif
    
    @IBAction func didPressAddDatabase(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressAddDatabaseOptions(at: popoverAnchor, in: self)
    }
    
    public func showAddDatabaseOptions(at popoverAnchor: PopoverAnchor) {
        let optionsSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        optionsSheet.addAction(title: LString.actionOpenDatabase, style: .default) {
            [weak self] _ in
            guard let self = self else { return }
            self.delegate?.didPressAddExistingDatabase(at: popoverAnchor, in: self)
        }
        
        #if MAIN_APP
        optionsSheet.addAction(title: LString.actionCreateDatabase, style: .default) {
            [weak self] _ in
            guard let self = self else { return }
            self.delegate?.didPressCreateDatabase(at: popoverAnchor, in: self)
        }
        #endif
        
        optionsSheet.addAction(title: LString.actionCancel, style: .cancel, handler: nil)

        popoverAnchor.apply(to: optionsSheet.popoverPresentationController)
        present(optionsSheet, animated: true, completion: nil)
    }
    

    func didPressExportDatabase(_ fileRef: URLReference, at indexPath: IndexPath) {
        let fileRef = databaseRefs[indexPath.row]
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressExportDatabase(fileRef, at: popoverAnchor, in: self)
    }
        
    func didPressEliminateDatabase(_ fileRef: URLReference, at indexPath: IndexPath) {
        StoreReviewSuggester.registerEvent(.trouble)

        let fileRef = databaseRefs[indexPath.row]
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        
        delegate?.didPressEliminateDatabase(
            fileRef,
            shouldConfirm: !fileRef.hasError,
            at: popoverAnchor,
            in: self
        )
    }
    
    
    private func shouldShowAppLockSetup() -> Bool {
        let settings = Settings.current
        if settings.isHideAppLockSetupReminder {
            return false
        }
        let isDataVulnerable = settings.isRememberDatabaseKey && !settings.isAppLockEnabled
        return isDataVulnerable
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfRows()
    }

    func numberOfRows() -> Int {
        let contentCellCount = max(databaseRefs.count, 1) // either files or "there is nothing"
        if shouldShowAppLockSetup() {
            return contentCellCount + 1
        } else {
            return contentCellCount
        }
    }

    private func getCellID(for indexPath: IndexPath) -> CellID {
        if indexPath.row < databaseRefs.count {
            return .fileItem
        }
        if shouldShowAppLockSetup() && indexPath.row == (numberOfRows() - 1) {
            return .appLockSetup
        }
        return .noFiles
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        switch getCellID(for: indexPath) {
        case .noFiles:
            return makeEmptyListCell(tableView, indexPath: indexPath)
        case .fileItem:
            return makeFileItemCell(tableView, indexPath: indexPath)
        case .appLockSetup:
            return makeAppLockSetupCell(tableView, indexPath: indexPath)
        }
    }
    
    private func makeEmptyListCell(
        _ tableView: UITableView,
        indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CellID.noFiles.rawValue,
            for: indexPath
        )
        return cell
    }
    
    private func makeFileItemCell(
        _ tableView: UITableView,
        indexPath: IndexPath
    ) -> FileListCell {
        let cell = FileListCellFactory.dequeueReusableCell(
            from: tableView,
            withIdentifier: CellID.fileItem.rawValue,
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
    }
    
    private func makeAppLockSetupCell(
        _ tableView: UITableView,
        indexPath: IndexPath
    ) -> AppLockSetupCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CellID.appLockSetup.rawValue,
            for: indexPath)
            as! AppLockSetupCell
        cell.delegate = self
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let shouldKeepSelection = delegate?.shouldKeepSelection(in: self) ?? true
        defer {
            if !shouldKeepSelection {
                tableView.deselectRow(at: indexPath, animated: true)
                selectedRef = nil
            }
        }
        
        switch getCellID(for: indexPath) {
        case .noFiles:
            break
        case .fileItem:
            let selectedDatabaseRef = databaseRefs[indexPath.row]
            selectedRef = selectedDatabaseRef
            delegate?.didSelectDatabase(selectedDatabaseRef, in: self)
        case .appLockSetup:
            break
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        accessoryButtonTappedForRowWith indexPath: IndexPath
    ) {
        guard getCellID(for: indexPath) == .fileItem else {
            Diag.warning("Accessory button tapped for an unexpected item")
            assertionFailure()
            return
        }
        
        let fileRef = databaseRefs[indexPath.row]
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressDatabaseProperties(fileRef, at: popoverAnchor, in: self)
    }
    
       
    override func getContextActionsForRow(
        at indexPath: IndexPath,
        forSwipe: Bool
    ) -> [ContextualAction] {
        let cellType = getCellID(for: indexPath)
        let isEditableRow = cellType == .fileItem
        guard isEditableRow else {
            return []
        }

        let fileRef = databaseRefs[indexPath.row]
        let exportAction = ContextualAction(
            title: LString.actionExport,
            imageName: .squareAndArrowUp,
            style: .default,
            color: UIColor.actionTint,
            handler: { [weak self, indexPath] in
                self?.didPressExportDatabase(fileRef, at: indexPath)
            }
        )
        
        let destructiveActionTitle = DestructiveFileAction.get(for: fileRef.location).title
        let destructiveAction = ContextualAction(
            title: destructiveActionTitle,
            imageName: .trash,
            style: .destructive,
            color: UIColor.destructiveTint,
            handler: { [weak self, indexPath] in
                self?.didPressEliminateDatabase(fileRef, at: indexPath)
            }
        )
        
        return [exportAction, destructiveAction]
    }
}

extension DatabasePickerVC: DynamicFileList {
    func getIndexPath(for fileIndex: Int) -> IndexPath {
        return IndexPath(row: fileIndex, section: 0)
    }
}

extension DatabasePickerVC: SettingsObserver {
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

extension DatabasePickerVC: AppLockSetupCellDelegate {
    func didPressClose(in cell: AppLockSetupCell) {
        Settings.current.isHideAppLockSetupReminder = true
        tableView.reloadSections([0], with: .automatic)
    }
    
    func didPressEnableAppLock(in cell: AppLockSetupCell) {
        delegate?.didPressSetupAppLock(in: self)
    }
}
