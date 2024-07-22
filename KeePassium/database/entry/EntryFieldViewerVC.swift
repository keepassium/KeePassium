//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol EntryFieldViewerDelegate: AnyObject {
    func didPressCopyField(
        text: String,
        from viewableField: ViewableField,
        in viewController: EntryFieldViewerVC)
    func didPressExportField(
        text: String,
        from viewableField: ViewableField,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldViewerVC)
    func didPressCopyFieldReference(
        from viewableField: ViewableField,
        in viewController: EntryFieldViewerVC)
    func didPressShowLargeType(
        text: String,
        from viewableField: ViewableField,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldViewerVC)

    func didPressEdit(at popoverAnchor: PopoverAnchor, in viewController: EntryFieldViewerVC)
    func didPressOpenLinkedDatabase(_ info: LinkedDatabaseInfo, in viewController: EntryFieldViewerVC)
}

final class EntryFieldViewerVC: UITableViewController, Refreshable {
    private lazy var copiedCellView: FieldCopiedView = {
        let view = FieldCopiedView(frame: .zero)
        return view
    }()

    enum Section: Int, CaseIterable {
        case announcements
        case fields
    }

    weak var delegate: EntryFieldViewerDelegate?

    private let editButton = UIBarButtonItem()

    private var isHistoryEntry = false
    private var canEditEntry = false
    private var category = ItemCategory.default
    private var sortedFields: [ViewableField] = []
    private var tags: [String] = []
    private var announcements: [AnnouncementItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = true

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        tableView.register(
            AnnouncementCell.classForCoder(),
            forCellReuseIdentifier: AnnouncementCell.reuseIdentifier)

        copiedCellView.delegate = self

        editButton.title = LString.actionEdit
        editButton.target = self
        editButton.action = #selector(didPressEdit)
        editButton.accessibilityIdentifier = "edit_entry_button" 

        toolbarItems = [] 
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    func setContents(
        _ fields: [ViewableField],
        category: ItemCategory,
        tags: [String],
        linkedDBInfo: LinkedDatabaseInfo?,
        isHistoryEntry: Bool,
        canEditEntry: Bool
    ) {
        self.isHistoryEntry = isHistoryEntry
        self.canEditEntry = canEditEntry
        self.category = category
        self.tags = tags
        self.sortedFields = fields.sorted {
            return category.compare($0.internalName, $1.internalName)
        }

        announcements.removeAll()
        if let linkedDBInfo {
            announcements.append(makeLinkedDatabaseAnnouncement(linkedDBInfo))
        }
        refresh()
    }

    func refresh() {
        guard isViewLoaded else { return }
        editButton.isEnabled = canEditEntry
        navigationItem.rightBarButtonItem = editButton
        tableView.reloadData()
    }

    private func makeLinkedDatabaseAnnouncement(_ info: LinkedDatabaseInfo) -> AnnouncementItem {
        let dbRef = info.databaseRef
        let fpIcon: UIImage?
        if PremiumManager.shared.isAvailable(feature: .canOpenLinkedDatabases) {
            fpIcon = UIImage.symbol(dbRef.fileProvider?.iconSymbol ?? .fileProviderGeneric)
        } else {
            fpIcon = UIImage.premiumBadge
        }
        return AnnouncementItem(
            title: dbRef.visibleFileName,
            body: nil,
            actionTitle: LString.actionOpenDatabase,
            image: fpIcon,
            onDidPressAction: { [weak self] _ in
                guard let self else { return }
                delegate?.didPressOpenLinkedDatabase(info, in: self)
            },
            onDidPressClose: nil
        )
    }

    @objc func didPressEdit(_ sender: UIBarButtonItem) {
        guard canEditEntry else {
            Diag.warning("Tried to modify non-editable entry, aborting")
            assertionFailure()
            return
        }
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressEdit(at: popoverAnchor, in: self)
    }

    private func didTapRow(at indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section) {
        case .announcements:
            return
        case .fields:
            guard let field = getField(at: indexPath),
                  let text = field.resolvedValue
            else { return }

            delegate?.didPressCopyField(text: text, from: field, in: self)
            animateCopyingToClipboard(at: indexPath)
        default:
            fatalError("Unexpected section")
        }
    }

    func animateCopyingToClipboard(at indexPath: IndexPath) {
        let supportsFieldReferencing = getField(at: indexPath)?.field?.isStandardField ?? false
        HapticFeedback.play(.copiedToClipboard)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.copiedCellView.show(
                in: self.tableView,
                at: indexPath,
                options: [
                    .canExport,
                    .canShowLargeType,
                    supportsFieldReferencing ? .canCopyReference : nil
                ].compactMap { $0 }
            )
        }
    }


    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .announcements:
            return announcements.count
        case .fields:
            return sortedFields.count
        default:
            fatalError("Unexpected section")
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .announcements:
            return makeAnnouncementCell(at: indexPath, in: tableView)
        case .fields:
            return makeFieldCell(at: indexPath, in: tableView)
        default:
            fatalError("Unexpected section")
        }
    }

    private func makeAnnouncementCell(at indexPath: IndexPath, in tableView: UITableView) -> UITableViewCell {
        let cell = tableView
            .dequeueReusableCell(withIdentifier: AnnouncementCell.reuseIdentifier, for: indexPath)
            as! AnnouncementCell
        let announcement = announcements[indexPath.row]
        cell.announcementView.apply(announcement)
        cell.accessoryType = .detailButton
        return cell
    }

    private func makeFieldCell(at indexPath: IndexPath, in tableView: UITableView) -> UITableViewCell {
        let field = sortedFields[indexPath.row]
        let cell = ViewableFieldCellFactory.dequeueAndConfigureCell(
            from: tableView,
            for: indexPath,
            field: field)
        cell.delegate = self
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        if let dynamicFieldCell = cell as? DynamicFieldCell {
            dynamicFieldCell.startRefreshing()
        }
    }

    override func tableView(
        _ tableView: UITableView,
        didEndDisplaying cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        if let dynamicFieldCell = cell as? DynamicFieldCell {
            dynamicFieldCell.stopRefreshing()
        }
    }

    private func getField(at indexPath: IndexPath) -> ViewableField? {
        guard indexPath.section == Section.fields.rawValue else {
            assertionFailure()
            return nil
        }
        let fieldNumber = indexPath.row
        let field = sortedFields[fieldNumber]
        return field
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didTapRow(at: indexPath)
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section) {
        case .announcements:
            URLOpener(self).open(url: URL.AppHelp.linkedDatabases)
        default:
            break
        }
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
        guard let field = getField(at: indexPath),
              let value = field.resolvedValue
        else {
            assertionFailure()
            return
        }
        view.hide(animated: true)

        HapticFeedback.play(.contextMenuOpened)
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressExportField(text: value, from: field, at: popoverAnchor, in: self)
    }

    func didPressCopyFieldReference(for indexPath: IndexPath, from view: FieldCopiedView) {
        guard let field = getField(at: indexPath) else {
            assertionFailure()
            return
        }
        delegate?.didPressCopyFieldReference(from: field, in: self)
    }

    func didPressShowLargeType(for indexPath: IndexPath, from view: FieldCopiedView) {
        guard let field = getField(at: indexPath),
              let value = field.resolvedValue
        else {
            assertionFailure()
            return
        }
        view.hide(animated: true)

        HapticFeedback.play(.contextMenuOpened)
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressShowLargeType(text: value, from: field, at: popoverAnchor, in: self)
    }
}
