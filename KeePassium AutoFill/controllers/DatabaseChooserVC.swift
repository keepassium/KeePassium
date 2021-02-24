//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseChooserDelegate: class {
    func databaseChooserShouldCancel(_ sender: DatabaseChooserVC)
    func databaseChooserShouldAddDatabase(_ sender: DatabaseChooserVC, popoverAnchor: PopoverAnchor)
    func databaseChooser(_ sender: DatabaseChooserVC, didSelectDatabase urlRef: URLReference)
    func databaseChooser(_ sender: DatabaseChooserVC, shouldDeleteDatabase urlRef: URLReference)
    func databaseChooser(_ sender: DatabaseChooserVC, shouldRemoveDatabase urlRef: URLReference)
    func databaseChooser(_ sender: DatabaseChooserVC, shouldShowInfoForDatabase urlRef: URLReference)
}

class DatabaseChooserVC: UITableViewController, DynamicFileList, Refreshable {
    private enum CellID {
        static let fileItem = "FileItemCell"
        static let noFiles = "NoFilesCell"
    }
    
    weak var delegate: DatabaseChooserDelegate?
    
    private(set) var databaseRefs: [URLReference] = []

    private let fileInfoReloader = FileInfoReloader()

    internal var ongoingUpdateAnimations = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        self.refreshControl = refreshControl

        let longPressGestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(didLongPressTableView))
        tableView.addGestureRecognizer(longPressGestureRecognizer)
        
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
        refresh()
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

    @objc func refresh() {
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

    func getIndexPath(for fileIndex: Int) -> IndexPath {
        return IndexPath(row: fileIndex, section: 0)
    }
    
    
    @IBAction func didPressCancel(_ sender: Any) {
        Watchdog.shared.restart()
        delegate?.databaseChooserShouldCancel(self)
    }
    
    @IBAction func didPressAddDatabase(_ sender: UIBarButtonItem) {
        Watchdog.shared.restart()
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.databaseChooserShouldAddDatabase(self, popoverAnchor: popoverAnchor)
    }
    
    @objc func didLongPressTableView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        Watchdog.shared.restart()
        let point = gestureRecognizer.location(in: tableView)
        guard gestureRecognizer.state == .began,
            let indexPath = tableView.indexPathForRow(at: point),
            tableView(tableView, canEditRowAt: indexPath) else { return }
        showActions(for: indexPath)
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if databaseRefs.isEmpty {
            return 1 // for "nothing here" cell
        } else {
            return databaseRefs.count
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath)
        -> UITableViewCell
    {
        guard databaseRefs.count > 0 else {
            let cell = tableView.dequeueReusableCell(withIdentifier: CellID.noFiles, for: indexPath)
            return cell
        }
        
        let cell = FileListCellFactory.dequeueReusableCell(
            from: tableView,
            withIdentifier: CellID.fileItem,
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard databaseRefs.count > 0 else { return }
        let dbRef = databaseRefs[indexPath.row]
        delegate?.databaseChooser(self, didSelectDatabase: dbRef)
    }
    
    override func tableView(
        _ tableView: UITableView,
        accessoryButtonTappedForRowWith indexPath: IndexPath)
    {
        Watchdog.shared.restart()
        let urlRef = databaseRefs[indexPath.row]
        delegate?.databaseChooser(self, shouldShowInfoForDatabase: urlRef)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return databaseRefs.count > 0
    }
    
    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        Watchdog.shared.restart()
        guard databaseRefs.count > 0 else { return nil }
        
        let urlRef = databaseRefs[indexPath.row]
        let destructiveFileAction = DestructiveFileAction.get(for: urlRef.location)
        let deleteAction = UIContextualAction(
            style: .destructive,
            title: destructiveFileAction.title)
        {
            [weak self] (action, sourceView, completion) in
            guard let self = self else { return }
            self.setEditing(false, animated: true)
            switch destructiveFileAction {
            case .delete:
                self.delegate?.databaseChooser(self, shouldDeleteDatabase: urlRef)
            case .remove:
                self.delegate?.databaseChooser(self, shouldRemoveDatabase: urlRef)
            }
            if #available(iOS 13, *) {
                completion(true)
            } else {
                completion(false) 
            }
            completion(true)
        }
        deleteAction.backgroundColor = UIColor.destructiveTint
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    private func showActions(for indexPath: IndexPath) {
        let urlRef = databaseRefs[indexPath.row]
        let isInternalFile = urlRef.location.isInternal
        let deleteAction = UIAlertAction(
            title: isInternalFile ? LString.actionDeleteFile : LString.actionRemoveFile,
            style: .destructive,
            handler: { [weak self] _ in
                guard let self = self else { return }
                if isInternalFile {
                    self.delegate?.databaseChooser(self, shouldDeleteDatabase: urlRef)
                } else {
                    self.delegate?.databaseChooser(self, shouldRemoveDatabase: urlRef)
                }
            }
        )
        let cancelAction = UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil)
        
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        menu.addAction(deleteAction)
        menu.addAction(cancelAction)
        
        let pa = PopoverAnchor(tableView: tableView, at: indexPath)
        if let popover = menu.popoverPresentationController {
            pa.apply(to: popover)
        }
        present(menu, animated: true)
    }
}
