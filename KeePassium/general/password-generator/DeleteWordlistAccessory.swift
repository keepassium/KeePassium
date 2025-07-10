//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class DeleteWordlistAccessory: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        setImage(.symbol(.ellipsis), for: .normal)
        setPreferredSymbolConfiguration(.init(scale: .default), forImageIn: .normal)
        accessibilityLabel = LString.titleMoreActions

        showsMenuAsPrimaryAction = true
        let deleteAction = UIAction(
            title: LString.actionDelete,
            image: .symbol(.trash),
            attributes: .destructive,
            handler: { [weak self] _ in
                self?.sendActions(for: .touchUpInside)
            }
        )
        menu = UIMenu(children: [deleteAction])
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: 32, height: 32)
    }
}
