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

protocol SettingsShakeGestureActionVCDelegate: AnyObject {
    func didSelectShakeGesture(
        _ action: Settings.ShakeGestureAction,
        in viewController: SettingsShakeGestureActionVC)
    func didSetShakeGestureConfirmation(
        _ shouldConfirm: Bool,
        in viewController: SettingsShakeGestureActionVC)
}

final class SettingsShakeGestureActionVC: UITableViewController, Refreshable {
    private let visibleActions = Settings.ShakeGestureAction.getVisibleValues()

    weak var delegate: SettingsShakeGestureActionVCDelegate?

    static func make(delegate: SettingsShakeGestureActionVCDelegate? = nil) -> SettingsShakeGestureActionVC {
        let vc = Self(style: .insetGrouped)
        vc.delegate = delegate
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LString.shakeGestureActionTitle
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
        tableView.register(
            SwitchCell.self,
            forCellReuseIdentifier: SwitchCell.reuseIdentifier
        )
    }

    func refresh() {
        tableView.reloadSections([0, 1], with: .automatic)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return visibleActions.count
        default:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SubtitleCell.reuseIdentifier,
                for: indexPath) as! SubtitleCell
            configureActionCell(cell, at: indexPath)
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SwitchCell.reuseIdentifier,
                for: indexPath) as! SwitchCell
            configureConfirmationCell(cell)
            return cell
        default:
            fatalError()
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 1:
            guard ManagedAppConfig.shared.isAppProtectionAllowed else {
                return nil
            }
            return LString.shakeGestureConfirmationFootnote
        default:
            return nil
        }
    }

    private func configureActionCell(_ cell: SubtitleCell, at indexPath: IndexPath) {
        let action = visibleActions[indexPath.row]
        let isCurrent = action == Settings.current.shakeGestureAction
        let isDisabled = action == .lockApp && !Settings.current.isAppLockEnabled

        cell.textLabel?.text = action.shortTitle
        cell.detailTextLabel?.text = isDisabled ? action.disabledSubtitle : nil
        cell.accessoryType = isCurrent ? .checkmark : .none
        cell.setEnabled(!isDisabled)
    }

    private func configureConfirmationCell(_ cell: SwitchCell) {
        cell.textLabel?.text = LString.shakeGestureConfirmationTitle
        let isDisabled = Settings.current.shakeGestureAction == .nothing
        cell.theSwitch.isOn = Settings.current.isConfirmShakeGestureAction && !isDisabled
        cell.setEnabled(!isDisabled)
        cell.onDidToggleSwitch = { [weak self] theSwitch in
            guard let self else { return }
            self.delegate?.didSetShakeGestureConfirmation(theSwitch.isOn, in: self)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let action = visibleActions[indexPath.row]
        delegate?.didSelectShakeGesture(action, in: self)
    }
}

extension LString {
    public static let shakeGestureActionTitle = NSLocalizedString(
        "[Settings/ShakeGestureAction/title]",
        value: "When Shaken",
        comment: "Title for a setting: what the app should do when the user shakes the device")
    public static let shakeGestureConfirmationTitle = NSLocalizedString(
        "[Settings/ShakeGestureAction/Confirm/title]",
        value: "Ask for Confirmation",
        comment: "Title for a setting: whether the app should show an 'Are you sure?' before continuing")
    public static let shakeGestureConfirmationFootnote = NSLocalizedString(
        "[Settings/ShakeGestureAction/Confirm/footnote]",
        value: "If the app is locked, it acts without confirmation.",
        comment: "Description of the 'Ask for Confirmation' setting.")
}
