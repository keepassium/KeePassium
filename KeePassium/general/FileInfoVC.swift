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
    private var fields = [(String, String)]()
    
    private var dismissablePopoverDelegate = DismissablePopover()
    
    public static func make(urlRef: URLReference, at popoverAnchor: PopoverAnchor?) -> FileInfoVC {
        let vc = FileInfoVC.instantiateFromStoryboard()
        vc.setupFields(urlRef: urlRef)
        
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
    
    private func setupFields(urlRef: URLReference) {
        let fileInfo = urlRef.info
        if let errorMessage = fileInfo.errorMessage {
            fields.append((
                NSLocalizedString(
                    "[FileInfo/Field/valueError] Error",
                    value: "Error",
                    comment: "Title of a field with an error message"),
                errorMessage
            ))
        }
        fields.append((
            NSLocalizedString(
                "[FileInfo/Field/title] File Name",
                value: "File Name",
                comment: "Field title"),
            fileInfo.fileName
        ))
        fields.append((
            NSLocalizedString(
                "[FileInfo/Field/title] File Location",
                value: "File Location",
                comment: "Field title"),
            urlRef.location.description
        ))
        if let fileSize = fileInfo.fileSize {
            fields.append((
                NSLocalizedString(
                    "[FileInfo/Field/title] File Size",
                    value: "File Size",
                    comment: "Field title"),
                ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            ))
        }
        if let creationDate = fileInfo.creationDate {
            fields.append((
                NSLocalizedString(
                    "[FileInfo/Field/title] Creation Date",
                    value: "Creation Date",
                    comment: "Field title"),
                DateFormatter.localizedString(
                    from: creationDate,
                    dateStyle: .medium,
                    timeStyle: .medium)
            ))
        }
        if let modificationDate = fileInfo.modificationDate {
            fields.append((
                NSLocalizedString(
                    "[FileInfo/Field/title] Last Modification Date",
                    value: "Last Modification Date",
                    comment: "Field title"),
                DateFormatter.localizedString(
                    from: modificationDate,
                    dateStyle: .medium,
                    timeStyle: .medium)
            ))
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
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
}
