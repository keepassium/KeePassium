//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class FileInfoCell: UITableViewCell {
    static let storyboardID = "FileInfoCell"
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    
    var name: String? {
        didSet {
            nameLabel.text = name
        }
    }
    var value: String? {
        didSet {
            valueLabel.text = value
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        nameLabel?.font = UIFont.systemFont(forTextStyle: .subheadline, weight: .thin)
        valueLabel?.font = UIFont.monospaceFont(forTextStyle: .body)
    }
}

protocol FileInfoSwitchCellDelegate: class {
    func didToggleSwitch(in cell: FileInfoSwitchCell, theSwitch: UISwitch)
}
class FileInfoSwitchCell: UITableViewCell {
    static let storyboardID = "SwitchCell"
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var theSwitch: UISwitch!
    
    weak var delegate: FileInfoSwitchCellDelegate?
    
    @IBAction func didToggleSwitch(_ sender: UISwitch) {
        delegate?.didToggleSwitch(in: self, theSwitch: sender)
    }
}

class FileInfoVC: UITableViewController {
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    public var didDeleteCallback: (()->Void)?
    
    public var canExport: Bool = false {
        didSet {
            setupButtons()
        }
    }
    
    private var fields = [(String, String)]()
    private var urlRef: URLReference!
    private var fileType: FileType!
    private var isExcludedFromBackup: Bool? 
    private var isShowExcludeFromBackupSwitch: Bool {
        let isLocalFile = urlRef.location.isInternal ||
            (urlRef.fileProvider != nil && urlRef.fileProvider == .localStorage)
        return isLocalFile && isExcludedFromBackup != nil
    }

    private var dismissablePopoverDelegate = DismissablePopover()
    
    private enum FieldTitle {
        static let fileName = NSLocalizedString(
            "[FileInfo/Field/title] File Name",
            value: "File Name",
            comment: "Field title")
        static let error = NSLocalizedString(
            "[FileInfo/Field/valueError] Error",
            value: "Error",
            comment: "Title of a field with an error message")
        static let fileLocation = NSLocalizedString(
            "[FileInfo/Field/title] File Location",
            value: "File Location",
            comment: "Field title")
        static let fileSize = NSLocalizedString(
            "[FileInfo/Field/title] File Size",
            value: "File Size",
            comment: "Field title")
        static let creationDate = NSLocalizedString(
            "[FileInfo/Field/title] Creation Date",
            value: "Creation Date",
            comment: "Field title")
        static let modificationDate = NSLocalizedString(
            "[FileInfo/Field/title] Last Modification Date",
            value: "Last Modification Date",
            comment: "Field title")
    }
    
    public static func make(
        urlRef: URLReference,
        fileType: FileType,
        at popoverAnchor: PopoverAnchor?
        ) -> FileInfoVC
    {
        let vc = FileInfoVC.instantiateFromStoryboard()
        vc.urlRef = urlRef
        vc.fileType = fileType
        
        guard let popoverAnchor = popoverAnchor else {
            return vc
        }

        vc.modalPresentationStyle = .popover
        if let popover = vc.popoverPresentationController {
            popoverAnchor.apply(to: popover)
            popover.permittedArrowDirections = [.left]
            popover.delegate = vc.dismissablePopoverDelegate
        }
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.sectionFooterHeight = 0
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        self.refreshControl = refreshControl
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        
        setupButtons()
        
        refreshControl?.beginRefreshing()
        refreshFixedFields()
        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let refreshControl = refreshControl, refreshControl.isRefreshing {
            UIView.performWithoutAnimation { [self] in
                self.refreshControl?.endRefreshing()
            }
            refreshControl.beginRefreshing()
        }
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
        if #available(iOS 13, *) {
            preferredSize.width = 400
            DispatchQueue.main.async { [self] in
                self.preferredContentSize = preferredSize
            }
        } else {
            self.preferredContentSize = preferredSize
        }
    }

    func setupButtons() {
        exportButton?.isHidden = !canExport
        let destructiveAction = DestructiveFileAction.get(for: urlRef.location)
        deleteButton?.setTitle(destructiveAction.title, for: .normal)
    }
    
    
    @objc
    func refresh() {
        refreshFixedFields()
        tableView.reloadData()
        let oldSectionCount = tableView.numberOfSections

        urlRef.refreshInfo { [weak self] result in
            guard let self = self else { return }
            self.fields.removeAll(keepingCapacity: true)
            self.refreshFixedFields()
            switch result {
            case .success(let fileInfo):
                self.updateDynamicFields(from: fileInfo)
            case .failure(let accessError):
                self.fields.append((
                    FieldTitle.error,
                    accessError.localizedDescription
                ))
            }
            
            let newSectionCount = self.numberOfSections(in: self.tableView)
            if newSectionCount > oldSectionCount {
                self.tableView.performBatchUpdates({
                    self.tableView.reloadSections([0], with: .fade)
                    self.tableView.insertSections([1], with: .fade)
                }, completion: nil)
            } else if newSectionCount < oldSectionCount {
                self.tableView.performBatchUpdates({
                    self.tableView.deleteSections([1], with: .fade)
                    self.tableView.reloadSections([0], with: .automatic)
                }, completion: nil)
            } else {
                let sections = IndexSet(integersIn: 0..<newSectionCount)
                self.tableView.reloadSections(sections, with: .none)
            }
            
            if let refreshControl = self.refreshControl, refreshControl.isRefreshing {
                refreshControl.endRefreshing()
                self.refreshControl = nil 
            }
        }
    }
    
    private func refreshFixedFields() {
        if fields.isEmpty {
            fields.append(("", ""))
            fields.append(("", ""))
        }
        fields[0] = ((FieldTitle.fileName, urlRef.visibleFileName))
        fields[1] = ((FieldTitle.fileLocation, getFileLocationDescription()))
    }
    
    private func getFileLocationDescription() -> String {
        guard let fileProvider = urlRef.fileProvider else {
            return urlRef.location.description
        }
        
        var components = [String]()
        switch urlRef.location {
        case .external:
            components.append(fileProvider.localizedName)
            let isInTrash = urlRef.getCachedInfoSync(canFetch: false)?.isInTrash
            if isInTrash ?? false {
                components.append(LString.trashDirectoryName)
            }
        case .internalDocuments, .internalBackup, .internalInbox:
            components.append(fileProvider.localizedName)
            components.append(AppInfo.name)
            components.append(urlRef.location.description)
        }
        return components.joined(separator: " → ")
    }
    
    private func updateDynamicFields(from fileInfo: FileInfo) {
        if let fileSize = fileInfo.fileSize {
            fields.append((
                FieldTitle.fileSize,
                ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            ))
        }
        if let creationDate = fileInfo.creationDate {
            fields.append((
                FieldTitle.creationDate,
                DateFormatter.localizedString(
                    from: creationDate,
                    dateStyle: .medium,
                    timeStyle: .medium)
            ))
        }
        if let modificationDate = fileInfo.modificationDate {
            fields.append((
                FieldTitle.modificationDate,
                DateFormatter.localizedString(
                    from: modificationDate,
                    dateStyle: .medium,
                    timeStyle: .medium)
            ))
        }
        self.isExcludedFromBackup = fileInfo.isExcludedFromBackup
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        if isShowExcludeFromBackupSwitch {
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
            return isShowExcludeFromBackupSwitch ? 1 : 0
        default:
            assertionFailure()
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return CGFloat.leastNonzeroMagnitude
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return nil
        case 1:
            return LString.titleBackupSettings
        default:
            return super.tableView(tableView, titleForHeaderInSection: section)
        }
    }
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        if indexPath.section == 0 {
            let fieldIndex = indexPath.row
            let cell = tableView.dequeueReusableCell(
                withIdentifier: FileInfoCell.storyboardID,
                for: indexPath)
                as! FileInfoCell
            
            cell.name = fields[fieldIndex].0
            cell.value = fields[fieldIndex].1
            return cell
        } else {
            assert(isExcludedFromBackup != nil)
            let cell = tableView.dequeueReusableCell(
                withIdentifier: FileInfoSwitchCell.storyboardID,
                for: indexPath)
                as! FileInfoSwitchCell
            cell.delegate = self
            cell.titleLabel.text = LString.titleExcludeFromBackup
            cell.theSwitch.isOn = isExcludedFromBackup ?? cell.theSwitch.isOn
            return cell
        }
    }

    
    @IBAction func didPressExport(_ sender: UIButton) {
        let popoverAnchor = PopoverAnchor(sourceView: sender, sourceRect: sender.bounds)
        FileExportHelper.showFileExportSheet(urlRef, at: popoverAnchor, parent: self)
    }
    
    @IBAction func didPressDelete(_ sender: UIButton) {
        let popoverAnchor = PopoverAnchor(sourceView: sender, sourceRect: sender.bounds)
        FileDestructionHelper.destroyFile(
            urlRef,
            fileType: fileType,
            withConfirmation: true,
            at: popoverAnchor,
            parent: self,
            completion: { [weak self] (success) in
                if success {
                    self?.didDeleteCallback?()
                } else {
                }
            }
        )
    }
}

extension FileInfoVC: FileInfoSwitchCellDelegate {
    func didToggleSwitch(in cell: FileInfoSwitchCell, theSwitch: UISwitch) {
        setExcludedFromBackup(theSwitch.isOn)
    }
    
    private func setExcludedFromBackup(_ isExcluded: Bool) {
        urlRef.resolveAsync(timeout: 1.0) {[weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(var url):
                if url.setExcludedFromBackup(isExcluded) {
                    Diag.info("File is \(isExcluded ? "" : "not ")excluded from iTunes/iCloud backup")
                } else {
                    Diag.error("Failed to change file attributes.")
                    self.showErrorAlert(LString.errorFailedToChangeFileAttributes)
                }
            case .failure(let error):
                Diag.error(error.localizedDescription)
                self.showErrorAlert(error)
            }
            self.refresh()
        }
    }
}
