//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol RemoteFolderViewerDelegate: AnyObject {
    func didSelectItem(_ item: RemoteFileItem, in viewController: RemoteFolderViewerVC)
}

final class RemoteFolderViewerVC: UITableViewController {
    private enum CellID {
        static let folderCell = "FolderCell"
        static let fileCell = "FileCell"
    }
    
    weak var delegate: RemoteFolderViewerDelegate?
    
    var folderName = "/" {
        didSet {
            navigationItem.title = folderName
        }
    }
    var items = [RemoteFileItem]() {
        didSet {
            sortItems()
            refresh()
        }
    }
    
    private var sortedFolders = [RemoteFileItem]()
    private var sortedFiles = [RemoteFileItem]()
    
    private let fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.formattingContext = .listItem
        formatter.countStyle = .file
        return formatter
    }()
    
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .medium
        dateFormatter.doesRelativeDateFormatting = true
        dateFormatter.formattingContext = .listItem
        return dateFormatter
    }()
    
    public static func make() -> RemoteFolderViewerVC {
        return RemoteFolderViewerVC.init(style: .plain)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        
        tableView.register(
            SubtitleCell.classForCoder(),
            forCellReuseIdentifier: CellID.folderCell)
        tableView.register(
            SubtitleCell.classForCoder(),
            forCellReuseIdentifier: CellID.fileCell)
        
        setupEmptyView(tableView)
        refresh()
    }
    
    private func setupEmptyView(_ tableView: UITableView) {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .auxiliaryText
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.text = LString.titleFolderIsEmpty
        label.textAlignment = .center
        
        tableView.backgroundView = label
    }
    
    func refresh() {
        guard isViewLoaded else {
            return
        }
        tableView.backgroundView?.isHidden = !items.isEmpty
        tableView.reloadData()
    }
    
    private func sortItems() {
        sortedFolders.removeAll(keepingCapacity: true)
        sortedFiles.removeAll(keepingCapacity: true)
        sortedFolders = items.filter { $0.isFolder }
        sortedFiles = items.filter { !$0.isFolder }
    }
}

extension RemoteFolderViewerVC {
    private func isFolderItem(at indexPath: IndexPath) -> Bool {
        return indexPath.row < sortedFolders.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedFolders.count + sortedFiles.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell: UITableViewCell
        if isFolderItem(at: indexPath) {
            cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.folderCell,
                for: indexPath)
            let folderIndex = indexPath.row
            configureFolderCell(cell as! SubtitleCell, item: sortedFolders[folderIndex])
        } else {
            cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.fileCell,
                for: indexPath)
            let fileIndex = indexPath.row - sortedFolders.count
            configureFileCell(cell as! SubtitleCell, item: sortedFiles[fileIndex])
        }
        return cell
    }
    
    private func configureFolderCell(_ cell: SubtitleCell, item: RemoteFileItem) {
        cell.textLabel?.font = .preferredFont(forTextStyle: .headline)
        cell.textLabel?.text = item.fileInfo.fileName
        
        cell.detailTextLabel?.text = nil
        cell.accessoryType = .disclosureIndicator
    }
    
    private func configureFileCell(_ cell: SubtitleCell, item: RemoteFileItem) {
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.text = item.fileInfo.fileName
        
        var details = [String]()
        if let fileSize = item.fileInfo.fileSize {
            let sizeString = fileSizeFormatter.string(fromByteCount: fileSize)
            details.append(sizeString)
        }
        if let modificationDate = item.fileInfo.modificationDate {
            let dateString = dateFormatter.string(from: modificationDate)
            details.append(dateString)
        }

        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .footnote)
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.text = details.joined(separator: " · ")
        cell.accessoryType = .none
    }
}

extension RemoteFolderViewerVC {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selectedItem: RemoteFileItem
        if isFolderItem(at: indexPath) {
            let folderIndex = indexPath.row
            selectedItem = sortedFolders[folderIndex]
        } else {
            let fileIndex = indexPath.row - sortedFolders.count
            selectedItem = sortedFiles[fileIndex]
        }
        delegate?.didSelectItem(selectedItem, in: self)
    }
}
