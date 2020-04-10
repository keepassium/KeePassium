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

class ViewEntryFieldsVC: UITableViewController, Refreshable {
    @IBOutlet weak var copiedCellView: UIView!
    
    private let editButton = UIBarButtonItem()

    private weak var entry: Entry?
    private var isHistoryMode = false
    private var sortedFields: [ViewableField] = []
    private var entryChangeNotifications: EntryChangeNotifications!

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
        
        editButton.image = UIImage(asset: .editItemToolbar)
        editButton.title = NSLocalizedString(
            "[Entry/View] Edit Entry",
            value: "Edit Entry",
            comment: "Action to start editing an entry")
        editButton.target = self
        editButton.action = #selector(onEditAction)
        editButton.accessibilityIdentifier = "edit_entry_button" 

        entryChangeNotifications = EntryChangeNotifications(observer: self)
        entry?.touch(.accessed)
        refresh()
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
    
    
    @objc func onEditAction() {
        guard let entry = entry else { return }
        let editEntryFieldsVC = EditEntryVC.make(entry: entry, popoverSource: nil, delegate: nil)
        present(editEntryFieldsVC, animated: true, completion: nil)
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
        guard let text = field.value else { return }

        let timeout = Double(Settings.current.clipboardTimeout.seconds)
        if text.isOpenableURL {
            Clipboard.general.insert(url: URL(string: text)!, timeout: timeout)
        } else {
            Clipboard.general.insert(text: text, timeout: timeout)
        }
        entry?.touch(.accessed)
        animateCopyToClipboard(indexPath: indexPath)
    }
    
    func animateCopyToClipboard(indexPath: IndexPath) {
        tableView.allowsSelection = false
        guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
        copiedCellView.frame = cell.bounds
        copiedCellView.layoutIfNeeded()
        cell.addSubview(copiedCellView)

        DispatchQueue.main.async { [weak self] in
            guard let _self = self else { return }
            _self.showCopyNotification(indexPath: indexPath, view: _self.copiedCellView)
        }
    }
    
    private func showCopyNotification(indexPath: IndexPath, view: UIView) {
        view.alpha = 0.0
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            options: .curveEaseOut ,
            animations: {
                view.backgroundColor = UIColor.actionTint
                view.alpha = 0.8
            },
            completion: {
                [weak self] finished in
                guard let _self = self else { return }
                _self.tableView.deselectRow(at: indexPath, animated: false)
                _self.hideCopyNotification(view: view)
            }
        )
    }
    
    private func hideCopyNotification(view: UIView) {
        UIView.animate(
            withDuration: 0.2,
            delay: 0.5,
            options: .curveEaseIn,
            animations: {
                view.backgroundColor = UIColor.actionTint
                view.alpha = 0.0
            },
            completion: {
                [weak self] finished in
                guard let _self = self else { return }
                view.removeFromSuperview()
                _self.tableView.allowsSelection = true
            }
        )
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
    }
    
    func didTapCellValue(_ cell: ViewableFieldCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        tableView(tableView, didSelectRowAt: indexPath)
    }
    
    func didLongTapAccessoryButton(_ cell: ViewableFieldCell) {
        guard let value = cell.field?.value else { return }
        guard let accessoryView = cell.accessoryView else { return }
        
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
