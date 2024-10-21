//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UniformTypeIdentifiers

protocol EntryFileViewerDelegate: AnyObject {
    func shouldReplaceExistingFile(in viewController: EntryFileViewerVC) -> Bool

    func didPressAddFile(at popoverAnchor: PopoverAnchor, in viewController: EntryFileViewerVC)
    func didPressAddPhoto(
        fromCamera: Bool,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFileViewerVC)

    func didPressSave(
        file attachment: Attachment,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFileViewerVC
    )
    func didPressRename(
        file attachment: Attachment,
        to newName: String,
        in viewController: EntryFileViewerVC
    )
    func didPressView(
        file attachment: Attachment,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFileViewerVC
    )
    func didPressViewAll(
        files attachments: [Attachment],
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFileViewerVC
    )
    func didPressDelete(files attachments: [Attachment], in viewController: EntryFileViewerVC)
}

final class EntryFileViewerVC: TableViewControllerWithContextActions, Refreshable {
    private enum CellID {
        static let fileItem = "FileItemCell"
        static let noFiles = "NoFilesCell"
        static let addFile = "AddFileCell"
    }

    weak var delegate: EntryFileViewerDelegate?

    private var attachments = [Attachment]()

    private var canEditFiles = false

    private var previewFilesBarButton: UIBarButtonItem! 
    private var addFileBarButton: UIBarButtonItem! 
    private var deleteFilesBarButton: UIBarButtonItem! 


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = editButtonItem
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.dragInteractionEnabled = true
        tableView.dragDelegate = self

        previewFilesBarButton = UIBarButtonItem(
            image: .symbol(.rectangleStack),
            style: .plain,
            target: self,
            action: #selector(didPressViewAll(_:)))
        previewFilesBarButton.title = LString.actionPreviewAttachments
        previewFilesBarButton.accessibilityLabel = LString.actionPreviewAttachments

        addFileBarButton = UIBarButtonItem(systemItem: .add)
        addFileBarButton.accessibilityLabel = LString.actionAddAttachment
        addFileBarButton.menu = makeAddAttachmentMenu()

        deleteFilesBarButton = UIBarButtonItem(
            title: LString.actionDelete, 
            image: nil,
            primaryAction: nil,
            menu: nil 
        )
        toolbarItems = [
            previewFilesBarButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            addFileBarButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            deleteFilesBarButton
        ]
        updateToolbar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        setEditing(false, animated: false)
    }

    public func setContents(_ attachments: [Attachment], canEditEntry: Bool, animated: Bool) {
        self.attachments = attachments
        self.canEditFiles = canEditEntry
        refresh(animated: animated)
    }

    func refresh() {
        refresh(animated: false)
    }

    func refresh(animated: Bool) {
        editButtonItem.isEnabled = canEditFiles
        if animated {
            tableView.reloadSections([0], with: .automatic) 
        } else {
            tableView.reloadData()
        }
        updateToolbar()
    }

    private func makeAddAttachmentMenu() -> UIMenu {
        let chooseFileAction = UIAction(
            title: LString.actionChooseFile,
            image: .symbol(.folder)
        ) { [weak self] action in
            self?.didPressAddFileAttachment(action)
        }
        let choosePhotoAction = UIAction(
            title: LString.actionChoosePhoto,
            image: .symbol(.photo)
        ) { [weak self] _ in
            self?.didPressAddPhotoAttachment(fromCamera: false)
        }
        let takePhotoAction = UIAction(
            title: LString.actionTakePhoto,
            image: .symbol(.camera)
        ) { [weak self] _ in
            self?.didPressAddPhotoAttachment(fromCamera: true)
        }

        let menu = UIMenu.make(
            reverse: true,
            children: [
                chooseFileAction,
                choosePhotoAction,
                takePhotoAction
            ]
        )
        return menu
    }


    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(1, attachments.count) // at least one for "Nothing here"
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        if attachments.isEmpty {
            return tableView.dequeueReusableCell(withIdentifier: CellID.noFiles, for: indexPath)
        }

        guard indexPath.row < attachments.count else {
            assertionFailure()
            return tableView.dequeueReusableCell(withIdentifier: CellID.noFiles, for: indexPath)
        }
        let att = attachments[indexPath.row]
        return setupAttachmentCell(att, for: indexPath)
    }

    private func setupAttachmentCell(
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
        guard indexPath.row < attachments.count else {
            return // skip "empty list" row
        }

        if isEditing {
            updateToolbar()
        } else {
            let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
            let attachment = attachments[indexPath.row]
            delegate?.didPressView(file: attachment, at: popoverAnchor, in: self)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard indexPath.row < attachments.count else {
            return
        }
        if isEditing {
            updateToolbar()
        }
    }

    override func tableView(
        _ tableView: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        assert(canEditFiles)
        if attachments.isEmpty {
            return .none
        }
        guard indexPath.row < attachments.count else {
            assertionFailure()
            return .none
        }
        return .delete
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard canEditFiles else {
            return false
        }

        let isFileRow = !attachments.isEmpty && (indexPath.row < attachments.count)
        return isFileRow
    }


    override func getContextActionsForRow(
        at indexPath: IndexPath,
        forSwipe: Bool
    ) -> [ContextualAction] {
        guard canEditFiles else {
            return []
        }
        guard indexPath.row < attachments.count else {
            return []
        }
        let deleteAction = ContextualAction(
            title: LString.actionDeleteFile,
            imageName: .trash,
            style: .destructive,
            handler: { [weak self] in
                self?.didPressDeleteAttachment(at: indexPath)
            }
        )

        let renameFileAction = ContextualAction(
            title: LString.actionRename,
            imageName: .pencil,
            style: .default,
            handler: { [weak self] in
                self?.didPressRenameAttachment(at: indexPath)
            }
        )

        let saveAsAction = ContextualAction(
            title: LString.actionFileSaveAs,
            imageName: .squareAndArrowDown,
            style: .default,
            handler: { [weak self] in
                self?.didPressSaveAttachment(at: indexPath)
            }
        )
        return [saveAsAction, renameFileAction, deleteAction]
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        assert(canEditFiles)
        didPressDeleteAttachment(at: indexPath)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        assert(canEditFiles || !editing)
        super.setEditing(editing, animated: animated)
        updateToolbar()
    }
}

private extension EntryFileViewerVC {

    @objc private func didPressViewAll(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressViewAll(files: attachments, at: popoverAnchor, in: self)
    }

    @objc private func didPressAddFileAttachment(_ sender: AnyObject) {
        assert(canEditFiles)
        maybeConfirmReplacement(confirmed: { [weak self] in
            guard let self = self else { return }
            let popoverAnchor = PopoverAnchor(barButtonItem: self.addFileBarButton)
            self.delegate?.didPressAddFile(at: popoverAnchor, in: self)
        })
    }

    private func didPressAddPhotoAttachment(fromCamera: Bool) {
        assert(canEditFiles)
        maybeConfirmReplacement(confirmed: { [weak self] in
            guard let self = self else { return }
            let popoverAnchor = PopoverAnchor(barButtonItem: self.addFileBarButton)
            self.delegate?.didPressAddPhoto(fromCamera: fromCamera, at: popoverAnchor, in: self)
        })
    }

    private func maybeConfirmReplacement(confirmed confirmedHandler: @escaping () -> Void) {
        let isReplacementRequired = delegate?.shouldReplaceExistingFile(in: self) ?? true
        guard isReplacementRequired else {
            confirmedHandler()
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
        replacementAlert.addAction(title: LString.actionReplace, style: .destructive) { _ in
            Diag.debug("Will replace an existing attachment")
            confirmedHandler()
        }
        present(replacementAlert, animated: true, completion: nil)
    }

    private func didPressRenameAttachment(at indexPath: IndexPath) {
        assert(canEditFiles)
        let attachment = attachments[indexPath.row]

        let renameController = UIAlertController(
            title: NSLocalizedString(
                "[Entry/Files/Rename/title] Rename File",
                value: "Rename File",
                comment: "Title of a dialog for renaming an attached file"),
            message: nil,
            preferredStyle: .alert)
        renameController.addTextField { textField in
            textField.text = attachment.name
        }
        renameController.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        renameController.addAction(title: LString.actionRename, style: .default) {
            [weak renameController, weak self] _ in 
            guard let self = self,
                  let textField = renameController?.textFields?.first,
                  let newName = textField.text,
                  newName.isNotEmpty
            else {
                Diag.warning("New attachment name is empty, ignoring")
                return
            }
            self.delegate?.didPressRename(file: attachment, to: newName, in: self)
        }
        present(renameController, animated: true, completion: nil)
    }

    private func didPressSaveAttachment(at indexPath: IndexPath) {
        let attachment = attachments[indexPath.row]
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressSave(file: attachment, at: popoverAnchor, in: self)
    }

    private func didPressDeleteAttachment(at indexPath: IndexPath) {
        assert(canEditFiles)
        let attachment = attachments[indexPath.row]
        delegate?.didPressDelete(files: [attachment], in: self)
    }

    private func makeConfirmDeleteSelectionMenu(for button: UIBarButtonItem) -> UIMenu {
        let deleteAction = UIAction(
            title: button.title ?? LString.actionDelete,
            image: .symbol(.trash),
            attributes: [.destructive],
            handler: { [weak self] _ in
                self?.didPressDeleteSelection()
            }
        )
        return UIMenu.make(options: [.destructive], children: [deleteAction])
    }

    private func didPressDeleteSelection() {
        assert(canEditFiles)

        let attachmentsToDelete: [Attachment]
        if let selectedIndexPaths = tableView.indexPathsForSelectedRows {
            Diag.debug("Deleting selected attachments")
            attachmentsToDelete = selectedIndexPaths.map {
                attachments[$0.row]
            }
        } else {
            Diag.debug("Deleting all attachments")
            attachmentsToDelete = attachments
        }
        delegate?.didPressDelete(files: attachmentsToDelete, in: self)
    }

    private func updateToolbar() {
        let hasAttachments = !attachments.isEmpty
        previewFilesBarButton.isEnabled = hasAttachments
        addFileBarButton.isEnabled = canEditFiles
        deleteFilesBarButton.isEnabled = canEditFiles && isEditing && hasAttachments
        if tableView.indexPathsForSelectedRows != nil {
            deleteFilesBarButton.title = LString.actionDelete
        } else {
            deleteFilesBarButton.title = LString.actionDeleteAll
        }
        deleteFilesBarButton.menu = makeConfirmDeleteSelectionMenu(for: deleteFilesBarButton)
    }
}

extension EntryFileViewerVC: UITableViewDragDelegate {
    func tableView(
        _ tableView: UITableView,
        itemsForBeginning session: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        guard indexPath.row < attachments.count else {
            return []
        }

        let attachment = attachments[indexPath.row]
        let type = UTType(filenameExtension: (attachment.name as NSString).pathExtension)
        do {
            let data: ByteArray
            if attachment.isCompressed {
                data = try attachment.data.gunzipped()
            } else {
                data = attachment.data
            }
            let itemProvider = NSItemProvider(item: data.asData as NSData, typeIdentifier: type?.identifier)
            itemProvider.suggestedName = attachment.name
            return [UIDragItem(itemProvider: itemProvider)]
        } catch {
            Diag.error("Failed to unzip attachment [message: \(error.localizedDescription)")
            return []
        }
    }
}
