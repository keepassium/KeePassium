//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol KeyFilePickerDelegate: class {
    func didPressAddKeyFile(in keyFilePicker: KeyFilePickerVC, at popoverAnchor: PopoverAnchor)
    func didSelectFile(in keyFilePicker: KeyFilePickerVC, selectedFile: URLReference?)
    func didPressRemoveOrDeleteFile(
        in keyFilePicker: KeyFilePickerVC,
        keyFile: URLReference,
        at popoverAnchor: PopoverAnchor)
    func didPressFileInfo(
        in keyFilePicker: KeyFilePickerVC,
        for keyFile: URLReference,
        at popoverAnchor: PopoverAnchor)
}

class KeyFilePickerVC: TableViewControllerWithContextActions, Refreshable {
    private enum CellID {
        static let noKeyFile = "NoKeyFileCell"
        static let keyFile = "KeyFileCell"
    }

    @IBOutlet weak var addKeyFileBarButton: UIBarButtonItem!
    
    weak var delegate: KeyFilePickerDelegate?

    var keyFileRefs = [URLReference]()
    
    private let fileInfoReloader = FileInfoReloader()
    private var fileKeeperNotifications: FileKeeperNotifications!

    
    public static func create() -> KeyFilePickerVC {
        let vc = KeyFilePickerVC.instantiateFromStoryboard()
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fileKeeperNotifications = FileKeeperNotifications(observer: self)
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        self.refreshControl = refreshControl
        
        refresh()
        
        clearsSelectionOnViewWillAppear = true
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
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?)
    {
        var preferredSize = tableView.contentSize
        if #available(iOS 13, *) {
            preferredSize.width = 400
        }
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

    func refresh() {
        keyFileRefs = FileKeeper.shared.getAllReferences(fileType: .keyFile, includeBackup: false)
        fileInfoReloader.getInfo(
            for: keyFileRefs,
            update: { [weak self] (ref) in
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
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return keyFileRefs.count + 1
    }

    private func getFileForRow(at indexPath: IndexPath) -> URLReference? {
        guard indexPath.row > 0 else {
            return nil
        }
        return keyFileRefs[indexPath.row - 1]
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath)
        -> UITableViewCell
    {
        guard let keyFileRef = getFileForRow(at: indexPath) else {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.noKeyFile,
                for: indexPath)
            return cell
        }

        let cell = FileListCellFactory.dequeueReusableCell(
            from: tableView,
            withIdentifier: CellID.keyFile,
            for: indexPath,
            for: .keyFile)
        cell.showInfo(from: keyFileRef)
        cell.isAnimating = keyFileRef.isRefreshingInfo
        cell.accessoryTapHandler = { [weak self, indexPath] cell in
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
        accessoryButtonTappedForRowWith indexPath: IndexPath)
    {
        guard let fileRef = getFileForRow(at: indexPath) else {
            assertionFailure("Accessory tapped for non-file cell")
            return
        }
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressFileInfo(in: self, for: fileRef, at: popoverAnchor)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let fileRef = getFileForRow(at: indexPath)
        delegate?.didSelectFile(in: self, selectedFile: fileRef)
    }
    
    @IBAction func didPressAddKeyFile(_ sender: Any) {
        let popoverAnchor = PopoverAnchor(barButtonItem: addKeyFileBarButton)
        delegate?.didPressAddKeyFile(in: self, at: popoverAnchor)
    }
    
    func didPressRemoveOrDeleteKeyFile(at indexPath: IndexPath) {
        guard let fileRef = getFileForRow(at: indexPath) else {
            assertionFailure()
            return
        }
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressRemoveOrDeleteFile(in: self, keyFile: fileRef, at: popoverAnchor)
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
                self.delegate?.didPressRemoveOrDeleteFile(
                    in: self,
                    keyFile: fileRef,
                    at: popoverAnchor
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
