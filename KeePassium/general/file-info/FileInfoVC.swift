//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol FileInfoDelegate: AnyObject {
    func didPressEliminate(at popoverAnchor: PopoverAnchor, in viewController: FileInfoVC)
    func didPressExport(at popoverAnchor: PopoverAnchor, in viewController: FileInfoVC)
    func canExcludeFromBackup(in viewController: FileInfoVC) -> Bool
    func didChangeExcludeFromBackup(shouldExclude: Bool, in viewController: FileInfoVC)
}

final class FileInfoVC: UITableViewController, Refreshable {
    internal typealias FileInfoField = (name: String, value: String)
    private enum CellID {
        static let fieldCell = "FieldCell"
        static let switchCell = "SwitchCell"
    }
    
    public weak var delegate: FileInfoDelegate?
    
    public var canExport: Bool = false
    public var isExcludedFromBackup: Bool? 
    public var fileRef: URLReference!
    public var fileType: FileType!
    
    private var exportBarButton: UIBarButtonItem! 
    private var eliminateBarButton: UIBarButtonItem! 
    private var fields = [FileInfoField]()
    private var canExcludeFromBackup: Bool {
        delegate?.canExcludeFromBackup(in: self) ?? false
    }
    private lazy var titleView: SpinnerLabel = {
        let view = SpinnerLabel(frame: .zero)
        view.label.text = LString.FileInfo.title
        view.label.font = .preferredFont(forTextStyle: .headline)
        view.spinner.startAnimating()
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SwitchCell.classForCoder(), forCellReuseIdentifier: CellID.switchCell)
        tableView.sectionFooterHeight = 0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        
        navigationItem.titleView = titleView
        refresh()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        tableView.removeObserver(self, forKeyPath: "contentSize")
        super.viewWillDisappear(animated)
    }
    
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?)
    {
        var preferredSize = CGSize(
            width: max(tableView.contentSize.width, self.preferredContentSize.width),
            height: max(tableView.contentSize.height, self.preferredContentSize.height)
        )

        preferredSize.width = 400
        DispatchQueue.main.async { [self] in
            self.preferredContentSize = preferredSize
        }
    }

    func refresh() {
        setupToolbar()
        tableView.reloadData()
    }
    
    public func showBusyIndicator(_ isBusy: Bool, animated: Bool) {
        titleView.showSpinner(isBusy, animated: animated)
    }
    
    public func updateFileInfo(_ fileInfo: FileInfo?, error: FileAccessError?) {
        var newFields = makeFields(fileInfo: fileInfo)
        if let error = error {
            newFields.append(FileInfoField(
                name: LString.FileInfo.fieldError,
                value: error.localizedDescription
            ))
        }
        
        let oldSectionCount = tableView.numberOfSections
        let newSectionCount = self.numberOfSections(in: tableView)

        fields = newFields
        if newSectionCount > oldSectionCount {
            tableView.performBatchUpdates({ [self] in
                tableView.reloadSections([0], with: .fade)
                tableView.insertSections([1], with: .fade)
            }, completion: nil)
        } else if newSectionCount < oldSectionCount {
            tableView.performBatchUpdates({ [self] in
                tableView.deleteSections([1], with: .fade)
                tableView.reloadSections([0], with: .automatic)
            }, completion: nil)
        } else {
            let sections = IndexSet(integersIn: 0..<newSectionCount)
            tableView.reloadSections(sections, with: .none)
        }
        setupToolbar()
    }
    
    private func setupToolbar() {
        var toolbarItems = [UIBarButtonItem]()
        
        let exportActionTitle = ProcessInfo.isRunningOnMac ?
                LString.actionRevealInFinder : LString.actionExport
        exportBarButton = UIBarButtonItem(
            title: exportActionTitle,
            image: .get(.squareAndArrowUp),
            primaryAction: UIAction(
                title: exportActionTitle,
                image: .get(.squareAndArrowUp),
                handler: { [weak self] action in
                    guard let self = self else { return }
                    let popoverAnchor = PopoverAnchor(barButtonItem: self.exportBarButton)
                    self.delegate?.didPressExport(at: popoverAnchor, in: self)
                }
            )
        )
        exportBarButton.isEnabled = canExport
        
        let eliminationActionTitle = DestructiveFileAction.get(for: fileRef.location).title
        eliminateBarButton = UIBarButtonItem(
            title: eliminationActionTitle,
            image: .get(.trash),
            primaryAction: UIAction(
                title: eliminationActionTitle,
                image: .get(.trash),
                attributes: .destructive,
                handler: { [weak self] action in
                    guard let self = self else { return }
                    let popoverAnchor = PopoverAnchor(barButtonItem: self.eliminateBarButton)
                    self.delegate?.didPressEliminate(at: popoverAnchor, in: self)
                }
            )
        )
        toolbarItems.append(UIBarButtonItem(systemItem: .flexibleSpace))
        toolbarItems.append(exportBarButton)
        toolbarItems.append(UIBarButtonItem(systemItem: .flexibleSpace))
        toolbarItems.append(eliminateBarButton)

        setToolbarItems(toolbarItems, animated: true)
    }
    
    private func makeFields(fileInfo: FileInfo?) -> [FileInfoField] {
        var fields = [FileInfoField]()
        fields.append(FileInfoField(
            name: LString.FileInfo.fieldFileName,
            value: fileRef.visibleFileName
        ))
        fields.append(FileInfoField(
            name: LString.FileInfo.fieldFileLocation,
            value: fileRef.getLocationDescription()
        ))
        
        guard let fileInfo = fileInfo else { 
            return fields
        }
        
        if let fileSize = fileInfo.fileSize {
            fields.append(FileInfoField(
                name: LString.FileInfo.fieldFileSize,
                value: ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            ))
        }
        if let creationDate = fileInfo.creationDate {
            fields.append(FileInfoField(
                name: LString.FileInfo.fieldCreationDate,
                value: DateFormatter.localizedString(
                    from: creationDate,
                    dateStyle: .medium,
                    timeStyle: .medium
                )
            ))
        }
        if let modificationDate = fileInfo.modificationDate {
            fields.append(FileInfoField(
                name: LString.FileInfo.fieldModificationDate,
                value: DateFormatter.localizedString(
                    from: modificationDate,
                    dateStyle: .medium,
                    timeStyle: .medium
                )
            ))
        }
        return fields
    }
}

extension FileInfoVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        if canExcludeFromBackup {
            return 2
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return fields.count
        case 1:
            return canExcludeFromBackup ? 1 : 0
        default:
            assertionFailure()
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return nil
        case 1:
            return LString.titleFileBackupSettings
        default:
            return super.tableView(tableView, titleForHeaderInSection: section)
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.fieldCell,
                for: indexPath)
            configureFieldCell(cell, field: fields[indexPath.row])
            return cell
        case 1:
            assert(isExcludedFromBackup != nil)
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.switchCell,
                for: indexPath)
                as! SwitchCell
            configureExcludeFromBackupCell(cell)
            return cell
        default:
            preconditionFailure("Unexpected section number")
        }
    }

    private func configureFieldCell(_ cell: UITableViewCell, field: FileInfoField) {
        cell.textLabel?.text = field.name
        cell.detailTextLabel?.text = field.value
    }
    
    private func configureExcludeFromBackupCell(_ cell: SwitchCell) {
        cell.imageView?.image = UIImage.get(.xmarkICloud)
        cell.textLabel?.text = LString.titleExcludeFromBackup
        cell.theSwitch.isOn = isExcludedFromBackup ?? cell.theSwitch.isOn
        cell.onDidToggleSwitch = { [weak self] cellSwitch in
            guard let self = self else { return }
            self.delegate?.didChangeExcludeFromBackup(shouldExclude: cellSwitch.isOn, in: self)
        }
    }
}
