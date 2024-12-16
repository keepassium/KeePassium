//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import LocalAuthentication.LAContext


protocol DatabasePickerDelegate: AnyObject {
    #if MAIN_APP
    func didPressHelp(at popoverAnchor: PopoverAnchor, in viewController: DatabasePickerVC)
    func didPressSettings(at popoverAnchor: PopoverAnchor, in viewController: DatabasePickerVC)
    #endif
    func didPressPasswordGenerator(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC
    )
    func didPressCancel(in viewController: DatabasePickerVC)
    func didPressShowDiagnostics(in viewController: DatabasePickerVC)

    func needsPremiumToAddDatabase(in viewController: DatabasePickerVC) -> Bool
    func didPressAddExistingDatabase(in viewController: DatabasePickerVC)
    func didPressAddRemoteDatabase(in viewController: DatabasePickerVC)

    #if MAIN_APP
    func didPressCreateDatabase(in viewController: DatabasePickerVC)
    #endif

    func didPressRevealDatabaseInFinder(
        _ fileRef: URLReference,
        in viewController: DatabasePickerVC)
    func didPressExportDatabase(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC)
    func didPressEliminateDatabase(
        _ fileRef: URLReference,
        shouldConfirm: Bool,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC)
    func didPressDatabaseSettings(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC)
    func didPressFileInfo(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabasePickerVC)

    func shouldKeepSelection(in viewController: DatabasePickerVC) -> Bool

    func getDefaultDatabase(
        from databases: [URLReference],
        in viewController: DatabasePickerVC)
        -> URLReference?

    func shouldAcceptDatabaseSelection(
        _ fileRef: URLReference,
        in viewController: DatabasePickerVC) -> Bool

    func didSelectDatabase(_ fileRef: URLReference, in viewController: DatabasePickerVC)
}

final class DatabasePickerVC: TableViewControllerWithContextActions, Refreshable {

    private enum CellID: String {
        case fileItem = "FileItemCell"
    }
    @IBOutlet private weak var aboutButton: UIBarButtonItem!
    @IBOutlet private weak var listActionsButton: UIBarButtonItem!
    @IBOutlet private weak var passwordGeneratorButton: UIBarButtonItem!
    @IBOutlet private weak var refreshButton: UIBarButtonItem!
    @IBOutlet private weak var appSettingsButton: UIBarButtonItem!

    public weak var delegate: DatabasePickerDelegate?
    public var mode: DatabasePickerMode = .light

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
            if let toolbarItems = toolbarItems {
                for item in toolbarItems {
                    item.isEnabled = _isEnabled
                }
            }
            UIView.animate(withDuration: 0.5) { [weak self] in
                self?.tableView.alpha = alpha
            }
        }
    }

    private(set) var databaseRefs: [URLReference] = []
    private var selectedRef: URLReference?

    private var settingsNotifications: SettingsNotifications!

    private let fileInfoReloader = FileInfoReloader()

    internal var ongoingUpdateAnimations = 0

    override var canDismissFromKeyboard: Bool {
        switch mode {
        case .full:
            return false
        case .autoFill, .light:
            return true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = LString.titleDatabases
        tableView.accessibilityLabel = LString.titleDatabases
        tableView.estimatedRowHeight = 44.0
        tableView.rowHeight = UITableView.automaticDimension
        setupEmptyView(tableView)

        aboutButton.title = LString.titleAboutKeePassium
        listActionsButton.title = LString.titleMoreActions
        refreshButton.title = LString.actionRefreshList
        passwordGeneratorButton.title = LString.PasswordGenerator.titleRandomGenerator
        appSettingsButton.title = LString.titleSettings

        settingsNotifications = SettingsNotifications(observer: self)

        if !ProcessInfo.isRunningOnMac {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
            self.refreshControl = refreshControl
        }
        clearsSelectionOnViewWillAppear = false

        switch mode {
        case .autoFill:
            setupCancelButton()
        case .full:
            break
        case .light:
            if (navigationController?.viewControllers.count ?? 1) > 1 {
                navigationItem.leftBarButtonItem = nil
            } else {
                setupCancelButton()
            }
        }
    }

    private func setupEmptyView(_ tableView: UITableView) {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .auxiliaryText
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.text = LString.titleNoDatabaseFiles
        label.textAlignment = .center

        tableView.backgroundView = label
    }

    private func setupCancelButton() {
        let cancelBarButton = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didPressCancel(_:)))
        let diagMenuItem = UIAction(title: LString.titleDiagnosticLog) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.didPressShowDiagnostics(in: self)
        }
        cancelBarButton.menu = UIMenu(children: [diagMenuItem])
        navigationItem.leftBarButtonItem = cancelBarButton
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        switch mode {
        case .full:
            navigationController?.setToolbarHidden(false, animated: false)
        case .autoFill, .light:
            navigationController?.setToolbarHidden(true, animated: false)
        }
        settingsNotifications.startObserving()
        refresh()
        UIAccessibility.post(notification: .screenChanged, argument: tableView)

        if mode == .autoFill,
           !FileKeeper.shared.canActuallyAccessAppSandbox
        {
            showNotification(
                LString.messageLocalFilesMissing,
                image: .symbol(.exclamationMarkTriangle),
                position: .center
            )
        }
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
        listActionsButton.menu = makeListActionsMenu()

        let includeBackup: Bool
        switch mode {
        case .full, .autoFill:
            includeBackup = Settings.current.isBackupFilesVisible
        case .light:
            includeBackup = false
        }

        databaseRefs = FileKeeper.shared.getAllReferences(
            fileType: .database,
            includeBackup: includeBackup)
        sortFileList()

        tableView.backgroundView?.isHidden = !databaseRefs.isEmpty

        if let defaultDatabase = delegate?.getDefaultDatabase(from: databaseRefs, in: self) {
            if delegate?.shouldAcceptDatabaseSelection(defaultDatabase, in: self) ?? true {
                selectDatabase(defaultDatabase, animated: false)
                delegate?.didSelectDatabase(defaultDatabase, in: self)
            } else {
                Diag.debug("Default database could not be selected, skipping")
            }
        }

        fileInfoReloader.getInfo(
            for: databaseRefs,
            update: { [weak self] _ in
                guard let self = self else { return }
                self.sortAndAnimateFileInfoUpdate(refs: &self.databaseRefs, in: self.tableView)
            },
            completion: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + self.sortingAnimationDuration) { [weak self] in
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
           delegate?.shouldKeepSelection(in: self) ?? false {
            selectDatabase(selectedRef, animated: false)
        }
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

    private func showSelectionDeniedAnimation(at indexPath: IndexPath) {
        guard let cellView = tableView.cellForRow(at: indexPath)?.contentView else {
            return
        }
        cellView.shake()
    }


    private func makeListActionsMenu() -> UIMenu {
        let needPremium = delegate?.needsPremiumToAddDatabase(in: self) ?? true
        var menuItems = [UIMenuElement]()

        #if MAIN_APP
        switch mode {
        case .full, .light:
            let createDatabaseAction = UIAction(
                title: LString.titleNewDatabase,
                image: needPremium ? .premiumBadge : .symbol(.plus),
                handler: { [weak self] _ in
                    guard let self = self else { return }
                    self.delegate?.didPressCreateDatabase(in: self)
                }
            )
            menuItems.append(createDatabaseAction)
        case .autoFill:
            assertionFailure("Tried to use .autoFill mode in main app")
        }
        #endif

        let appConfig = ManagedAppConfig.shared
        let openDatabaseAction = UIAction(
            title: LString.actionOpenDatabase,
            image: needPremium ? .premiumBadge : .symbol(.folder),
            attributes: appConfig.areSystemFileProvidersAllowed ? [] : [.disabled],
            handler: { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.didPressAddExistingDatabase(in: self)
            }
        )
        menuItems.append(openDatabaseAction)

        let addRemoteDatabaseAction = UIAction(
            title: LString.actionConnectToServer,
            image: needPremium ? UIImage.premiumBadge : UIImage.symbol(.network),
            attributes: appConfig.areInAppFileProvidersAllowed ? [] : [.disabled],
            handler: { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.didPressAddRemoteDatabase(in: self)
            }
        )
        let addRemoteDatabaseMenu = UIMenu.make(
            title: "",
            reverse: false,
            options: .displayInline,
            children: [addRemoteDatabaseAction])
        menuItems.append(addRemoteDatabaseMenu)

        let showBackupAction = UIAction(
            title: LString.titleShowBackupFiles,
            attributes: [],
            state: Settings.current.isBackupFilesVisible ? .on : .off,
            handler: { [weak self] action in
                let isOn = (action.state == .on)
                Settings.current.isBackupFilesVisible = !isOn
                self?.refresh()
                self?.showNotificationIfManaged(setting: .backupFilesVisible)
            }
        )
        menuItems.append(showBackupAction)

        let currentSortOrder = Settings.current.filesSortOrder
        let sortMenuItems = UIMenu.makeFileSortMenuItems(
            current: currentSortOrder,
            handler: { [weak self] newSortOrder in
                Settings.current.filesSortOrder = newSortOrder
                self?.refresh()
            }
        )
        let sortOptionsMenu = UIMenu.make(
            title: LString.titleSortOrder,
            subtitle: currentSortOrder.title,
            reverse: false,
            options: [],
            macOptions: [],
            children: sortMenuItems
        )
        menuItems.append(sortOptionsMenu)

        return UIMenu.make(reverse: false, children: menuItems)
    }


    #if MAIN_APP
    @IBAction private func didPressSettingsButton(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressSettings(at: popoverAnchor, in: self)
    }

    @IBAction private func didPressHelpButton(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressHelp(at: popoverAnchor, in: self)
    }
    #endif

    @IBAction private func didPressPasswordGeneratorButton(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressPasswordGenerator(at: popoverAnchor, in: self)
    }

    @IBAction private func didPressRefresh(_ sender: UIBarButtonItem) {
        refresh()
    }

    @objc func didPressCancel(_ sender: UIBarButtonItem) {
        delegate?.didPressCancel(in: self)
    }

    private func didPressFileInfo(_ fileRef: URLReference, at indexPath: IndexPath) {
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressFileInfo(fileRef, at: popoverAnchor, in: self)
    }

    private func didPressRevealInFinder(_ fileRef: URLReference, at indexPath: IndexPath) {
        assert(ProcessInfo.isRunningOnMac)
        guard let fileRef = getFileRef(at: indexPath) else { assertionFailure(); return }
        delegate?.didPressRevealDatabaseInFinder(fileRef, in: self)
    }

    func didPressExportDatabase(_ fileRef: URLReference, at indexPath: IndexPath) {
        guard let fileRef = getFileRef(at: indexPath) else { assertionFailure(); return }
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressExportDatabase(fileRef, at: popoverAnchor, in: self)
    }

    func didPressDatabaseSettings(_ fileRef: URLReference, at indexPath: IndexPath) {
        guard let fileRef = getFileRef(at: indexPath) else { assertionFailure(); return }
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressDatabaseSettings(fileRef, at: popoverAnchor, in: self)
    }

    func didPressEliminateDatabase(_ fileRef: URLReference, at indexPath: IndexPath) {
        StoreReviewSuggester.registerEvent(.trouble)

        guard let fileRef = getFileRef(at: indexPath) else { assertionFailure(); return }
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)

        delegate?.didPressEliminateDatabase(
            fileRef,
            shouldConfirm: !fileRef.hasError,
            at: popoverAnchor,
            in: self
        )
    }


    private func getFileRef(at indexPath: IndexPath) -> URLReference? {
        let fileIndex = indexPath.row
        guard databaseRefs.indices.contains(fileIndex) else {
            return nil
        }
        return databaseRefs[fileIndex]
    }

    private func getIndexPath(for fileRef: URLReference) -> IndexPath? {
        guard let originalInstance = fileRef.find(in: databaseRefs, fallbackToNamesake: false),
              let fileIndex = databaseRefs.firstIndex(of: originalInstance)
        else {
            return nil
        }
        return IndexPath(row: fileIndex, section: 0)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return databaseRefs.count
    }

    private func getCellID(for indexPath: IndexPath) -> CellID {
        return .fileItem
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch getCellID(for: indexPath) {
        case .fileItem:
            return makeFileItemCell(tableView, indexPath: indexPath)
        }
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
        guard let dbRef = getFileRef(at: indexPath) else { fatalError() }
        cell.showInfo(from: dbRef)
        cell.isAnimating = dbRef.isRefreshingInfo
        cell.accessoryMenu = makeDatabaseContextMenu(for: indexPath)
        cell.accessoryTapHandler = { [weak self, indexPath] _ in
            guard let self = self else { return }
            self.tableView(self.tableView, accessoryButtonTappedForRowWith: indexPath)
        }
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
        case .fileItem:
            guard let selectedDatabaseRef = getFileRef(at: indexPath) else {
                assertionFailure()
                return
            }
            if delegate?.shouldAcceptDatabaseSelection(selectedDatabaseRef, in: self) ?? true {
                selectedRef = selectedDatabaseRef
                delegate?.didSelectDatabase(selectedDatabaseRef, in: self)
            } else {
                showSelectionDeniedAnimation(at: indexPath)
            }
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
        guard let fileRef = getFileRef(at: indexPath) else { assertionFailure(); return }
        didPressFileInfo(fileRef, at: indexPath)
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

        guard let fileRef = getFileRef(at: indexPath) else { assertionFailure(); return [] }
        var actions = [ContextualAction]()
        if ProcessInfo.isRunningOnMac {
            actions.append(makeRevealInFinderAction(for: fileRef, at: indexPath))
        } else {
            actions.append(makeExportFileAction(for: fileRef, at: indexPath))
        }
        actions.append(makeDestructiveFileAction(for: fileRef, at: indexPath))
        return actions
    }

    override func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            self?.makeDatabaseContextMenu(for: indexPath)
        }
    }

    private func makeDatabaseContextMenu(for indexPath: IndexPath) -> UIMenu? {
        let cellType = getCellID(for: indexPath)
        let isEditableRow = cellType == .fileItem
        guard isEditableRow else {
            return nil
        }

        var menuItems = [UIMenuElement]()
        guard let fileRef = getFileRef(at: indexPath) else { assertionFailure(); return nil }

        let databaseSettingsAction = makeDatabaseSettingsAction(for: fileRef, at: indexPath)
        let databaseSettingsMenu = UIMenu(
            title: "",
            image: nil,
            options: [.displayInline],
            children: [databaseSettingsAction.toMenuAction()]
        )
        menuItems.append(databaseSettingsMenu)

        menuItems.append(makeFileInfoAction(for: fileRef, at: indexPath).toMenuAction())

        if ProcessInfo.isRunningOnMac {
            menuItems.append(
                makeRevealInFinderAction(for: fileRef, at: indexPath).toMenuAction()
            )
        } else {
            menuItems.append(
                makeExportFileAction(for: fileRef, at: indexPath).toMenuAction()
            )
        }
        menuItems.append(makeDestructiveFileAction(for: fileRef, at: indexPath).toMenuAction())

        return UIMenu(title: "", children: menuItems)
    }

    private func makeDatabaseSettingsAction(
        for fileRef: URLReference,
        at indexPath: IndexPath
    ) -> ContextualAction {
        return ContextualAction(
            title: LString.titleDatabaseSettings,
            imageName: .gearshape2,
            style: .default,
            handler: { [weak self] in
                self?.didPressDatabaseSettings(fileRef, at: indexPath)
            }
        )
    }

    private func makeFileInfoAction(
        for fileRef: URLReference,
        at indexPath: IndexPath
    ) -> ContextualAction {
        return ContextualAction(
            title: LString.FileInfo.menuFileInfo,
            imageName: .infoCircle,
            style: .default,
            handler: { [weak self] in
                self?.didPressFileInfo(fileRef, at: indexPath)
            }
        )
    }

    private func makeRevealInFinderAction(
        for fileRef: URLReference,
        at indexPath: IndexPath
    ) -> ContextualAction {
        return ContextualAction(
            title: LString.actionRevealInFinder,
            imageName: .folder,
            style: .default,
            color: UIColor.actionTint,
            handler: { [weak self] in
                self?.didPressRevealInFinder(fileRef, at: indexPath)
            }
        )
    }

    private func makeExportFileAction(
        for fileRef: URLReference,
        at indexPath: IndexPath
    ) -> ContextualAction {
        return ContextualAction(
            title: LString.actionExport,
            imageName: .squareAndArrowUp,
            style: .default,
            color: UIColor.actionTint,
            handler: { [weak self, indexPath] in
                self?.didPressExportDatabase(fileRef, at: indexPath)
            }
        )
    }

    private func makeDestructiveFileAction(
        for fileRef: URLReference,
        at indexPath: IndexPath
    ) -> ContextualAction {
        let destructiveActionTitle = DestructiveFileAction.get(for: fileRef.location).title
        return ContextualAction(
            title: destructiveActionTitle,
            imageName: .trash,
            style: .destructive,
            color: UIColor.destructiveTint,
            handler: { [weak self, indexPath] in
                self?.didPressEliminateDatabase(fileRef, at: indexPath)
            }
        )
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
        case .filesSortOrder,
             .backupFilesVisible,
             .networkAccessAllowed:
            refresh()
        case .appLockEnabled, .rememberDatabaseKey:
            tableView.reloadSections([0], with: .automatic)
        default:
            break
        }
    }
}
