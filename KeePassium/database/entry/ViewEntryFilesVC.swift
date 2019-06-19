//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class ViewEntryFilesVC: UITableViewController, Refreshable {
    private enum CellID {
        static let fileItem = "FileItemCell"
        static let noFiles = "NoFilesCell"
        static let addFile = "AddFileCell"
    }
    
    private weak var entry: Entry?
    private var editButton: UIBarButtonItem! 
    private var isHistoryMode = false
    private var canAddFiles: Bool { return !isHistoryMode }
    private var databaseManagerNotifications: DatabaseManagerNotifications!
    private var progressViewHost: ProgressViewHost?
    private var exportController: UIDocumentInteractionController!

    static func make(
        with entry: Entry?,
        historyMode: Bool,
        progressViewHost: ProgressViewHost?
    ) -> ViewEntryFilesVC {
        let viewEntryFilesVC = ViewEntryFilesVC.instantiateFromStoryboard()
        viewEntryFilesVC.entry = entry
        viewEntryFilesVC.isHistoryMode = historyMode
        viewEntryFilesVC.progressViewHost = progressViewHost
        return viewEntryFilesVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        editButton = UIBarButtonItem(
            barButtonSystemItem: .edit,
            target: self,
            action: #selector(didPressEdit))
        navigationItem.rightBarButtonItem = isHistoryMode ? nil : editButton
        
        databaseManagerNotifications = DatabaseManagerNotifications(observer: self)
        
        exportController = UIDocumentInteractionController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }
    
    func refresh() {
        tableView.reloadData()
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1 
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let entry = entry else { return 0 }
        let contentCellCount = max(1, entry.attachments.count) // at least one for "Nothing here"
        if canAddFiles {
            return contentCellCount + 1 // +1 for "Add File"
        } else {
            return contentCellCount
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        guard let entry = entry else { fatalError() }
        guard entry.attachments.count > 0 else {
            switch indexPath.row {
            case 0:
                return tableView.dequeueReusableCell(withIdentifier: CellID.noFiles, for: indexPath)
            case 1:
                assert(canAddFiles)
                return tableView.dequeueReusableCell(withIdentifier: CellID.addFile, for: indexPath)
            default:
                fatalError()
            }
        }
        
        if indexPath.row < entry.attachments.count {
            let att = entry.attachments[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: CellID.fileItem, for: indexPath)
            cell.textLabel?.text = att.name
            cell.detailTextLabel?.text = ByteCountFormatter.string(
                fromByteCount: Int64(att.size),
                countStyle: .file
            )
            return cell
        } else {
            assert(canAddFiles)
            return tableView.dequeueReusableCell(withIdentifier: CellID.addFile, for: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let attachments = entry?.attachments else { return }
        guard let sourceCell = tableView.cellForRow(at: indexPath) else { return }
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let row = indexPath.row
        if row < attachments.count {
            if tableView.isEditing {
                didPressRenameAttachment(at: indexPath)
            } else {
                didPressExportAttachment(attachments[row], sourceCell: sourceCell)
            }
        } else {
            assert(canAddFiles)
            didPressAddAttachment()
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        guard let attachments = entry?.attachments else { return .none }
        let row = indexPath.row
        guard attachments.count > 0 else {
            switch row {
            case 0: // "nothing here"
                return .none
            case 1: // "add file"
                assert(canAddFiles)
                return .insert
            default:
                fatalError()
            }
        }
        
        if row < attachments.count {
            return .delete
        } else {
            assert(canAddFiles)
            return .insert
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let attachments = entry?.attachments else { return false }
        guard !isHistoryMode else { return false }
        let row = indexPath.row
        if row == 0 && attachments.isEmpty {
            return false
        } else {
            return true
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath
        ) -> [UITableViewRowAction]?
    {
        let deleteAction = UITableViewRowAction(
            style: .destructive,
            title: LString.actionDeleteFile,
            handler: { [weak self] (rowAction, indexPath) in
                self?.didPressDeleteAttachment(at: indexPath)
            }
        )
        
        return [deleteAction]
    }
    
    
    @objc func didPressEdit() {
        tableView.setEditing(!tableView.isEditing, animated: true)
    }
    

    private func didPressExportAttachment(_ att: Attachment, sourceCell: UITableViewCell) {
        
        guard let encodedAttName = att.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let fileName = URL(string: encodedAttName)?.lastPathComponent else
        {
            Diag.warning("Failed to create a URL from attachment name [att.name: \(att.name)]")
            let alert = UIAlertController.make(title: LString.titleExportError, message: nil)
            present(alert, animated: true, completion: nil)
            return
        }
        
        do {
            let exportFileURL = (try TemporaryFileURL(fileName: fileName)).url
            let uncompressedBytes = att.isCompressed ? try att.data.gunzipped() : att.data
            try uncompressedBytes.write(to: exportFileURL, options: [.completeFileProtection])
            exportController.url = exportFileURL
            if let icon = exportController.icons.first {
                sourceCell.imageView?.image = icon
            }
            exportController.delegate = self
            Diag.info("Will present attachment")
            if !exportController.presentPreview(animated: true) {
                Diag.verbose("Preview not available, showing menu")
                exportController.presentOptionsMenu(
                    from: sourceCell.frame,
                    in: tableView,
                    animated: true)
            }
        } catch {
            Diag.error("Failed to write attachment [reason: \(error.localizedDescription)]")
            let alert = UIAlertController.make(
                title: LString.titleExportError,
                message: error.localizedDescription)
            present(alert, animated: true, completion: nil)
        }
    }
    
    private func didPressAddAttachment() {
        guard let entry = entry else { return }
        
        let capacityOK = entry.isSupportsMultipleAttachments || entry.attachments.isEmpty
        if capacityOK {
            addAttachment()
            return
        }
        
        let replacementAlert = UIAlertController(
            title: NSLocalizedString("Replace existing attachment?", comment: "Confirmation message to replace an existing entry attachment with a new one."),
            message: NSLocalizedString("This database supports only one attachment per entry, and there is already one. ", comment: "Explanation for replacing the only attachment of KeePass1 entry"),
            preferredStyle: .alert)
        let cancelAction = UIAlertAction(
            title: LString.actionCancel,
            style: .cancel,
            handler: nil)
        let replaceAction = UIAlertAction(
            title: LString.actionReplace,
            style: .destructive,
            handler: { [weak self] _ in
                Diag.debug("Will replace an existing attachment")
                self?.addAttachment()
            }
        )
        replacementAlert.addAction(cancelAction)
        replacementAlert.addAction(replaceAction)
        present(replacementAlert, animated: true, completion: nil)
    }
    
    private func didPressRenameAttachment(at indexPath: IndexPath) {
        print("did press Rename Attachment")
    }
    
    private func didPressDeleteAttachment(at indexPath: IndexPath) {
        guard let entry = entry else { return }
        entry.backupState()
        entry.modified()
        entry.attachments.remove(at: indexPath.row)
        Diag.info("Attachment deleted OK")
        
        if entry.attachments.isEmpty {
            tableView.reloadRows(at: [indexPath], with: .automatic)
        } else {
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        applyChangesAndSaveDatabase()
    }
    
    
    private func addAttachment() {
        let picker = UIDocumentPickerViewController(
            documentTypes: FileType.attachmentUTIs,
            in: .import)
        picker.modalPresentationStyle = .formSheet
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }

    
    private func applyChangesAndSaveDatabase() {
        guard let entry = entry else { return }
        entry.modified()
        databaseManagerNotifications.startObserving()
        DatabaseManager.shared.startSavingDatabase()
    }
}

extension ViewEntryFilesVC: DatabaseManagerObserver {
    
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        progressViewHost?.showProgressView(
            title: LString.databaseStatusSaving,
            allowCancelling: true)
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        progressViewHost?.updateProgressView(with: progress)
    }
    
    func databaseManager(didSaveDatabase urlRef: URLReference) {
        databaseManagerNotifications.stopObserving()
        progressViewHost?.hideProgressView()
        if let entry = entry {
            EntryChangeNotifications.post(entryDidChange: entry)
        }
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        databaseManagerNotifications.stopObserving()
        progressViewHost?.hideProgressView()
    }

    func databaseManager(
        database urlRef: URLReference,
        savingError message: String,
        reason: String?)
    {
        databaseManagerNotifications.stopObserving()
        progressViewHost?.hideProgressView()
        
        let errorAlert = UIAlertController.make(
            title: message,
            message: reason,
            cancelButtonTitle: LString.actionDismiss)
        let showDetailsAction = UIAlertAction(title: LString.actionShowDetails, style: .default)
        {
            [weak self] _ in
            let diagnosticsVC = ViewDiagnosticsVC.instantiateFromStoryboard()
            self?.present(diagnosticsVC, animated: true, completion: nil)
        }
        errorAlert.addAction(showDetailsAction)
        present(errorAlert, animated: true, completion: nil)
    }
}

extension ViewEntryFilesVC: UIDocumentPickerDelegate {
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL])
    {
        guard let url = urls.first else { return }
        
        progressViewHost?.showProgressView(
            title: NSLocalizedString("Loading attachment file", comment: "Status message: loading file to be attached to an entry"),
            allowCancelling: false)
        
        let doc = FileDocument(fileURL: url)
        doc.open(
            successHandler: { [weak self] in
                self?.addAttachment(name: url.lastPathComponent, data: doc.data)
            },
            errorHandler: { [weak self] (error) in
                Diag.error("Failed to open source file [message: \(error.localizedDescription)]")
                self?.progressViewHost?.hideProgressView() 
                let alert = UIAlertController.make(
                    title: LString.titleError,
                    message: error.localizedDescription,
                    cancelButtonTitle: LString.actionDismiss)
                self?.present(alert, animated: true, completion: nil)
            }
        )
    }

    private func addAttachment(name: String, data: ByteArray) {
        guard let entry = entry, let database = entry.database else { return }
        entry.backupState()
        entry.modified()

        let newAttachment = database.makeAttachment(name: name, data: data)
        if !entry.isSupportsMultipleAttachments {
            entry.attachments.removeAll()
        }
        entry.attachments.append(newAttachment)
        Diag.info("Attachment added OK")

        tableView.reloadSections([0], with: .automatic) 
        EntryChangeNotifications.post(entryDidChange: entry)
        
        applyChangesAndSaveDatabase()
    }
}

extension ViewEntryFilesVC: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController
        ) -> UIViewController
    {
        return navigationController! 
    }
}
