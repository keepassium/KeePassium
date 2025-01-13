//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class SwitchCell: UITableViewCell {
    public static let reuseIdentifier = "SwitchCell"

    typealias ToggleHandler = (UISwitch) -> Void

    var onDidToggleSwitch: ToggleHandler?

    lazy var theSwitch: UISwitch = {
        let theSwitch = UISwitch(frame: .zero)
        return theSwitch
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        configureCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        configureCell()
    }

    private func configureCell() {
        selectionStyle = .none

        textLabel?.font = .preferredFont(forTextStyle: .body)
        textLabel?.textColor = .primaryText
        textLabel?.numberOfLines = 0
        textLabel?.lineBreakMode = .byWordWrapping

        detailTextLabel?.font = .preferredFont(forTextStyle: .footnote)
        detailTextLabel?.textColor = .auxiliaryText
        detailTextLabel?.numberOfLines = 0
        detailTextLabel?.lineBreakMode = .byWordWrapping

        imageView?.preferredSymbolConfiguration = .init(textStyle: .body, scale: .large)

        accessoryType = .none
        accessoryView = theSwitch

        let toggleHandlerAction = UIAction { [weak self] _ in
            guard let self = self else { return }
            self.onDidToggleSwitch?(self.theSwitch)
        }
        theSwitch.addAction(toggleHandlerAction, for: .valueChanged)
    }

    override func setEnabled(_ isEnabled: Bool) {
        super.setEnabled(isEnabled)
        theSwitch.isEnabled = isEnabled
    }
}
