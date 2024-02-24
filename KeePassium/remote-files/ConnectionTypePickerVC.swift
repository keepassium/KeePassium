//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol ConnectionTypePickerDelegate: AnyObject {
    func isConnectionTypeEnabled(
        _ connectionType: RemoteConnectionType,
        in viewController: ConnectionTypePickerVC) -> Bool

    func willSelect(
        connectionType: RemoteConnectionType,
        in viewController: ConnectionTypePickerVC) -> Bool
    func didSelect(connectionType: RemoteConnectionType, in viewController: ConnectionTypePickerVC)
}

final class ConnectionTypePickerVC: UITableViewController, Refreshable, BusyStateIndicating {
    private enum CellID {
        static let itemCell = "itemCell"
    }

    public weak var delegate: ConnectionTypePickerDelegate?

    public let values = RemoteConnectionType.allValues
    public var selectedValue: RemoteConnectionType?

    private lazy var titleView: SpinnerLabel = {
        let view = SpinnerLabel(frame: .zero)
        view.label.text = LString.titleConnection
        view.label.font = .preferredFont(forTextStyle: .headline)
        view.spinner.startAnimating()
        return view
    }()
    private var isBusy = false

    public static func make() -> ConnectionTypePickerVC {
        return ConnectionTypePickerVC(style: .insetGrouped)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.titleView = titleView
        navigationItem.title = titleView.label.text

        tableView.register(
            SubtitleCell.classForCoder(),
            forCellReuseIdentifier: CellID.itemCell)
        tableView.allowsSelection = true
    }

    func refresh() {
        tableView.reloadData()
    }

    public func indicateState(isBusy: Bool) {
        titleView.showSpinner(isBusy, animated: true)
        self.isBusy = isBusy
        refresh()
    }
}

extension ConnectionTypePickerVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return values.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView
            .dequeueReusableCell(withIdentifier: CellID.itemCell, for: indexPath)
            as! SubtitleCell

        let connectionType = values[indexPath.row]
        cell.textLabel?.text = connectionType.description
        cell.imageView?.contentMode = .scaleAspectFit
        cell.imageView?.image = .symbol(connectionType.fileProvider.iconSymbol)
        cell.selectionStyle = .default

        let isAllowed = connectionType.fileProvider.isAllowed
        cell.detailTextLabel?.text = isAllowed ? nil : LString.Error.storageAccessDeniedByOrg

        let isEnabled = delegate?.isConnectionTypeEnabled(connectionType, in: self) ?? true
        cell.setEnabled(isEnabled && isAllowed && !isBusy)

        if connectionType.isPremiumUpgradeRequired {
            cell.accessoryType = .none
            cell.accessoryView = PremiumBadgeAccessory()
        } else {
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }
}

extension ConnectionTypePickerVC {
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if isBusy {
            return nil
        }
        let selectedConnectionType = values[indexPath.row]
        guard selectedConnectionType.fileProvider.isAllowed else {
            showManagedSettingNotification(text: LString.Error.storageAccessDeniedByOrg)
            return nil
        }
        return indexPath
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedConnectionType = values[indexPath.row]
        let isEnabled = delegate?.isConnectionTypeEnabled(selectedConnectionType, in: self) ?? true
        let canSelect = delegate?.willSelect(connectionType: selectedConnectionType, in: self) ?? false
        guard isEnabled && canSelect else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        self.selectedValue = selectedConnectionType
        tableView.reloadData()
        delegate?.didSelect(connectionType: selectedConnectionType, in: self)
    }
}
