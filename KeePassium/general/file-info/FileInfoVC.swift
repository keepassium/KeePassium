//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol FileInfoDelegate: AnyObject {
    func didPressEliminate(at popoverAnchor: PopoverAnchor, in viewController: FileInfoVC)
    func didPressExport(at popoverAnchor: PopoverAnchor, in viewController: FileInfoVC)
    func shouldShowAttribute(_ attribute: FileInfo.Attribute, in viewController: FileInfoVC) -> Bool
    func didChangeAttribute(_ attribute: FileInfo.Attribute, to value: Bool, in viewController: FileInfoVC)
}

final class FileInfoVC: UITableViewController, Refreshable {
    internal typealias FileInfoField = (name: String, value: String)
    private enum CellID {
        static let fieldCell = "FieldCell"
        static let switchCell = "SwitchCell"
    }

    private enum Section {
        case info
        case attributes([FileInfo.Attribute])
    }

    public weak var delegate: FileInfoDelegate?

    public var canExport: Bool = false
    public var fileRef: URLReference!
    public var fileType: FileType!

    private var exportBarButton: UIBarButtonItem! 
    private var eliminateBarButton: UIBarButtonItem! 
    private var fields = [FileInfoField]()
    private var attributes = FileInfo.Attributes()
    private var sections = [Section]()

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
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
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

        let visibleAttributes = FileInfo.Attribute.allCases.filter {
            attributes.keys.contains($0) && delegate?.shouldShowAttribute($0, in: self) ?? false
        }
        if visibleAttributes.isEmpty {
            sections = [.info]
        } else {
            sections = [.info, .attributes(visibleAttributes)]
        }
        tableView.reloadData()
    }

    public func showBusyIndicator(_ isBusy: Bool, animated: Bool) {
        titleView.showSpinner(isBusy, animated: animated)
    }

    public func updateFileInfo(_ fileInfo: FileInfo?, error: FileAccessError?) {
        attributes = fileInfo?.attributes ?? [:]
        var newFields = makeFields(fileInfo: fileInfo)
        if let error = error {
            newFields.append(FileInfoField(
                name: LString.FileInfo.fieldError,
                value: error.localizedDescription
            ))
        }
        fields = newFields
        refresh()
    }

    private func setupToolbar() {
        var toolbarItems = [UIBarButtonItem]()

        let exportActionTitle: String
        let exportActionSymbol: SymbolName
        if ProcessInfo.isRunningOnMac {
            exportActionTitle = LString.actionRevealInFinder
            exportActionSymbol = .folder
        } else {
            exportActionTitle = LString.actionExport
            exportActionSymbol = .squareAndArrowUp
        }
        exportBarButton = UIBarButtonItem(
            title: exportActionTitle,
            image: .symbol(exportActionSymbol),
            primaryAction: UIAction(
                title: exportActionTitle,
                handler: { [weak self] _ in
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
            image: .symbol(.trash),
            primaryAction: UIAction(
                title: eliminationActionTitle,
                attributes: .destructive,
                handler: { [weak self] _ in
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
            value: fileInfo?.fileName ?? fileRef.visibleFileName
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
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .info:
            return fields.count
        case let .attributes(attributes):
            return attributes.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .info:
            return nil
        case .attributes:
            return LString.titleFileAttributes
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sections[section] {
        case .attributes(let attributes):
            if attributes.contains(where: { $0 == .hidden }) {
                return LString.descriptionHiddenFileAttribute
            }
        default:
            break
        }
        return nil
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .info:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.fieldCell,
                for: indexPath)
            configureFieldCell(cell, field: fields[indexPath.row])
            return cell
        case let .attributes(attributes):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.switchCell,
                for: indexPath)
                as! SwitchCell
            configureAttributeCell(cell, attribute: attributes[indexPath.row])
            return cell
        }
    }

    private func configureFieldCell(_ cell: UITableViewCell, field: FileInfoField) {
        cell.textLabel?.text = field.name
        cell.detailTextLabel?.text = field.value
    }

    private func configureAttributeCell(_ cell: SwitchCell, attribute: FileInfo.Attribute) {
        assert(attributes[attribute] != nil)
        cell.imageView?.image = attribute.icon
        cell.textLabel?.text = attribute.title
        cell.theSwitch.isOn = (attributes[attribute] == true)
        cell.onDidToggleSwitch = { [weak self] cellSwitch in
            guard let self else { return }
            delegate?.didChangeAttribute(attribute, to: cellSwitch.isOn, in: self)
        }
    }
}

extension FileInfo.Attribute {
    var icon: UIImage? {
        switch self {
        case .excludedFromBackup:
            return UIImage.symbol(.xmarkICloud)
        case .hidden:
            return UIImage.symbol(.eye)
        }
    }
}
