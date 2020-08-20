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

class FileInfoVC: UITableViewController {
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    public var onDismiss: (()->())?
    
    public var canExport: Bool = false {
        didSet {
            setupButtons()
        }
    }
    
    private var fields = [(String, String)]()
    private var urlRef: URLReference!
    private var fileType: FileType!

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
        var preferredSize = tableView.contentSize
        if #available(iOS 13, *) {
            preferredSize.width = 400
        }
        self.preferredContentSize = preferredSize
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
        
        urlRef.refreshInfo { [weak self] result in
            guard let self = self else { return }
            self.fields.removeAll(keepingCapacity: true)
            self.refreshFixedFields()
            switch result {
            case .success(let fileInfo):
                self.addFields(from: fileInfo)
            case .failure(let accessError):
                self.fields.append((
                    FieldTitle.error,
                    accessError.localizedDescription
                ))
            }
            self.tableView.reloadSections([0], with: .fade) 
            if let refreshControl = self.tableView.refreshControl, refreshControl.isRefreshing {
                refreshControl.endRefreshing()
                self.tableView.refreshControl = nil
            }
        }
    }
    
    private func refreshFixedFields() {
        if fields.isEmpty {
            fields.append(("", ""))
            fields.append(("", ""))
        }
        fields[0] = ((FieldTitle.fileName, urlRef.visibleFileName))
        fields[1] = ((FieldTitle.fileLocation, getFileLocationValue()))
    }
    
    private func getFileLocationValue() -> String {
        if let fileProvider = urlRef.fileProvider {
            return fileProvider.localizedName
        }
        return urlRef.location.description
    }
    
    private func addFields(from fileInfo: FileInfo) {
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
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fields.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: FileInfoCell.storyboardID,
            for: indexPath)
            as! FileInfoCell
        
        let fieldIndex = indexPath.row
        cell.name = fields[fieldIndex].0
        cell.value = fields[fieldIndex].1
        return cell
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
                    self?.onDismiss?()
                } else {
                }
            }
        )
    }
}
