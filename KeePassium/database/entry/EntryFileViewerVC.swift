//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol EntryFileViewerDelegate: AnyObject {
    func canEditFiles(in viewController: EntryFileViewerVC) -> Bool
    
    func shouldReplaceExistingFile(in viewController: EntryFileViewerVC) -> Bool
    
    func didPressAddFile(in viewController: EntryFileViewerVC)
    func didRenameFile(
        _ attachment: Attachment,
        to newName: String,
        in viewController: EntryFileViewerVC
    )
    func didPressViewFile(
        _ attachment: Attachment,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFileViewerVC
    )
    func didPressDeleteFile(_ attachment: Attachment, in viewController: EntryFileViewerVC)
}

final class EntryFileViewerVC: UITableViewController , Refreshable {
    private enum CellID {
        static let fileItem = "FileItemCell"
        static let noFiles = "NoFilesCell"
        static let addFile = "AddFileCell"
    }
    
    weak var delegate: EntryFileViewerDelegate?
     
    private var attachments = [Attachment]()
    private var editButton: UIBarButtonItem! 

    private var canAddFiles: Bool {
        return canEditFiles
    }
    private var canEditFiles: Bool {
        return delegate?.canEditFiles(in: self) ?? false
    }
        
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        editButton = UIBarButtonItem(
            title: LString.actionEdit,
            style: .plain,
            target: self,
            action: #selector(didPressEdit))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        tableView.isEditing = false
        refresh()
    }
    
    public func setAttachments(_ attachments: [Attachment], animated: Bool) {
        self.attachments = attachments
        refresh(animated: animated)
    }
    
    func refresh() {
        refresh(animated: false)
    }
    
    func refresh(animated: Bool) {
        guard isViewLoaded else { return }
        editButton.isEnabled = canEditFiles
        navigationItem.rightBarButtonItem = canEditFiles ? editButton : nil
        
        if animated {
            tableView.reloadSections([0], with: .automatic) 
        } else {
            tableView.reloadData()
        }
        
        if tableView.isEditing {
            editButton.title = LString.actionDone
            editButton.style = .done
        } else {
            editButton.title = LString.actionEdit
            editButton.style = .plain
        }
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var contentCellCount = max(1, attachments.count) // at least one for "Nothing here"
        if canAddFiles {
            contentCellCount += 1 // +1 for "Add File"
        }
        return contentCellCount
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        if attachments.isEmpty {
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
        
        if indexPath.row < attachments.count {
            let att = attachments[indexPath.row]
            return makeAttachmentCell(att, for: indexPath)
        } else {
            assert(canAddFiles)
            return tableView.dequeueReusableCell(withIdentifier: CellID.addFile, for: indexPath)
        }
    }
    
    private func makeAttachmentCell(
        _ attachment: Attachment,
        for indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CellID.fileItem, for: indexPath)
        cell.imageView?.image = attachment.getSystemIcon()
        cell.textLabel?.text = attachment.name
        cell.detailTextLabel?.text = ByteCountFormatter.string(
            fromByteCount: Int64(attachment.size),
            countStyle: .file
        )
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sourceCell = tableView.cellForRow(at: indexPath) else { return }
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let row = indexPath.row
        if row < attachments.count {
            let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
            if tableView.isEditing {
                didPressRenameAttachment(at: indexPath)
            } else {
                delegate?.didPressViewFile(attachments[row], at: popoverAnchor, in: self)
            }
        } else {
            didPressAddAttachment()
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
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
        guard canEditFiles else {
            return false
        }
        
        let row = indexPath.row
        if row == 0 && attachments.isEmpty {
            return false
        } else {
            return true
        }
    }
    
    
    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let attachment = attachments[indexPath.row]
        let deleteAction = UIContextualAction(
            style: .destructive,
            title: LString.actionDeleteFile,
            handler: { [weak self] (action, sourceView, completion) in
                self?.didPressDeleteAttachment(attachment)
                if #available(iOS 13, *) {
                    completion(true)
                } else {
                    completion(false) 
                }
            }
        )
        deleteAction.image = UIImage.get(.trash)
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath)
    {
        if editingStyle == .insert {
            didPressAddAttachment()
        }
    }
    
    @objc func didPressEdit() {
        guard canEditFiles else {
            assertionFailure()
            return
        }
        tableView.setEditing(!tableView.isEditing, animated: true)
        refresh()
    }
}

private extension EntryFileViewerVC {
    
    func didPressAddAttachment() {
        guard canAddFiles else {
            assertionFailure()
            return
        }
        
        let isReplacementRequired = delegate?.shouldReplaceExistingFile(in: self) ?? true
        guard isReplacementRequired else {
            delegate?.didPressAddFile(in: self)
            return
        }
        
        let replacementAlert = UIAlertController(
            title: NSLocalizedString(
                "[Entry/Files/Add] Replace existing attachment?",
                value: "Replace existing attachment?",
                comment: "Confirmation message to replace an existing entry attachment with a new one."),
            message: NSLocalizedString(
                "[Entry/Files/Add] This database supports only one attachment per entry, and there is already one.",
                value: "This database supports only one attachment per entry, and there is already one.",
                comment: "Explanation for replacing the only attachment of KeePass1 entry"),
            preferredStyle: .alert)
        replacementAlert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        replacementAlert.addAction(title: LString.actionReplace, style: .destructive) {
            [weak self] _ in
            guard let self = self else { return }
            Diag.debug("Will replace an existing attachment")
            self.delegate?.didPressAddFile(in: self)
        }
        present(replacementAlert, animated: true, completion: nil)
    }
    
    func didPressRenameAttachment(at indexPath: IndexPath) {
        let attachment = attachments[indexPath.row]
        
        let renameController = UIAlertController(
            title: NSLocalizedString(
                "[Entry/Files/Rename/title] Rename File",
                value: "Rename File",
                comment: "Title of a dialog for renaming an attached file"),
            message: nil,
            preferredStyle: .alert)
        renameController.addTextField { (textField) in
            textField.text = attachment.name
        }
        renameController.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        renameController.addAction(title: LString.actionRename, style: .default) {
            [weak renameController, weak self] (action) in
            guard let self = self,
                  let textField = renameController?.textFields?.first,
                  let newName = textField.text,
                  newName.isNotEmpty
            else {
                Diag.warning("New attachment name is empty, ignoring")
                return
            }
            self.delegate?.didRenameFile(attachment, to: newName, in: self)
        }
        present(renameController, animated: true, completion: nil)
    }
    
    private func didPressDeleteAttachment(_ attachment: Attachment) {
        delegate?.didPressDeleteFile(attachment, in: self)
    }
}
