//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol KeyFileChooserDelegate: class {
    func didPressAddKeyFile(in keyFileChooser: KeyFileChooserVC, popoverAnchor: PopoverAnchor)
    func didSelectFile(in keyFileChooser: KeyFileChooserVC, urlRef: URLReference?)
    func didPressFileInfo(in keyFileChooser: KeyFileChooserVC, for urlRef: URLReference)
}

class KeyFileChooserVC: UITableViewController, Refreshable {
    private enum CellID {
        static let noKeyFile = "NoKeyFileCell"
        static let keyFile = "KeyFileCell"
    }

    @IBOutlet weak var addKeyFileBarButton: UIBarButtonItem!
    
    weak var delegate: KeyFileChooserDelegate?

    var keyFileRefs = [URLReference]()
    
    private let fileInfoReloader = FileInfoReloader()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        self.refreshControl = refreshControl
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(didLongPressTableView))
        tableView.addGestureRecognizer(longPressGestureRecognizer)
        
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

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath)
        -> UITableViewCell
    {
        guard indexPath.row != 0 else {
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
        let keyFileRef = keyFileRefs[indexPath.row - 1]
        cell.showInfo(from: keyFileRef)
        cell.isAnimating = keyFileRef.isRefreshingInfo
        cell.accessoryTapHandler = { [weak self, indexPath] cell in
            guard let self = self else { return }
            self.tableView(self.tableView, accessoryButtonTappedForRowWith: indexPath)
        }
        return cell
    }
    
    override func tableView(
        _ tableView: UITableView,
        accessoryButtonTappedForRowWith indexPath: IndexPath)
    {
        let urlRef = keyFileRefs[indexPath.row - 1]
        delegate?.didPressFileInfo(in: self, for: urlRef)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row > 0
    }

    override func tableView(
        _ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath
        ) -> [UITableViewRowAction]?
    {
        let removeAction = UITableViewRowAction(
            style: .destructive,
            title: LString.actionRemoveFile)
        {
            [unowned self] (rowAction, indexPath) in
            self.setEditing(false, animated: true)
            self.didPressRemoveKeyFile(at: indexPath)
        }
        return [removeAction]
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row > 0 else {
            delegate?.didSelectFile(in: self, urlRef: nil)
            return
        }
        
        let selectedFileIndex = indexPath.row - 1
        delegate?.didSelectFile(in: self, urlRef: keyFileRefs[selectedFileIndex])
    }
    
    @IBAction func didPressAddKeyFile(_ sender: Any) {
        let popoverAnchor = PopoverAnchor(barButtonItem: addKeyFileBarButton)
        delegate?.didPressAddKeyFile(in: self, popoverAnchor: popoverAnchor)
    }
    
    func didPressRemoveKeyFile(at indexPath: IndexPath) {
        let fileIndex = indexPath.row - 1
        let fileRef = keyFileRefs[fileIndex]
        FileKeeper.shared.removeExternalReference(fileRef, fileType: .keyFile)
        refresh()
    }
    
    @objc func didLongPressTableView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        let point = gestureRecognizer.location(in: tableView)
        guard gestureRecognizer.state == .began,
            let indexPath = tableView.indexPathForRow(at: point),
            tableView(tableView, canEditRowAt: indexPath) else { return }
        showActions(for: indexPath)
    }
    
    private func showActions(for indexPath: IndexPath) {
        let removeAction = UIAlertAction(
            title: LString.actionRemoveFile,
            style: .destructive,
            handler: { [weak self] _ in
                guard let self = self else { return }
                self.didPressRemoveKeyFile(at: indexPath)
            }
        )
        let cancelAction = UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil)
        
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        menu.addAction(removeAction)
        menu.addAction(cancelAction)
        
        let pa = PopoverAnchor(tableView: tableView, at: indexPath)
        if let popover = menu.popoverPresentationController {
            pa.apply(to: popover)
        }
        present(menu, animated: true)
    }
}
