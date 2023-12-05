//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import UIKit

final class PasswordAuditResultCell: UITableViewCell {


    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var exposuresLabel: UILabel!


    var model: PasswordAuditService.PasswordAudit? {
        didSet {
            refresh()
        }
    }
    var isEdited: Bool? {
        didSet {
            refresh()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        multipleSelectionBackgroundView = UIView()
    }

    private func refresh() {
        guard let model else { return }

        iconView.image = UIImage.kpIcon(forEntry: model.entry)
        titleLabel.text = model.entry.resolvedTitle
        subtitleLabel.text = model.entry.getGroupPath()
        if isEdited ?? false {
            exposuresLabel.text = LString.statusItemEdited
        } else {
            exposuresLabel.text = ExposureCountFormatter.string(fromExposureCount: model.count)
        }
    }
}
