//  KeePassium Password Manager
//  Copyright © 2018-2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class SyncConflictAlertMessageCell: UITableViewCell {
    @IBOutlet fileprivate weak var titleLabel: UILabel!
    @IBOutlet fileprivate weak var subtitleLabel: UILabel!
}

final class SyncConflictAlert: UIViewController, Refreshable {
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var tableViewHeightConstraint: NSLayoutConstraint!

    private enum CellID {
        static let fixedCellCount = 1
        static let message = "messageCell"
        static let file = "fileCell"
        static let option = "optionCell"
    }
    
    public let options: [DatabaseFile.ConflictResolutionStrategy] =
        [.overwriteRemote, .saveAs, .cancelSaving]

    typealias Completion = ((_ selectedStrategy: DatabaseFile.ConflictResolutionStrategy) -> Void)
    var responseHandler: Completion?
    
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .long
        dateFormatter.doesRelativeDateFormatting = true
        dateFormatter.formattingContext = .listItem
        return dateFormatter
    }()
    
    private var localFileInfo: FileInfo?
    private var remoteFileInfo: FileInfo?
    private var remoteFileError: FileAccessError?
    
    public func setData(local: DatabaseFile, remote: URL) {
        localFileInfo = local.fileReference?.getCachedInfoSync(canFetch: false)
        refresh()
        remote.readFileInfo(canUseCache: false) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let fileInfo):
                self.remoteFileInfo = fileInfo
                self.refresh()
            case .failure(let fileAccessError):
                self.remoteFileError = fileAccessError
                self.refresh()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.layer.borderWidth = 0
        tableView.layer.shadowColor = UIColor.primaryText.cgColor
        tableView.layer.shadowOpacity = 0.1
        tableView.layer.shadowOffset = .zero
        tableView.layer.shadowRadius = 10

        let bgView = UIView(frame: view.bounds)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bgView.alpha = 0.2
        bgView.backgroundColor = .black
        view.insertSubview(bgView, at: 0)
        
        tableView.estimatedRowHeight = 60
        tableView.rowHeight  = UITableView.automaticDimension
        tableView.alwaysBounceVertical = false
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        tableView.removeObserver(self, forKeyPath: "contentSize")
        super.viewWillDisappear(animated)
    }
    
    func refresh() {
        tableView.reloadData()
    }
    
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        let contentSize = tableView.contentSize
        tableViewHeightConstraint.constant = contentSize.height
    }
}

extension SyncConflictAlert: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return CellID.fixedCellCount
        case 1:
            return options.count
        default:
            assertionFailure()
            return 0
        }
    }
    
    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: CellID.message,
                    for: indexPath) as! SyncConflictAlertMessageCell
                return setupMessageCell(cell)
            case 1:
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: CellID.file,
                    for: indexPath)
                return setupLocalFileCell(cell)
            case 2:
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: CellID.file,
                    for: indexPath)
                return setupRemoteFileCell(cell)
            default:
                fatalError()
            }
        case 1:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.option,
                for: indexPath)
            return setupOptionCell(cell, index: indexPath.row)
        default:
            fatalError()
        }
    }
    
    private func setupMessageCell(_ cell: SyncConflictAlertMessageCell) -> UITableViewCell {
        cell.titleLabel?.text = LString.titleSyncConflict
        cell.subtitleLabel?.text = LString.syncConflictMessage
        return cell
    }
    
    private func setupLocalFileCell(_ cell: UITableViewCell) -> UITableViewCell {
        cell.textLabel?.text = "Local database"
        cell.detailTextLabel?.text = String.localizedStringWithFormat(
            "Name: %@\nModified: %@",
            localFileInfo?.fileName ?? "?",
            formatFileDate(localFileInfo?.modificationDate) ?? "?")
        return cell
    }
    
    private func setupRemoteFileCell(_ cell: UITableViewCell) -> UITableViewCell {
        cell.textLabel?.text = "Target database"
        if let remoteFileInfo = remoteFileInfo {
            cell.detailTextLabel?.text = String.localizedStringWithFormat(
                "Name: %@\nModified: %@",
                remoteFileInfo.fileName,
                formatFileDate(remoteFileInfo.modificationDate) ?? "?"
            )
        } else {
            cell.detailTextLabel?.text = remoteFileError?.localizedDescription ?? LString.databaseStatusLoading
        }
        return cell
    }
    
    private func setupOptionCell(_ cell: UITableViewCell, index: Int) -> UITableViewCell {
        let option = options[index]
        switch option {
        case .overwriteRemote:
            cell.textLabel?.textColor = .destructiveTint
            cell.textLabel?.font = .preferredFont(forTextStyle: .body)
            cell.textLabel?.text = LString.conflictResolutionOverwriteAction
            cell.detailTextLabel?.text = LString.conflictResolutionOverwriteDescription
        case .saveAs:
            cell.textLabel?.textColor = .actionTint
            cell.textLabel?.font = .preferredFont(forTextStyle: .body)
            cell.textLabel?.text = LString.conflictResolutionSaveAsAction
            cell.detailTextLabel?.text = LString.conflictResolutionSaveAsDescription
        case .merge:
            fatalError("Not implemented yet")
            cell.textLabel?.textColor = .actionTint
            cell.textLabel?.font = .preferredFont(forTextStyle: .body)
            cell.textLabel?.text = LString.conflictResolutionMergeAction
            cell.detailTextLabel?.text = LString.conflictResolutionMergeDescription
        case .cancelSaving:
            cell.textLabel?.textColor = .actionTint
            cell.textLabel?.font = .preferredFont(forTextStyle: .body).withWeight(.semibold)
            cell.textLabel?.text = LString.conflictResolutionCancelAction
            cell.detailTextLabel?.text = LString.conflictResolutionCancelDescription
        }
        return cell
    }
    
    private func formatFileDate(_ date: Date?) -> String? {
        guard let date = date else {
            return nil
        }
        return dateFormatter.string(from: date)
    }
}

extension SyncConflictAlert: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.section == 1 {
            return indexPath
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let strategy = options[indexPath.row]
        Diag.debug("Selected conflict resolution strategy: \(strategy)")
        dismiss(animated: true) {[self] in
            self.responseHandler?(strategy)
        }
    }
}

extension LString {
    public static let titleSyncConflict = NSLocalizedString(
        "[Database/SyncConflict/title]",
        value: "Sync Conflict",
        comment: "Title of a message shown when saving to a database that has already been modified elsewhere."
    )
    public static let syncConflictMessage = NSLocalizedString(
        "[Database/SyncConflict/description]",
        value: "The database has changed since it was loaded in KeePassium.",
        comment: "Message shown in case of database sync conflict."
    )

    public static let conflictResolutionOverwriteAction = LString.actionOverwrite
    public static let conflictResolutionOverwriteDescription = NSLocalizedString(
        "[Database/SyncConflict/Overwrite/description]",
        value: "Overwrite target file with the local version.",
        comment: "Explanation of the database sync conflict `Overwrite` option.")
    
    public static let conflictResolutionSaveAsAction = LString.actionFileSaveAs
    public static let conflictResolutionSaveAsDescription = NSLocalizedString(
        "[Database/SyncConflict/SaveAs/description]",
        value: "Save changes to another file.",
        comment: "Explanation of the database sync conflict `Save as` option.")

    public static let conflictResolutionMergeAction = NSLocalizedString(
        "[Database/SyncConflict/Merge/action]",
        value: "Merge",
        comment: "Action: combine changes in two conflicting databases.")
    public static let conflictResolutionMergeDescription = NSLocalizedString(
        "[Database/SyncConflict/Merge/description]",
        value: "Combine changes before saving.",
        comment: "Explanation of the database sync conflict `Merge` option.")
    
    public static let conflictResolutionCancelAction = LString.actionCancel
    public static let conflictResolutionCancelDescription = NSLocalizedString(
        "[Database/SyncConflict/Cancel/description]",
        value: "Cancel saving, leave target file intact.",
        comment: "Explanation of the database sync conflict `Cancel` option.")
}
