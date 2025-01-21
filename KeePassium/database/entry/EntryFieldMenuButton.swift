//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib
import UIKit

enum ViewableFieldAction: CaseIterable {
    case copy
    case export
    case copyReference
    case showLargeType

    var title: String {
        switch self {
        case .copy:
            return LString.actionCopy
        case .export:
            return LString.actionExport
        case .copyReference:
            return LString.actionCopyFieldReference
        case .showLargeType:
            return LString.actionShowTextInLargeType
        }
    }

    var icon: UIImage? {
        switch self {
        case .copy:
            return .symbol(.docOnDoc)
        case .export:
            return .symbol(.squareAndArrowUp)
        case .copyReference:
            return .symbol(.fieldReference)
        case .showLargeType:
            return .symbol(.largeType)
        }
    }

    var hapticFeedback: HapticFeedback.Kind? {
        switch self {
        case .copy,
             .copyReference:
            return .copiedToClipboard
        case .export,
             .showLargeType:
            return nil
        }
    }
}

@available(iOS 17.4, *)
final class EntryFieldMenuButton: UIButton {
    init(
        actions: [ViewableFieldAction],
        completion: @escaping (ViewableFieldAction) -> Void
    ) {
        super.init(frame: .zero)
        showsMenuAsPrimaryAction = true
        menu = UIMenu(children: actions.map { action in
            UIAction(title: action.title, image: action.icon) { _ in
                HapticFeedback.play(action.hapticFeedback)
                completion(action)
            }
        })
        preferredMenuElementOrder = .priority
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showMenuInCell(_ cell: UITableViewCell) {
        self.frame = .init(
            x: cell.bounds.midX,
            y: cell.bounds.minY,
            width: 1.0,
            height: cell.bounds.height)
        cell.contentView.addSubview(self)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor)
        ])
        HapticFeedback.play(.contextMenuOpened)
        performPrimaryAction()
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        removeFromSuperview()
    }
}
