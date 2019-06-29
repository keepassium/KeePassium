//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol KeyFileChooserDelegate: class {
    func onKeyFileSelected(urlRef: URLReference?)
}

class ChooseKeyFileVC: UITableViewController, Refreshable {
    private enum CellID {
        static let passwordOnly = "PasswordOnlyCell"
        static let keyFile = "FileCell"
    }
    
    public weak var delegate: KeyFileChooserDelegate?

    private var urlRefs: [URLReference] = []

    private var fileKeeperNotifications: FileKeeperNotifications!
    
    private let fileInfoReloader = FileInfoReloader()

    static func make(
        popoverSourceView: UIView,
        delegate: KeyFileChooserDelegate?) -> UIViewController
    {
        let vc = ChooseKeyFileVC.instantiateFromStoryboard()
        vc.delegate = delegate
        
        let navVC = UINavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .popover
        if let popover = navVC.popoverPresentationController {
            popover.sourceView = popoverSourceView
            popover.sourceRect = popoverSourceView.bounds
            popover.delegate = vc
        }
        return navVC
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fileKeeperNotifications = FileKeeperNotifications(observer: self)
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        self.refreshControl = refreshControl
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(didLongPressTableView))
        tableView.addGestureRecognizer(longPressGestureRecognizer)
        
        refresh()
        self.clearsSelectionOnViewWillAppear = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fileKeeperNotifications.startObserving()
        if FileKeeper.shared.hasPendingFileOperations {
            processPendingFileOperations()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        fileKeeperNotifications.stopObserving()
        super.viewDidDisappear(animated)
    }

    
    @objc func refresh() {
        urlRefs = FileKeeper.shared.getAllReferences(fileType: .keyFile, includeBackup: false)
        let navBarHeight = navigationController?.navigationBar.frame.height ?? 0.0
        let preferredHeight = 44.0 * CGFloat(tableView.numberOfRows(inSection: 0)) + navBarHeight 
        preferredContentSize = CGSize(width: 300, height: preferredHeight)

        fileInfoReloader.reload(urlRefs) { [weak self] in
            guard let self = self else { return }
            self.sortFileList()
            if self.refreshControl?.isRefreshing ?? false {
                self.refreshControl?.endRefreshing()
            }
        }
    }
    
    fileprivate func sortFileList() {
        let fileSortOrder = Settings.current.filesSortOrder
        self.urlRefs.sort { return fileSortOrder.compare($0, $1) }
        tableView.reloadData()
    }
    
    
    @IBAction func didPressImportButton(_ sender: Any) {
        importKeyFile()
    }
    
    func didPressDeleteKeyFile(at indexPath: IndexPath) {
        let urlRef = urlRefs[indexPath.row - 1]
        let fileInfo = urlRef.getInfo()
        if fileInfo.hasError {
            deleteKeyFile(urlRef: urlRef)
        } else {
            let confirmDeletionAlert = UIAlertController.make(
                title: fileInfo.fileName,
                message: LString.confirmKeyFileDeletion,
                cancelButtonTitle: LString.actionCancel)
            let deleteAction = UIAlertAction(title: LString.actionDelete, style: .destructive)
            {
                [unowned self] _ in
                self.deleteKeyFile(urlRef: urlRef)
            }
            confirmDeletionAlert.addAction(deleteAction)
            present(confirmDeletionAlert, animated: true, completion: nil)
        }
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
        return 1 + urlRefs.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        if indexPath.row == 0 {
            return tableView.dequeueReusableCell(
                withIdentifier: CellID.passwordOnly,
                for: indexPath)
        }
        
        let fileInfo = urlRefs[indexPath.row - 1].getInfo()

        let cell = tableView.dequeueReusableCell(withIdentifier: CellID.keyFile, for: indexPath)
        cell.textLabel?.text = fileInfo.fileName
        guard !fileInfo.hasError else {
            cell.detailTextLabel?.text = fileInfo.errorMessage
            cell.detailTextLabel?.textColor = UIColor.errorMessage
            return cell
        }
        
        if let lastModifiedDate = fileInfo.modificationDate  {
            let dateString = DateFormatter.localizedString(
                from: lastModifiedDate,
                dateStyle: .long,
                timeStyle: .medium)
            cell.detailTextLabel?.text = dateString
        } else {
            cell.detailTextLabel?.text = nil
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        dismissPopover()
        if row == 0 {
            Diag.debug("Selected No Key File")
            delegate?.onKeyFileSelected(urlRef: nil)
        } else {
            Diag.debug("Selected a key file")
            let selectedRef = urlRefs[row - 1]
            delegate?.onKeyFileSelected(urlRef: selectedRef)
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        accessoryButtonTappedForRowWith indexPath: IndexPath)
    {
        let urlRef = urlRefs[indexPath.row - 1]
        guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
        let databaseInfoVC = FileInfoVC.make(urlRef: urlRef, popoverSource: cell)
        present(databaseInfoVC, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row > 0
    }
    
    override func tableView(
        _ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath
        ) -> [UITableViewRowAction]?
    {
        let deleteAction = UITableViewRowAction(
            style: .destructive,
            title: LString.actionDelete)
        {
            [unowned self] _,_ in
            self.setEditing(false, animated: true)
            self.didPressDeleteKeyFile(at: indexPath)
        }
        return [deleteAction]
    }


    private func importKeyFile() {
        let picker = UIDocumentPickerViewController(documentTypes: FileType.keyFileUTIs, in: .open)
        picker.delegate = self
        picker.modalPresentationStyle = .overFullScreen
        present(picker, animated: true, completion: nil)
    }

    private func deleteKeyFile(urlRef: URLReference) {
        do {
            try FileKeeper.shared.deleteFile(
                urlRef,
                fileType: .keyFile,
                ignoreErrors: urlRef.info.hasError)
            Settings.current.forgetKeyFile(urlRef)
            refresh()
        } catch {
            let errorAlert = UIAlertController.make(
                title: LString.titleError,
                message: error.localizedDescription)
            present(errorAlert, animated: true, completion: nil)
        }
    }
}

extension ChooseKeyFileVC: UIPopoverPresentationControllerDelegate {

    func presentationController(
        _ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle
        ) -> UIViewController?
    {
        if style != .popover {
            let navVC = controller.presentedViewController as? UINavigationController
            let cancelButton = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(dismissPopover))
            navVC?.topViewController?.navigationItem.leftBarButtonItem = cancelButton
        }
        return nil // "keep existing"
    }
    
    @objc func dismissPopover() {
        dismiss(animated: true, completion: nil)
    }
}

extension ChooseKeyFileVC: UIDocumentPickerDelegate {
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL])
    {
        guard let url = urls.first else { return }
        if FileType.isDatabaseFile(url: url) {
            let alertVC = UIAlertController.make(
                title: LString.titleWarning,
                message: LString.dontUseDatabaseAsKeyFile,
                cancelButtonTitle: LString.actionOK)
            present(alertVC, animated: true, completion: nil)
            return
        }
        
        let fileKeeper = FileKeeper.shared
        fileKeeper.prepareToAddFile(url: url, mode: .import)
        fileKeeper.processPendingOperations(
            success: {
                [weak self] (addedRef) in
                self?.refresh()
            },
            error: {
                [weak self] (error) in
                guard let _self = self else { return }
                let alert = UIAlertController.make(
                    title: LString.titleImportError,
                    message: error.localizedDescription)
                _self.present(alert, animated: true, completion: nil)
            }
        )
    }
}

extension ChooseKeyFileVC: FileKeeperObserver {
    func fileKeeper(didAddFile urlRef: URLReference, fileType: FileType) {
        guard fileType == .keyFile else { return }
        refresh()
    }
    
    func fileKeeperHasPendingOperation() {
        processPendingFileOperations()
    }
    
    func fileKeeper(didRemoveFile urlRef: URLReference, fileType: FileType) {
        guard fileType == .keyFile else { return }
        refresh()
    }
    
    private func processPendingFileOperations() {
        FileKeeper.shared.processPendingOperations(
            success: nil,
            error: {
                [weak self] (error) in
                guard let _self = self else { return }
                let alert = UIAlertController.make(
                    title: LString.titleError,
                    message: error.localizedDescription)
                _self.present(alert, animated: true, completion: nil)
            }
        )
    }
}
