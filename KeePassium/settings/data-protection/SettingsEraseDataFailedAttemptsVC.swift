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

protocol SettingsEraseDataFailedAttemptsVCDelegate: AnyObject {
    func didSelectEraseDataAfterFailedAttempts(
        _ option: Settings.PasscodeAttemptsBeforeAppReset,
        in viewController: SettingsEraseDataFailedAttemptsVC)
}

final class SettingsEraseDataFailedAttemptsVC: UITableViewController, Refreshable {
    weak var delegate: SettingsEraseDataFailedAttemptsVCDelegate?

    static func make(delegate: SettingsEraseDataFailedAttemptsVCDelegate? = nil) -> SettingsEraseDataFailedAttemptsVC {
        let vc = Self(style: .insetGrouped)
        vc.delegate = delegate
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LString.eraseDataAfterFailedAttemptsTitle
        registerCellClasses(tableView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    private func registerCellClasses(_ tableView: UITableView) {
        tableView.register(
            SubtitleCell.self,
            forCellReuseIdentifier: SubtitleCell.reuseIdentifier
        )
    }

    func refresh() {
        tableView.reloadSections([0], with: .automatic)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Settings.PasscodeAttemptsBeforeAppReset.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: SubtitleCell.reuseIdentifier,
            for: indexPath) as! SubtitleCell
        configureCell(cell, at: indexPath)
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return LString.eraseDataAfterFailedAttemptsFootnote
    }

    private func configureCell(_ cell: SubtitleCell, at indexPath: IndexPath) {
        let option = Settings.PasscodeAttemptsBeforeAppReset.allCases[indexPath.row]
        let isCurrent = option == Settings.current.passcodeAttemptsBeforeAppReset

        cell.textLabel?.text = option.title
        cell.accessoryType = isCurrent ? .checkmark : .none
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = Settings.PasscodeAttemptsBeforeAppReset.allCases[indexPath.row]
        delegate?.didSelectEraseDataAfterFailedAttempts(option, in: self)
    }
}

// swiftlint:disable line_length
extension LString {
    public static let eraseDataAfterFailedAttemptsFootnote = NSLocalizedString(
        "[Settings/EraseDataFailedAttempts/footnote]",
        value: "If enabled, all databases and keys will be permanently erased after the selected number of failed passcode attempts.",
        comment: "Description for the 'Erase data after failed attempts' setting")
}
// swiftlint:enable line_length
