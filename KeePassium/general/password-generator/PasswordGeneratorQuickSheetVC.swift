//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

enum QuickRandomTextMode: Int, CaseIterable, CustomStringConvertible {
    case basic = 0
    case expert = 1
    case passphrase = 2

    var description: String {
        switch self {
        case .basic:
            return LString.PasswordGeneratorMode.titleBasicMode
        case .expert:
            return LString.PasswordGeneratorMode.titleExpertMode
        case .passphrase:
            return LString.PasswordGeneratorMode.titlePassphraseMode
        }
    }

    var optimalLineBreakMode: NSLineBreakMode {
        switch self {
        case .basic,
             .expert:
            return .byCharWrapping
        case .passphrase:
            return .byWordWrapping
        }
    }

    var accessibilityShouldSpellOut: Bool {
        switch self {
        case .basic,
             .expert:
            return true
        case .passphrase:
            return false
        }
    }
}

protocol PasswordGeneratorQuickSheetDelegate: AnyObject {
    func didRequestFullMode(in viewController: PasswordGeneratorQuickSheetVC)
    func didPressCopy(_ text: String, inView: UIView?, in viewController: PasswordGeneratorQuickSheetVC)
    func didSelectItem(_ text: String, view: UIView?, in viewController: PasswordGeneratorQuickSheetVC)
    func shouldGenerateText(
        mode: QuickRandomTextMode,
        in viewController: PasswordGeneratorQuickSheetVC) -> String?
}

final class PasswordGeneratorQuickSheetVC: UITableViewController, Refreshable {
    weak var delegate: PasswordGeneratorQuickSheetDelegate?
    private typealias DataItem = (mode: QuickRandomTextMode, text: String)

    private lazy var items: [DataItem] = generateItems()
    private var preferredContentSizeObservation: NSKeyValueObservation?

    init() {
        super.init(style: .insetGrouped)

        tableView.register(
            PasswordGeneratorQuickSheetVC.Cell.classForCoder(),
            forCellReuseIdentifier: PasswordGeneratorQuickSheetVC.Cell.reuseIdentifier)
        tableView.bounces = false
        tableView.estimatedSectionHeaderHeight = 18

        title = LString.PasswordGenerator.titleRandomGenerator

        let fullModeButton = UIBarButtonItem(
            title: LString.PasswordGenerator.titleRandomGenerator,
            image: .symbol(.gearshape2),
            primaryAction: UIAction { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.didRequestFullMode(in: self)
            }
        )
        let refreshButton = UIBarButtonItem(
            systemItem: .refresh,
            primaryAction: UIAction { [weak self] _ in
                self?.refresh()
            }
        )
        navigationItem.rightBarButtonItem = fullModeButton
        setToolbarItems(
            [
                UIBarButtonItem(systemItem: .flexibleSpace),
                refreshButton,
                UIBarButtonItem(systemItem: .flexibleSpace),
            ],
            animated: false
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if popoverPresentationController?.presentationStyle == .popover {
            setupPreferredContentSize()
        }
    }

    private func setupPreferredContentSize() {
        preferredContentSizeObservation = tableView.observe(\.contentSize) { [weak self] _, _ in
            guard let self else { return }
            guard self.navigationController?.viewControllers.count == 1 else {
                return
            }
            let newPreferredSize = CGSize(
                width: 400,
                height: self.tableView.contentSize.height
            )

            DispatchQueue.main.async {
                self.preferredContentSize = newPreferredSize
            }
        }
    }

    func refresh() {
        items = generateItems()
        tableView.reloadData()
    }

    private func generateItems() -> [DataItem] {
        guard let delegate = delegate else {
            assertionFailure("This won't work without a delegate.")
            return []
        }

        let result = QuickRandomTextMode.allCases.compactMap { mode -> DataItem? in
            if let text = delegate.shouldGenerateText(mode: mode, in: self) {
                return (mode, text)
            } else {
                return nil
            }
        }
        return result
    }
}

extension PasswordGeneratorQuickSheetVC {
    private class Cell: UITableViewCell {
        static let reuseIdentifier = "Cell"
        var onDidPressCopy: ((UIView) -> Void)?

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
            textLabel?.font = .preferredFont(forTextStyle: .footnote)
            textLabel?.textColor = .auxiliaryText
            textLabel?.numberOfLines = 0
            textLabel?.lineBreakMode = .byWordWrapping
            textLabel?.accessibilityTraits = [.header]

            detailTextLabel?.font = .preferredFont(forTextStyle: .body)
            detailTextLabel?.textColor = .primaryText
            detailTextLabel?.numberOfLines = 0
            detailTextLabel?.lineBreakMode = .byCharWrapping

            let copyButton = UIButton(
                type: .system,
                primaryAction: UIAction { [weak self] _ in
                    guard let self else { return }
                    self.onDidPressCopy?(self.contentView)
                }
            )
            copyButton.setImage(.symbol(.docOnDoc), for: .normal)
            copyButton.sizeToFit()
            copyButton.accessibilityLabel = LString.actionCopy
            accessoryView = copyButton

            accessibilityElements = [textLabel as Any, detailTextLabel as Any, accessoryView as Any]
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

extension PasswordGeneratorQuickSheetVC {
    private func getMode(forSection section: Int) -> QuickRandomTextMode {
        guard let mode = QuickRandomTextMode(rawValue: section) else {
            fatalError("Unexpected row number")
        }
        return mode
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return items.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: Cell.reuseIdentifier,
            for: indexPath)
            as! Cell

        let item = items[indexPath.section]
        cell.textLabel?.text = item.mode.description
        cell.detailTextLabel?.attributedText = PasswordStringHelper.decorate(
            item.text,
            font: .monospaceFont(style: .body)
        )
        cell.detailTextLabel?.lineBreakMode = item.mode.optimalLineBreakMode
        cell.detailTextLabel?.accessibilityAttributedLabel = NSAttributedString(
            string: item.text,
            attributes: [.accessibilitySpeechSpellOut: item.mode.accessibilityShouldSpellOut]
        )
        cell.onDidPressCopy = { [weak self] contentView in
            guard let self = self else { return }
            self.delegate?.didPressCopy(item.text, inView: contentView, in: self)
        }
        return cell
    }
}

extension PasswordGeneratorQuickSheetVC {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedItem = items[indexPath.section]
        let selectedCell = tableView.cellForRow(at: indexPath)
        delegate?.didSelectItem(selectedItem.text, view: selectedCell?.contentView, in: self)
    }
}
