//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
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
    case showQRCode

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
        case .showQRCode:
            return LString.actionShowAsQRCode
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
        case .showQRCode:
            return .symbol(.qrcode)
        }
    }
}

@available(iOS 17.4, *)
final class EntryFieldMenuButton: UIButton {
    typealias CompletionHandler = (ViewableFieldAction) -> Void
    private let actions: [ViewableFieldAction]
    private let completion: CompletionHandler

    private var isReshowing = false

    init(
        actions: [ViewableFieldAction],
        completion: @escaping CompletionHandler
    ) {
        self.actions = actions
        self.completion = completion
        super.init(frame: .zero)
        configureMenu()
    }

    private func configureMenu() {
        showsMenuAsPrimaryAction = true
        var fieldActions = actions.map { action in
            UIAction(title: action.title, image: action.icon) { [weak self] _ in
                self?.completion(action)
            }
        }

        let toggleMenuModeAction = UIAction(
            title: LString.titleFieldMenuCompactView,
            image: .symbol(.rectangleCompressVertical)
        ) { [weak self] _ in
            guard let self else { return }
            switch Settings.current.fieldMenuMode {
            case .full:
                Settings.current.fieldMenuMode = .compact
            case .compact:
                Settings.current.fieldMenuMode = .full
            }

            isReshowing = true
            DispatchQueue.main.async {
                self.configureMenu()
                self.performPrimaryAction()
            }
        }

        switch Settings.current.fieldMenuMode {
        case .full:
            toggleMenuModeAction.state = .off
            menu = UIMenu(options: [.displayInline], children: [
                UIMenu(options: .displayInline, children: fieldActions),
                UIMenu(options: .displayInline, children: [toggleMenuModeAction]),
            ])
        case .compact:
            toggleMenuModeAction.state = .on
            fieldActions.append(toggleMenuModeAction)
            menu = UIMenu(options: [.displayInline, .displayAsPalette], children: fieldActions)
        }
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
        if isReshowing {
            isReshowing = false
        } else {
            removeFromSuperview()
        }
    }
}
