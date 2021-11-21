//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseSettingsDelegate: AnyObject {
    func didPressClose(in viewController: DatabaseSettingsVC)
    func canChangeReadOnly(in viewController: DatabaseSettingsVC) -> Bool
    func didChangeSettings(isReadOnlyFile: Bool, in viewController: DatabaseSettingsVC)
}

final class DatabaseSettingsVC: UITableViewController, Refreshable {
    weak var delegate: DatabaseSettingsDelegate?
    var isReadOnlyAccess: Bool!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = LString.titleDatabaseSettings
        
        tableView.register(
            UINib(nibName: SwitchCell.reuseIdentifier, bundle: nil),
            forCellReuseIdentifier: SwitchCell.reuseIdentifier
        )
        setupCloseButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }
    
    func refresh() {
        tableView.reloadData()
    }
    
    private func setupCloseButton() {
        let closeBarButton = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction(
                title: LString.actionDone,
                image: nil,
                attributes: [],
                handler: { [weak self] _ in
                    guard let self = self else { return }
                    self.delegate?.didPressClose(in: self)
                }
            ),
            menu: nil)
        navigationItem.rightBarButtonItem = closeBarButton
    }
}

extension DatabaseSettingsVC {
    enum Section: Int, CaseIterable {
        case fileAccess = 0
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .fileAccess:
            return 1
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        switch Section(rawValue: section)! {
        case .fileAccess:
            return LString.titleSettingsFileAccess
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: SwitchCell.reuseIdentifier,
            for: indexPath)
            as! SwitchCell
        switch Section(rawValue: indexPath.section)! {
        case .fileAccess:
            configureFileAccessSectionCell(cell, row: indexPath.row)
        }
        return cell
    }
    
    private func configureFileAccessSectionCell(_ cell: SwitchCell, row: Int) {
        switch row {
        case 0:
            cell.titleLabel.text = LString.titleFileAccessReadOnly
            cell.theSwitch.isEnabled = delegate?.canChangeReadOnly(in: self) ?? false
            cell.theSwitch.isOn = isReadOnlyAccess
            cell.toggleHandler = { [weak self] theSwitch in
                guard let self = self else { return }
                self.isReadOnlyAccess = theSwitch.isOn
                self.delegate?.didChangeSettings(isReadOnlyFile: theSwitch.isOn, in: self)
            }
        default:
            preconditionFailure()
        }
    }
}
