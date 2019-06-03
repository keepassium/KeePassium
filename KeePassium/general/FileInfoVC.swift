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
}

class FileInfoVC: UITableViewController {
    private var fields = [(String, String)]()
    
    public static func make(urlRef: URLReference, popoverSource: UIView?) -> FileInfoVC {
        let vc = FileInfoVC.instantiateFromStoryboard()
        vc.setupFields(urlRef: urlRef)
        
        if let popoverSource = popoverSource {
            vc.modalPresentationStyle = .popover
            if let popover = vc.popoverPresentationController {
                popover.sourceView = popoverSource
                popover.sourceRect = popoverSource.bounds
                popover.permittedArrowDirections = [.left]
                popover.delegate = vc
            }
        }
        return vc
    }
    
    private func setupFields(urlRef: URLReference) {
        let fileInfo = urlRef.info
        if let errorMessage = fileInfo.errorMessage {
            fields.append((
                NSLocalizedString("Error", comment: "[FileInfo] Title of a field with an error message"),
                errorMessage
            ))
        }
        fields.append((
            NSLocalizedString("File Name", comment: "[FileInfo] Field title"),
            fileInfo.fileName
        ))
        fields.append((
            NSLocalizedString("File Location", comment: "[FileInfo] Field title"),
            urlRef.location.description
        ))
        if let fileSize = fileInfo.fileSize {
            fields.append((
                NSLocalizedString("File Size", comment: "[FileInfo] Field title"),
                ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            ))
        }
        if let creationDate = fileInfo.creationDate {
            fields.append((
                NSLocalizedString("Creation Date", comment: "[FileInfo] Field title"),
                DateFormatter.localizedString(
                    from: creationDate,
                    dateStyle: .medium,
                    timeStyle: .medium)
            ))
        }
        if let modificationDate = fileInfo.modificationDate {
            fields.append((
                NSLocalizedString("Last Modification Date", comment: "[FileInfo] Field title"),
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
        preferredContentSize = tableView.contentSize
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

extension FileInfoVC: UIPopoverPresentationControllerDelegate {
    func presentationController(
        _ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle
        ) -> UIViewController?
    {
        let navVC = UINavigationController(rootViewController: controller.presentedViewController)
        if style != .popover {
            let doneButton = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(dismissPopover))
            navVC.topViewController?.navigationItem.rightBarButtonItem = doneButton
        }
        return navVC
    }
    
    @objc
    private func dismissPopover() {
        dismiss(animated: true, completion: nil)
    }
}
