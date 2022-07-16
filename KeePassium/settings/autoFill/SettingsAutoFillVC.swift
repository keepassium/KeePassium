//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol SettingsAutoFillViewControllerDelegate: AnyObject {
    func didToggleQuickAutoFill(newValue: Bool, in viewController: SettingsAutoFillVC)
}

final class SettingsAutoFillVC: UITableViewController {
    weak var delegate: SettingsAutoFillViewControllerDelegate?
    
    @IBOutlet private weak var setupInstructionsCell: UITableViewCell!
    @IBOutlet private weak var quickAutoFillCell: UITableViewCell!
    @IBOutlet private weak var perfectMatchCell: UITableViewCell!
    @IBOutlet private weak var copyTOTPCell: UITableViewCell!
    
    @IBOutlet private weak var quickTypeLabel: UILabel!
    @IBOutlet private weak var quickTypeSwitch: UISwitch!
    @IBOutlet private weak var copyTOTPLabel: UILabel!
    @IBOutlet private weak var copyTOTPSwitch: UISwitch!
    @IBOutlet private weak var perfectMatchLabel: UILabel!
    @IBOutlet private weak var perfectMatchSwitch: UISwitch!
    @IBOutlet private weak var quickAutoFillPremiumBadge: UIImageView!
    @IBOutlet private weak var quickAutoFillPremiumBadgeWidthConstraint: NSLayoutConstraint!
    
    private var settingsNotifications: SettingsNotifications!
    private var isAutoFillEnabled = false

    
    override func viewDidLoad() {
        super.viewDidLoad()
        quickTypeLabel.text = LString.titleQuickAutoFill
        
        settingsNotifications = SettingsNotifications(observer: self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = LString.titleAutoFillSettings
        copyTOTPLabel.text = LString.titleCopyOTPtoClipboard
        perfectMatchLabel.text = LString.titleAutoFillPerfectMatch
        settingsNotifications.startObserving()
        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        settingsNotifications.stopObserving()
        super.viewWillDisappear(animated)
    }
    
    @objc
    private func appDidBecomeActive(_ notification: Notification) {
        refresh()
    }
    
    func refresh() {
        let settings = Settings.current
        quickTypeSwitch.isOn = settings.isQuickTypeEnabled
        copyTOTPSwitch.isOn = settings.isCopyTOTPOnAutoFill
        perfectMatchSwitch.isOn = settings.autoFillPerfectMatch

        isAutoFillEnabled = QuickTypeAutoFillStorage.isEnabled
        quickAutoFillCell.setEnabled(isAutoFillEnabled)
        perfectMatchCell.setEnabled(isAutoFillEnabled)
        copyTOTPCell.setEnabled(isAutoFillEnabled)
        if isAutoFillEnabled {
            setupInstructionsCell.textLabel?.text = LString.titleAutoFillSetupGuide
        } else {
            setupInstructionsCell.textLabel?.text = LString.actionActivateAutoFill
        }

        let canUseQuickAutoFill = PremiumManager.shared.isAvailable(feature: .canUseQuickTypeAutoFill)
        quickAutoFillPremiumBadge.isHidden = canUseQuickAutoFill
        quickAutoFillPremiumBadgeWidthConstraint.constant = canUseQuickAutoFill ? 0 : 25
        quickTypeSwitch.accessibilityHint = canUseQuickAutoFill ? nil : LString.premiumFeatureGenericTitle

        tableView.reloadData()
    }
    
    func showQuickAutoFillCleared() {
        quickTypeLabel.flashColor(to: .destructiveTint, duration: 0.7)
    }
    
    
    private func didPressSetupInstructions() {
        URLOpener(AppGroup.applicationShared).open(
            url: URL.AppHelp.autoFillSetupGuide,
            completionHandler: { success in
                if !success {
                    Diag.error("Failed to open help article")
                }
            }
        )
    }
    
    @IBAction func didToggleQuickType(_ sender: UISwitch) {
        assert(delegate != nil, "This won't work without a delegate")
        delegate?.didToggleQuickAutoFill(newValue: quickTypeSwitch.isOn, in: self)
        refresh()
    }
    
    @IBAction func didToggleCopyTOTP(_ sender: UISwitch) {
        Settings.current.isCopyTOTPOnAutoFill = copyTOTPSwitch.isOn
        refresh()
    }
    
    @IBAction func didTogglePerfectMatch(_ sender: UISwitch) {
        Settings.current.autoFillPerfectMatch = perfectMatchSwitch.isOn
        refresh()
    }
}

extension SettingsAutoFillVC {
    override func tableView(
        _ tableView: UITableView,
        titleForFooterInSection section: Int
    ) -> String? {
        switch section {
        case 0:
            if isAutoFillEnabled {
                return nil
            } else {
                return LString.howToActivateAutoFillDescription
            }
        case 1:
            return LString.quickAutoFillDescription
        default:
            return super.tableView(tableView, titleForFooterInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cell = tableView.cellForRow(at: indexPath)
        switch cell {
        case setupInstructionsCell:
            didPressSetupInstructions()
        default:
            return
        }
    }
}

extension SettingsAutoFillVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}
