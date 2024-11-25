//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol KeyFilePickerDelegate: AnyObject {
    func didPressImportKeyFile(at popoverAnchor: PopoverAnchor, in keyFilePicker: KeyFilePickerVC)
    func didSelectFile(_ selectedFile: URLReference?, in keyFilePicker: KeyFilePickerVC)
    func didPressEliminate(
        keyFile: URLReference,
        at popoverAnchor: PopoverAnchor,
        in keyFilePicker: KeyFilePickerVC)
    func didPressFileInfo(
        for keyFile: URLReference,
        at popoverAnchor: PopoverAnchor,
        in keyFilePicker: KeyFilePickerVC)
    func didPressUseKeyFile(at popoverAnchor: PopoverAnchor, in keyFilePicker: KeyFilePickerVC)
    func didPressCreateKeyFile(at popoverAnchor: PopoverAnchor, in keyFilePicker: KeyFilePickerVC)
}

final class KeyFilePickerVC: TableViewControllerWithContextActions, Refreshable {
    private enum CellID {
        static let noKeyFile = "NoKeyFileCell"
        static let keyFile = "KeyFileCell"
    }
    private enum Section: Int {
        case fixedOptions = 0
        case knownFiles = 1
    }

    @IBOutlet private weak var addKeyFileBarButton: UIBarButtonItem!

    weak var delegate: KeyFilePickerDelegate?

    private var keyFileRefs = [URLReference]()

    private let fileInfoReloader = FileInfoReloader()
    private var fileKeeperNotifications: FileKeeperNotifications!

    override var canBecomeFirstResponder: Bool { true }


    public static func create() -> KeyFilePickerVC {
        let vc = KeyFilePickerVC.instantiateFromStoryboard()
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        fileKeeperNotifications = FileKeeperNotifications(observer: self)

        setupTableView()
        setupAddKeyFileBarButton()

        refresh()

        clearsSelectionOnViewWillAppear = true
    }

    private func setupTableView() {
        if ProcessInfo.isRunningOnMac {
            let refreshButton = UIBarButtonItem(
                barButtonSystemItem: .refresh,
                target: self,
                action: #selector(refresh)
            )
            navigationItem.rightBarButtonItems?.append(refreshButton)
        }

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        tableView.delegate = self
        tableView.dataSource = self
    }

    private func setupAddKeyFileBarButton() {
        let popoverAnchor = PopoverAnchor(barButtonItem: addKeyFileBarButton)
        addKeyFileBarButton.primaryAction = nil
        let createMenu = UIMenu(options: [.displayInline], children: [
            UIAction(
                title: LString.actionCreateKeyFile,
                image: .symbol(.plus),
                handler: { [weak self] _ in
                    guard let self = self else { return }
                    delegate?.didPressCreateKeyFile(at: popoverAnchor, in: self)
                }
            )
        ])
        addKeyFileBarButton.menu = UIMenu.make(children: [
            UIAction(
                title: LString.importKeyFileAction,
                subtitle: LString.importKeyFileDescription,
                image: .symbol(.folderBadgePlus),
                handler: { [weak self] _ in
                    guard let self else { return }
                    delegate?.didPressImportKeyFile(at: popoverAnchor, in: self)
                }
            ),
            UIAction(
                title: LString.useKeyFileAction,
                subtitle: LString.useKeyFileDescription,
                image: .symbol(.folder),
                handler: { [weak self] _ in
                    guard let self = self else { return }
                    delegate?.didPressUseKeyFile(at: popoverAnchor, in: self)
                }
            ),
            createMenu,
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fileKeeperNotifications.startObserving()
    }

    override func viewWillDisappear(_ animated: Bool) {
        tableView.removeObserver(self, forKeyPath: "contentSize")
        super.viewWillDisappear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        fileKeeperNotifications.stopObserving()
        super.viewDidDisappear(animated)
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        var preferredSize = tableView.contentSize
        preferredSize.width = 400
        self.preferredContentSize = preferredSize
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

    @objc
    func refresh() {
        keyFileRefs = FileKeeper.shared.getAllReferences(fileType: .keyFile, includeBackup: false)
        fileInfoReloader.getInfo(
            for: keyFileRefs,
            update: { [weak self] _ in
                self?.tableView.reloadData()
            },
            completion: { [weak self] in
                self?.sortFileList()
            }
        )
        tableView.reloadData()
    }

    fileprivate func sortFileList() {
        let sortOrder = Settings.current.filesSortOrder
        keyFileRefs.sort { return sortOrder.compare($0, $1) }
        tableView.reloadData()
    }


    func setBusyIndicatorVisible(_ visible: Bool) {
        if visible {
            view.makeToastActivity(.center)
        } else {
            view.hideToastActivity()
        }
    }


    private func getFileForRow(at indexPath: IndexPath) -> URLReference? {
        switch Section(rawValue: indexPath.section)! {
        case .fixedOptions:
            return nil
        case .knownFiles:
            guard indexPath.row < keyFileRefs.count else {
                return nil
            }
            return keyFileRefs[indexPath.row]
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if keyFileRefs.isEmpty {
            return 1
        } else {
            return 2
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .fixedOptions:
            return 1
        case .knownFiles:
            return keyFileRefs.count
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .fixedOptions:
            return makeFixedOptionsCell(at: indexPath)
        case .knownFiles:
            return makeKeyFileCell(at: indexPath)
        }
    }

    private func makeFixedOptionsCell(at indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            return tableView.dequeueReusableCell(
                withIdentifier: CellID.noKeyFile,
                for: indexPath)
        default:
            assertionFailure("No such cell")
            return UITableViewCell()
        }
    }

    private func makeKeyFileCell(at indexPath: IndexPath) -> UITableViewCell {
        let keyFileRef = keyFileRefs[indexPath.row]
        let cell = FileListCellFactory.dequeueReusableCell(
            from: tableView,
            withIdentifier: CellID.keyFile,
            for: indexPath,
            for: .keyFile)
        cell.showInfo(from: keyFileRef)
        cell.isAnimating = keyFileRef.isRefreshingInfo
        cell.accessoryTapHandler = { [weak self, indexPath] _ in
            guard let self = self else { return }
            self.tableView(self.tableView, accessoryButtonTappedForRowWith: indexPath)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return getFileForRow(at: indexPath) != nil
    }


    override func tableView(
        _ tableView: UITableView,
        accessoryButtonTappedForRowWith indexPath: IndexPath
    ) {
        switch Section(rawValue: indexPath.section)! {
        case .fixedOptions:
            assertionFailure("There's no accessory button setup")
        case .knownFiles:
            let fileRef = keyFileRefs[indexPath.row]
            let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
            delegate?.didPressFileInfo(for: fileRef, at: popoverAnchor, in: self)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (Section(rawValue: indexPath.section)!, indexPath.row) {
        case (.fixedOptions, 0):
            delegate?.didSelectFile(nil, in: self)
        case (.knownFiles, _):
            let fileRef = getFileForRow(at: indexPath)
            delegate?.didSelectFile(fileRef, in: self)
        default:
            assertionFailure("Unexpected row selected")
        }
    }

    override func getContextActionsForRow(
        at indexPath: IndexPath,
        forSwipe: Bool
    ) -> [ContextualAction] {
        guard let fileRef = getFileForRow(at: indexPath) else {
            return []
        }

        let destructiveActionTitle = DestructiveFileAction.get(for: fileRef.location).title
        let destructiveAction = ContextualAction(
            title: destructiveActionTitle,
            imageName: .trash,
            style: .destructive,
            color: .destructiveTint,
            handler: { [weak self] in
                guard let self = self else { return }
                let popoverAnchor = PopoverAnchor(tableView: self.tableView, at: indexPath)
                self.delegate?.didPressEliminate(
                    keyFile: fileRef,
                    at: popoverAnchor,
                    in: self
                )
            }
        )
        return [destructiveAction]
    }
}

extension KeyFilePickerVC: FileKeeperObserver {
    func fileKeeper(didAddFile urlRef: URLReference, fileType: FileType) {
        guard fileType == .keyFile else { return }
        refresh()
    }

    func fileKeeper(didRemoveFile urlRef: URLReference, fileType: FileType) {
        guard fileType == .keyFile else { return }
        refresh()
    }

    func fileKeeperHasPendingOperation() {
    }
}

extension KeyFilePickerVC {
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(
                action: #selector(refresh),
                hotkey: .refreshList,
                discoverabilityTitle: LString.actionRefreshList
            )
        ]
    }
}
