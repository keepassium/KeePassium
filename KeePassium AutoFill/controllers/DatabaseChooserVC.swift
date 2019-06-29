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
    func databaseChooserShouldAddDatabase(_ sender: DatabaseChooserVC)
    func databaseChooser(_ sender: DatabaseChooserVC, didSelectDatabase urlRef: URLReference)
    func databaseChooser(_ sender: DatabaseChooserVC, shouldDeleteDatabase urlRef: URLReference)
    func databaseChooser(_ sender: DatabaseChooserVC, shouldRemoveDatabase urlRef: URLReference)
    func databaseChooser(_ sender: DatabaseChooserVC, shouldShowInfoForDatabase urlRef: URLReference)
}

class DatabaseChooserVC: UITableViewController, Refreshable {
    private enum CellID {
        static let fileItem = "FileItemCell"
        static let noFiles = "NoFilesCell"
    }
    
    weak var delegate: DatabaseChooserDelegate?
    
    private var databaseRefs: [URLReference] = []

    private let fileInfoReloader = FileInfoReloader()

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
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
    
    @objc func refresh() {
        databaseRefs = FileKeeper.shared.getAllReferences(
            fileType: .database,
            includeBackup: Settings.current.isBackupFilesVisible)
        fileInfoReloader.reload(databaseRefs) { [weak self] in
            guard let self = self else { return }
            self.sortFileList()
            if self.refreshControl?.isRefreshing ?? false {
                self.refreshControl?.endRefreshing()
            }
        }
    }
    
    fileprivate func sortFileList() {
        let fileSortOrder = Settings.current.filesSortOrder
        databaseRefs.sort { return fileSortOrder.compare($0, $1) }
        tableView.reloadData()
    }
    
    
    @IBAction func didPressCancel(_ sender: Any) {
        Watchdog.shared.restart()
        delegate?.databaseChooserShouldCancel(self)
    }
    
    @IBAction func didPressAddDatabase(_ sender: Any) {
        Watchdog.shared.restart()
        delegate?.databaseChooserShouldAddDatabase(self)
    }
    
    @objc func didLongPressTableView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        let point = gestureRecognizer.location(in: tableView)
        guard gestureRecognizer.state == .began,
            let indexPath = tableView.indexPathForRow(at: point),
            tableView(tableView, canEditRowAt: indexPath),
            let cell = tableView.cellForRow(at: indexPath) else { return }
        cell.demoShowEditActions(lastActionColor: UIColor.destructiveTint)
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

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard databaseRefs.count > 0 else {
            let cell = tableView.dequeueReusableCell(withIdentifier: CellID.noFiles, for: indexPath)
            return cell
        }
        
        let cell = tableView
            .dequeueReusableCell(withIdentifier: CellID.fileItem, for: indexPath)
            as! DatabaseFileListCell
        cell.urlRef = databaseRefs[indexPath.row]
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
        editActionsForRowAt indexPath: IndexPath
        ) -> [UITableViewRowAction]?
    {
        Watchdog.shared.restart()
        guard databaseRefs.count > 0 else { return nil }
        
        let urlRef = databaseRefs[indexPath.row]
        let isInternalFile = urlRef.location.isInternal
        let deleteAction = UITableViewRowAction(
            style: .destructive,
            title: isInternalFile ? LString.actionDeleteFile : LString.actionRemoveFile)
        {
            [weak self] (_,_) in
            guard let _self = self else { return }
            _self.setEditing(false, animated: true)
            if isInternalFile {
                _self.delegate?.databaseChooser(_self, shouldDeleteDatabase: urlRef)
            } else {
                _self.delegate?.databaseChooser(_self, shouldRemoveDatabase: urlRef)
            }
        }
        deleteAction.backgroundColor = UIColor.destructiveTint
        
        return [deleteAction]
    }
}
