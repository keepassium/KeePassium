//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol FieldCopiedViewDelegate: class {
    func didPressExport(for indexPath: IndexPath, from view: FieldCopiedView)
}

class FieldCopiedView: UIView {
    var indexPath: IndexPath!
    
    weak var hidingTimer: Timer?
    weak var delegate: FieldCopiedViewDelegate?
    
    public func show(in tableView: UITableView, at indexPath: IndexPath) {
        hide(animated: false)
        
        guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
        self.indexPath = indexPath
        
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
        delegate?.didPressExport(for: indexPath, from: self)
    }
}


protocol EntryFieldViewerDelegate: AnyObject {
    func canEditEntry(in viewController: EntryFieldViewerVC) -> Bool
    func didPressCopyField(
        text: String,
        from viewableField: ViewableField,
        in viewController: EntryFieldViewerVC)
    func didPressExportField(
        text: String,
        from viewableField: ViewableField,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldViewerVC)
    
    func didPressEdit(at popoverAnchor: PopoverAnchor, in viewController: EntryFieldViewerVC)
}

final class EntryFieldViewerVC: UITableViewController, Refreshable {
    @IBOutlet private weak var copiedCellView: FieldCopiedView!
    
    weak var delegate: EntryFieldViewerDelegate?
    
    private let editButton = UIBarButtonItem()

    private var isHistoryEntry = false
    private var category = ItemCategory.default
    private var sortedFields: [ViewableField] = []

    
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

        refresh()
    }
  
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    func setContents(_ fields: [ViewableField], category: ItemCategory, isHistoryEntry: Bool) {
        self.category = category
        self.sortedFields = fields.sorted {
            return category.compare($0.internalName, $1.internalName)
        }
        refresh()
    }
    
    func refresh() {
        guard isViewLoaded else { return }
        editButton.isEnabled = delegate?.canEditEntry(in: self) ?? false
        navigationItem.rightBarButtonItem = isHistoryEntry ? nil : editButton
        tableView.reloadData()
    }
    
    
    @objc func didPressEdit(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressEdit(at: popoverAnchor, in: self)
    }
    
    private func didTapRow(at indexPath: IndexPath) {
        let fieldNumber = indexPath.row
        let field = sortedFields[fieldNumber]
        guard let text = field.resolvedValue else { return }

        delegate?.didPressCopyField(text: text, from: field, in: self)
        animateCopyingToClipboard(at: indexPath)
    }
    
    func animateCopyingToClipboard(at indexPath: IndexPath) {
        HapticFeedback.play(.copiedToClipboard)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.copiedCellView.show(in: self.tableView, at: indexPath)
        }
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
        let field = getField(at: indexPath)
        let cell = ViewableFieldCellFactory.dequeueAndConfigureCell(
            from: tableView,
            for: indexPath,
            field: field)
        cell.delegate = self
        return cell
    }
    
    private func getField(at indexPath: IndexPath) -> ViewableField {
        let fieldNumber = indexPath.row
        let field = sortedFields[fieldNumber]
        return field
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didTapRow(at: indexPath)
    }
}

extension EntryFieldViewerVC: ViewableFieldCellDelegate {    
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
        guard let field = cell.field,
              let value = field.resolvedValue,
              let accessoryView = cell.accessoryView
        else {
            return
        }
        
        HapticFeedback.play(.contextMenuOpened)
        let popoverAnchor = PopoverAnchor(sourceView: accessoryView, sourceRect: accessoryView.bounds)
        delegate?.didPressExportField(text: value, from: field, at: popoverAnchor, in: self)
    }
}

extension EntryFieldViewerVC: FieldCopiedViewDelegate {
    func didPressExport(for indexPath: IndexPath, from view: FieldCopiedView) {
        let field = getField(at: indexPath)
        guard let value = field.resolvedValue else {
            assertionFailure()
            return
        }
        view.hide(animated: true)

        HapticFeedback.play(.contextMenuOpened)
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressExportField(text: value, from: field, at: popoverAnchor, in: self)
    }
}