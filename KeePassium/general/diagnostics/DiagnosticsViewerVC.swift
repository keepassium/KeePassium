//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DiagnosticsViewerDelegate: AnyObject {
    func didPressCopy(text: String, in diagnosticsViewer: DiagnosticsViewerVC)
    func didPressContactSupport(
        text: String,
        at popoverAnchor: PopoverAnchor,
        in diagnosticsViewer: DiagnosticsViewerVC
    )
}

class DiagnosticsViewerVC: UITableViewController, Refreshable {
    private static let cellID = "Cell"

    weak var delegate: DiagnosticsViewerDelegate?

    private weak var contactSupportButtonItem: UIBarButtonItem!
    private var items: [Diag.Item] = [] {
        didSet {
            refresh()
        }
    }

    public static func create() -> DiagnosticsViewerVC {
        return DiagnosticsViewerVC(style: .plain)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = false
        tableView.register(UITableViewCell.classForCoder(), forCellReuseIdentifier: Self.cellID)

        title = LString.titleDiagnosticLog
        configureToolbars()

        items = Diag.itemsSnapshot()

        refresh()
        if items.count > 0 {
            let lastRowIndexPath = IndexPath(row: items.count - 1, section: 0)
            DispatchQueue.main.async { 
                self.tableView.scrollToRow(at: lastRowIndexPath, at: .none, animated: true)
            }
        }
    }

    private func configureToolbars() {
        let copyToClipboardAction = UIAction(
            title: LString.actionCopy,
            image: .symbol(.docOnDoc),
            handler: didPressCopy(_:)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(primaryAction: copyToClipboardAction)

        let contactSupportAction = UIAction(
            title: LString.actionContactSupport,
            handler: didPressContactSupport(_:)
        )
        let contactSupportItem = UIBarButtonItem(primaryAction: contactSupportAction)
        self.contactSupportButtonItem = contactSupportItem

        toolbarItems = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            contactSupportButtonItem,
            UIBarButtonItem(systemItem: .flexibleSpace)
        ]
    }

    func refresh() {
        guard isViewLoaded else { return }
        tableView.reloadData()
    }


    private func didPressCopy(_ sender: Any) {
        Watchdog.shared.restart()
        let logText = Diag.toString()
        delegate?.didPressCopy(text: logText, in: self)
    }

    private func didPressContactSupport(_ sender: Any) {
        Watchdog.shared.restart()
        let logText = Diag.toString()
        let popoverAnchor = PopoverAnchor(barButtonItem: contactSupportButtonItem)
        delegate?.didPressContactSupport(text: logText, at: popoverAnchor, in: self)
    }


    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let item = items[indexPath.row]
        var content = buildContent()
        content.text = "\(item.file):\(item.line)\n\(item.function)"
        content.secondaryText = item.message

        let cell = tableView.dequeueReusableCell(
            withIdentifier: DiagnosticsViewerVC.cellID,
            for: indexPath)
        cell.contentConfiguration = content
        return cell
    }

    private func buildContent() -> UIListContentConfiguration {
        var content = UIListContentConfiguration.subtitleCell()
        content.textProperties.font = .preferredFont(forTextStyle: .caption1)
        content.textProperties.color = .secondaryLabel

        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .callout)
        content.secondaryTextProperties.color = .label

        content.textToSecondaryTextVerticalPadding = 4.0
        content.directionalLayoutMargins = .init(top: 8, leading: 8, bottom: 8, trailing: 8)
        return content
    }
}
