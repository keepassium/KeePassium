//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class SyncConflictAlertMessageCell: UITableViewCell {
    fileprivate var buttonHandler: ((UIButton)->Void)?
    
    @IBOutlet fileprivate weak var titleLabel: UILabel!
    @IBOutlet fileprivate weak var subtitleLabel: UILabel!
    @IBOutlet fileprivate weak var toggleButton: UIButton!
     
    @IBAction func didPressToggleButton(_ sender: UIButton) {
        buttonHandler?(sender)
    }
}

final class SyncConflictAlert: UIViewController, Refreshable {
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var tableViewHeightConstraint: NSLayoutConstraint!

    private enum CellID {
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
        dateFormatter.timeStyle = .medium
        dateFormatter.doesRelativeDateFormatting = false
        dateFormatter.formattingContext = .listItem
        return dateFormatter
    }()
    
    private let fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.formattingContext = .listItem
        formatter.countStyle = .file
        return formatter
    }()
    
    private var localFileInfo: FileInfo?
    private var remoteFileInfo: FileInfo?
    private var remoteFileError: FileAccessError?
    private var isShowFileInfo = false
    
    private let infoRefreshQueue = DispatchQueue(
        label: "com.keepassium.SyncConflictInfoRefresh",
        qos: .utility
    )
    
    public func setData(local: DatabaseFile, remote: URL) {
        localFileInfo = local.fileReference?.getCachedInfoSync(canFetch: false)
        refresh()
        infoRefreshQueue.async { [self] in
            FileDataProvider.readFileInfo(
                at: remote,
                fileProvider: FileProvider.find(for: remote), 
                canUseCache: false,
                completionQueue: .main,
                completion: { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let fileInfo):
                        self.remoteFileInfo = fileInfo
                    case .failure(let fileAccessError):
                        self.remoteFileError = fileAccessError
                    }
                    self.refresh()
                }
            )
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
        tableView.rowHeight = UITableView.automaticDimension
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }
    
    func refresh() {
        guard isViewLoaded else { return }
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
            return isShowFileInfo ? 3 : 1
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
                return setupLocalFileInfoCell(cell)
            case 2:
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: CellID.file,
                    for: indexPath)
                return setupRemoteFileInfoCell(cell)
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
        cell.titleLabel?.text = localFileInfo?.fileName ?? LString.titleSyncConflict
        cell.subtitleLabel?.text = LString.syncConflictMessage
        cell.toggleButton.setTitle(LString.actionShowDetails, for: .normal)
        cell.buttonHandler = { [weak self] button in
            guard let self = self else { return }
            self.isShowFileInfo = !self.isShowFileInfo
            button.isHidden = true
            self.refresh()
        }
        return cell
    }
    
    private func setupLocalFileInfoCell(_ cell: UITableViewCell) -> UITableViewCell {
        cell.textLabel?.text = LString.syncConflictLoadedVersion
        cell.detailTextLabel?.text = formatDescription(localFileInfo)
        return cell
    }
    
    private func setupRemoteFileInfoCell(_ cell: UITableViewCell) -> UITableViewCell {
        cell.textLabel?.text = LString.syncConflictCurrentVersion
        
        let currentVersionDescription: String
        if let remoteFileInfo = remoteFileInfo {
            currentVersionDescription = formatDescription(remoteFileInfo)
        } else {
            currentVersionDescription = remoteFileError?.localizedDescription
                ?? LString.databaseStatusLoading
        }
        cell.detailTextLabel?.text = currentVersionDescription
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
    
    private func formatDescription(_ fileInfo: FileInfo?) -> String {
        var lines = [String]()
        if let modDate = fileInfo?.modificationDate {
            lines.append(dateFormatter.string(from: modDate))
        }
        if let fileSize = fileInfo?.fileSize {
            lines.append(fileSizeFormatter.string(fromByteCount: fileSize))
        }
        return lines.joined(separator: "\n")
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
