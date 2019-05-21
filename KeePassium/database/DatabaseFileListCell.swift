//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class DatabaseFileListCell: UITableViewCell {
    var urlRef: URLReference! {
        didSet {
            setupCell()
        }
    }
    
    private func setupCell() {
        let fileInfo = urlRef.getInfo()
        textLabel?.text = fileInfo.fileName
        if fileInfo.hasError {
            detailTextLabel?.text = fileInfo.errorMessage
            detailTextLabel?.textColor = UIColor.errorMessage
            imageView?.image = UIImage(asset: .databaseErrorListitem)
        } else {
            imageView?.image = UIImage.databaseIcon(for: urlRef)
            if let modificationDate = fileInfo.modificationDate {
                let dateString = DateFormatter.localizedString(
                    from: modificationDate,
                    dateStyle: .long,
                    timeStyle: .medium)
                detailTextLabel?.text = dateString
            } else {
                detailTextLabel?.text = nil
            }
            detailTextLabel?.textColor = UIColor.auxiliaryText
        }
    }
}
