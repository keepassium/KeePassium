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
    func didSelectOtherLocations(in viewController: ConnectionTypePickerVC)
}

final class ConnectionTypePickerVC: UITableViewController, Refreshable, BusyStateIndicating {
    private enum Cells {
        static let itemCellID = "itemCell"

        static let sectionCount = 2
        static let connectionTypesSection = 0
        static let otherLocationsSection = 1
    }

    public weak var delegate: ConnectionTypePickerDelegate?

    public var showsOtherLocations = false {
        didSet {
            refresh()
        }
    }
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
            forCellReuseIdentifier: Cells.itemCellID)
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
        if showsOtherLocations {
            return Cells.sectionCount
        } else {
            return Cells.sectionCount - 1
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case Cells.connectionTypesSection:
            return values.count
        case Cells.otherLocationsSection:
            return 1
        default:
            fatalError("Unexpected section ID")
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case Cells.connectionTypesSection:
            return LString.directConnectionDescription
        case Cells.otherLocationsSection:
            return LString.integrationViaFilesAppDescription
        default:
            return nil
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView
            .dequeueReusableCell(withIdentifier: Cells.itemCellID, for: indexPath)
        as! SubtitleCell

        switch indexPath.section {
        case Cells.connectionTypesSection:
            configureConnectionTypeCell(cell, at: indexPath)
        case Cells.otherLocationsSection:
            configureOtherLocationsCell(cell, at: indexPath)
        default:
            fatalError("Unexpected cell index")
        }
        return cell
    }

    private func configureConnectionTypeCell(_ cell: SubtitleCell, at indexPath: IndexPath) {
        let connectionType = values[indexPath.row]
        cell.textLabel?.text = connectionType.description
        cell.imageView?.contentMode = .scaleAspectFit
        cell.imageView?.image = .symbol(connectionType.fileProvider.iconSymbol)

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
    }

    private func configureOtherLocationsCell(_ cell: SubtitleCell, at indexPath: IndexPath) {
        cell.textLabel?.text = LString.connectionTypeOtherLocations
        cell.imageView?.contentMode = .scaleAspectFit
        cell.imageView?.image = nil
        cell.detailTextLabel?.text = nil
        cell.accessoryType = .disclosureIndicator
        cell.setEnabled(ManagedAppConfig.shared.areSystemFileProvidersAllowed)
    }
}

extension ConnectionTypePickerVC {
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if isBusy {
            return nil
        }
        switch indexPath.section {
        case Cells.connectionTypesSection:
            let selectedConnectionType = values[indexPath.row]
            guard selectedConnectionType.fileProvider.isAllowed else {
                showManagedSettingNotification(text: LString.Error.storageAccessDeniedByOrg)
                return nil
            }
            return indexPath
        case Cells.otherLocationsSection:
            guard ManagedAppConfig.shared.areSystemFileProvidersAllowed else {
                showManagedSettingNotification(text: LString.Error.storageAccessDeniedByOrg)
                return nil
            }
            return indexPath
        default:
            fatalError()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case Cells.connectionTypesSection:
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
        case Cells.otherLocationsSection:
            Diag.debug("Switching to system file picker")
            delegate?.didSelectOtherLocations(in: self)
        default:
            fatalError()
        }
    }
}
