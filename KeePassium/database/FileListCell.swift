//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class FileListCellFactory {
    public static func dequeueReusableCell(
        from tableView: UITableView,
        withIdentifier identifier: String,
        for indexPath: IndexPath,
        for fileType: FileType
    ) -> FileListCell {
        let cell = tableView
            .dequeueReusableCell(withIdentifier: identifier, for: indexPath)
            as! FileListCell
        cell.fileType = fileType
        return cell
    }
}

class FileInfoAccessoryButton: UIButton {
    required init() {
        super.init(frame: .zero)
        setImage(.symbol(.ellipsis), for: .normal)
        contentMode = .scaleAspectFit
        accessibilityLabel = LString.actionShowDetails
        sizeToFit()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
}

class FileListCell: UITableViewCell {
    @IBOutlet weak var fileIconView: UIImageView!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var fileDetailLabel: UILabel!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    private var accessoryButton: FileInfoAccessoryButton! 

    var accessoryMenu: UIMenu? {
        get { accessoryButton.menu }
        set {
            accessoryButton?.menu = newValue
            accessoryButton.showsMenuAsPrimaryAction = (newValue != nil)
        }
    }
    var accessoryTapHandler: ((FileListCell) -> Void)? 

    fileprivate(set) var fileType: FileType!

    override func awakeFromNib() {
        super.awakeFromNib()

        accessoryButton = FileInfoAccessoryButton()
        setupCell()
    }

    private func setupCell() {
        spinner.style = .medium
        accessoryView = accessoryButton
        accessoryButton.addTarget(
            self,
            action: #selector(didPressAccessoryButton(button:)),
            for: .touchUpInside)
    }

    @objc
    private func didPressAccessoryButton(button: UIButton) {
        accessoryTapHandler?(self)
    }

    public func showInfo(from urlRef: URLReference) {
        fileNameLabel?.text = urlRef.visibleFileName

        if let error = urlRef.error {
            showFileError(error, for: urlRef)
            return
        }

        urlRef.getCachedInfo(canFetch: false) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let fileInfo):
                self.showFileInfo(fileInfo, for: urlRef)
            case .failure:
                self.showFileError(urlRef.error, for: urlRef)
            }
        }
    }

    private func showFileInfo(_ fileInfo: FileInfo, for urlRef: URLReference) {
        let iconSymbol = urlRef.getIconSymbol(fileType: fileType)
        fileIconView?.image = .symbol(iconSymbol)
        fileIconView?.sizeToFit()
        if let modificationDate = fileInfo.modificationDate {
            let dateString = DateFormatter.localizedString(
                from: modificationDate,
                dateStyle: .long,
                timeStyle: .medium)
            fileDetailLabel?.text = dateString
        } else {
            fileDetailLabel?.text = nil
        }
        fileDetailLabel?.textColor = UIColor.auxiliaryText
    }

    private func showFileError(_ error: FileAccessError?, for urlRef: URLReference) {
        let iconSymbol = urlRef.getIconSymbol(fileType: fileType)
        guard let error = error else {
            self.fileDetailLabel?.text = "..."
            self.fileIconView?.image = .symbol(iconSymbol)
            self.fileIconView?.sizeToFit()
            return
        }
        self.fileDetailLabel?.text = error.localizedDescription
        self.fileDetailLabel?.textColor = UIColor.errorMessage
        self.fileIconView?.image = .symbol(iconSymbol)
        self.fileIconView?.sizeToFit()
        sizeToFit()
    }

    var isAnimating: Bool {
        get { spinner.isAnimating }
        set {
            if newValue {
                spinner.isHidden = false
                spinner.startAnimating()
            } else {
                spinner.stopAnimating()
                spinner.isHidden = true
            }
        }
    }
}
