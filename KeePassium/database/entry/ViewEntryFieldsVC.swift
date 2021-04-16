//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import MobileCoreServices
import KeePassiumLib


protocol FieldCopiedViewDelegate: class {
    func didPressExport(in view: FieldCopiedView, field: ViewableField)
}

class FieldCopiedView: UIView {
    weak var delegate: FieldCopiedViewDelegate?
    weak var field: ViewableField?
    
    weak var hidingTimer: Timer?
    
    public func show(in tableView: UITableView, at indexPath: IndexPath) {
        hide(animated: false)
        
        guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
        self.frame = cell.bounds
        self.layoutIfNeeded()
        cell.addSubview(self)
        
        self.alpha = 0.0
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            options: [.curveEaseOut, .allowUserInteraction] ,
            animations: { [weak self] in
                self?.backgroundColor = UIColor.actionTint
                self?.alpha = 0.9
            },
            completion: { [weak self] finished in
                guard let self = self else { return }
                tableView.deselectRow(at: indexPath, animated: false)
                self.hidingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) {
                    [weak self] _ in
                    self?.hide(animated: true)
                }
            }
        )
    }
    
    public func hide(animated: Bool) {
        hidingTimer?.invalidate()
        hidingTimer = nil
        guard animated else {
            self.layer.removeAllAnimations()
            self.removeFromSuperview()
            return
        }
        UIView.animate(
            withDuration: 0.2,
            delay: 0.0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: { [weak self] in
                self?.backgroundColor = UIColor.actionTint
                self?.alpha = 0.0
            },
            completion: { [weak self] finished in
                if finished {
                    self?.removeFromSuperview()
                }
            }
        )
    }
    
    @IBAction func didPressExport(_ sender: UIButton) {
        guard let field = field else { return }
        delegate?.didPressExport(in: self, field: field)
    }
}


class ViewEntryFieldsVC: UITableViewController, Refreshable {
    @IBOutlet weak var copiedCellView: FieldCopiedView!
    
    private let editButton = UIBarButtonItem()

    private weak var entry: Entry?
    private var isHistoryMode = false
    private var sortedFields: [ViewableField] = []
    private var entryChangeNotifications: EntryChangeNotifications!
    
    private var entryFieldEditorCoordinator: EntryFieldEditorCoordinator?

    static func make(with entry: Entry?, historyMode: Bool) -> ViewEntryFieldsVC {
        let viewEntryFieldsVC = ViewEntryFieldsVC.instantiateFromStoryboard()
        viewEntryFieldsVC.entry = entry
        viewEntryFieldsVC.isHistoryMode = historyMode
        return viewEntryFieldsVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = true
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        copiedCellView.delegate = self
        
        editButton.title = LString.actionEdit
        editButton.target = self
        editButton.action = #selector(didPressEdit)
        editButton.accessibilityIdentifier = "edit_entry_button" 

        entryChangeNotifications = EntryChangeNotifications(observer: self)
        entry?.touch(.accessed)
        refresh()
    }

    deinit {
        entryFieldEditorCoordinator = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        editButton.isEnabled = !(entry?.isDeleted ?? true)
        navigationItem.rightBarButtonItem = isHistoryMode ? nil : editButton
        entryChangeNotifications.startObserving()
        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        entryChangeNotifications.stopObserving()
        super.viewWillDisappear(animated)
    }

    func refresh() {
        guard let entry = entry, let database = entry.database else { return }
        
        let category = ItemCategory.get(for: entry)
        let fields = ViewableEntryFieldFactory.makeAll(
            from: entry,
            in: database,
            excluding: [.title, .emptyValues]
        )
        self.sortedFields = fields.sorted {
            return category.compare($0.internalName, $1.internalName)
        }
        tableView.reloadData()
    }
    
    
    @objc func didPressEdit() {
        assert(entryFieldEditorCoordinator == nil)
        guard let entry = entry,
              let parent = entry.parent,
              let database = parent.database
        else {
            Diag.warning("Entry, parent group or database are undefined")
            assertionFailure()
            return
        }
        
        let modalRouter = NavigationRouter.createModal(style: .formSheet, at: nil)
        let entryFieldEditorCoordinator = EntryFieldEditorCoordinator(
            router: modalRouter,
            database: database,
            parent: parent,
            target: entry
        )
        entryFieldEditorCoordinator.dismissHandler = { [weak self] coordinator in
            self?.entryFieldEditorCoordinator = nil
        }
        entryFieldEditorCoordinator.delegate = self
        entryFieldEditorCoordinator.start()
        modalRouter.dismissAttemptDelegate = entryFieldEditorCoordinator
        self.entryFieldEditorCoordinator = entryFieldEditorCoordinator
        present(modalRouter, animated: true, completion: nil)
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedFields.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        let fieldNumber = indexPath.row
        let field = sortedFields[fieldNumber]
        let cell = ViewableFieldCellFactory.dequeueAndConfigureCell(
            from: tableView,
            for: indexPath,
            field: field)
        cell.delegate = self
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let fieldNumber = indexPath.row
        let field = sortedFields[fieldNumber]
        guard let text = field.resolvedValue else { return }

        Clipboard.general.insert(text)
        entry?.touch(.accessed)
        animateCopyToClipboard(indexPath: indexPath, field: field)
    }
    
    func animateCopyToClipboard(indexPath: IndexPath, field: ViewableField) {
        copiedCellView.field = field
        HapticFeedback.play(.copiedToClipboard)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.copiedCellView.show(in: self.tableView, at: indexPath)
        }
    }
}

extension ViewEntryFieldsVC: EntryChangeObserver {
    func entryDidChange(entry: Entry) {
        refresh()
    }
}


extension ViewEntryFieldsVC: ViewableFieldCellDelegate {    
    func cellHeightDidChange(_ cell: ViewableFieldCell) {
        tableView.beginUpdates()
        tableView.endUpdates()
        
        guard let viewableField = cell.field else { return }
        if viewableField.internalName == EntryField.notes {
            let isCollapsed = viewableField.isHeightConstrained
            Settings.current.isCollapseNotesField = isCollapsed
        }
    }
    
    func cellDidExpand(_ cell: ViewableFieldCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        tableView.scrollToRow(at: indexPath, at: .top, animated: true)
    }
    
    func didTapCellValue(_ cell: ViewableFieldCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        tableView(tableView, didSelectRowAt: indexPath)
    }
    
    func didLongTapAccessoryButton(_ cell: ViewableFieldCell) {
        guard let value = cell.field?.resolvedValue else { return }
        guard let accessoryView = cell.accessoryView else { return }
        
        HapticFeedback.play(.contextMenuOpened)
        
        var items: [Any] = [value]
        if value.isOpenableURL, let url = URL(string: value) {
            items = [url]
        }
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = accessoryView
            popover.sourceRect = accessoryView.bounds
        }
        present(activityVC, animated: true)
    }
}


extension ViewEntryFieldsVC: FieldCopiedViewDelegate {
    func didPressExport(in view: FieldCopiedView, field: ViewableField) {
        guard let value = field.resolvedValue else {
            assertionFailure()
            return
        }
        view.hide(animated: true)

        HapticFeedback.play(.contextMenuOpened)
        let activityController = UIActivityViewController(
            activityItems: [value],
            applicationActivities: nil)
        let popoverAnchor = PopoverAnchor(sourceView: view, sourceRect: view.bounds)
        popoverAnchor.apply(to: activityController.popoverPresentationController)
        present(activityController, animated: true)
    }
}

extension ViewEntryFieldsVC: EntryFieldEditorCoordinatorDelegate {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryFieldEditorCoordinator) {
        refresh()
    }
}
