//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol SettingsAutoFillViewControllerDelegate: AnyObject {
    func didToggleQuickAutoFill(newValue: Bool, in viewController: SettingsAutoFillVC)
    func didToggleCopyTOTP(newValue: Bool, in viewController: SettingsAutoFillVC)
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
    private var setupURL = URL.AppHelp.autoFillSetupGuide
    private var hasSetupFailed = false


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

        #if INTUNE
        isAutoFillEnabled = false
        setupInstructionsCell.setEnabled(false)
        #else
        isAutoFillEnabled = QuickTypeAutoFillStorage.isEnabled
        #endif

        setupInstructionsCell.imageView?.preferredSymbolConfiguration = .init(scale: .large)
        setupInstructionsCell.imageView?.image = .symbol(isAutoFillEnabled ? .infoCircle : .gear)
        if isAutoFillEnabled || hasSetupFailed {
            setupInstructionsCell.textLabel?.text = LString.titleAutoFillSetupGuide
            setupInstructionsCell.accessoryType = .none
            setupURL = URL.AppHelp.autoFillSetupGuide
        } else {
            setupInstructionsCell.textLabel?.text = LString.actionActivateAutoFill
            setupInstructionsCell.accessoryType = .detailButton
            setupURL = URL.Prefs.autoFillPreferences
        }

        quickAutoFillCell.setEnabled(isAutoFillEnabled)
        perfectMatchCell.setEnabled(isAutoFillEnabled)
        copyTOTPCell.setEnabled(isAutoFillEnabled)

        let canUseQuickAutoFill = PremiumManager.shared.isAvailable(feature: .canUseQuickTypeAutoFill)
        quickAutoFillPremiumBadge.isHidden = canUseQuickAutoFill
        quickAutoFillPremiumBadgeWidthConstraint.constant = canUseQuickAutoFill ? 0 : 25
        quickTypeSwitch.accessibilityHint = canUseQuickAutoFill ? nil : LString.premiumFeatureGenericTitle

        tableView.reloadData()
    }

    func showQuickAutoFillCleared() {
        quickTypeLabel.flashColor(to: .destructiveTint, duration: 0.7)
    }


    private func didPressOpenSystemSettings() {
        URLOpener(AppGroup.applicationShared).open(
            url: setupURL,
            completionHandler: { [weak self] success in
                guard let self else { return }
                if !success {
                    Diag.error("Failed to open AutoFill setup page")
                    HapticFeedback.play(.error)
                    hasSetupFailed = true
                    refresh()
                    setupInstructionsCell.shake()
                }
            }
        )
    }

    private func didPressMoreInfo() {
        URLOpener(AppGroup.applicationShared).open(
            url: URL.AppHelp.autoFillSetupGuide,
            completionHandler: { success in
                if !success {
                    Diag.error("Failed to open help article")
                }
            }
        )
    }

    @IBAction private func didToggleQuickType(_ sender: UISwitch) {
        assert(delegate != nil, "This won't work without a delegate")
        delegate?.didToggleQuickAutoFill(newValue: quickTypeSwitch.isOn, in: self)
        refresh()
    }

    @IBAction private func didToggleCopyTOTP(_ sender: UISwitch) {
        delegate?.didToggleCopyTOTP(newValue: copyTOTPSwitch.isOn, in: self)
        refresh()
    }

    @IBAction private func didTogglePerfectMatch(_ sender: UISwitch) {
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
            #if INTUNE
            return "⚠️ " + LString.autoFillUnavailableInIntuneDescription
            #else
            if isAutoFillEnabled {
                return nil
            } else {
                return LString.howToActivateAutoFillDescription
            }
            #endif
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
            didPressOpenSystemSettings()
        default:
            return
        }
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        switch cell {
        case setupInstructionsCell:
            didPressMoreInfo()
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
