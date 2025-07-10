//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class AutoFillSettingsCoordinator: BaseCoordinator {
    private let autoFillSettingsVC: AutoFillSettingsVC

    override init(router: NavigationRouter) {
        autoFillSettingsVC = AutoFillSettingsVC()
        super.init(router: router)
        autoFillSettingsVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(autoFillSettingsVC, animated: true)
        applySettingsToVC()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
    }

    @objc
    private func appDidBecomeActive(_ notification: Notification) {
        refresh()
    }

    override func refresh() {
        super.refresh()
        applySettingsToVC()
        autoFillSettingsVC.refresh()
    }

    private func applySettingsToVC() {
        #if INTUNE
        autoFillSettingsVC.setupState = .unavailable
        #else
        if QuickTypeAutoFillStorage.isEnabled {
            autoFillSettingsVC.setupState = .active
        } else {
            if autoFillSettingsVC.setupState != .activationFailed {
                autoFillSettingsVC.setupState = .needsActivation
            }
        }
        #endif
        let settings = Settings.current
        autoFillSettingsVC.isQuickAutoFillEnabled = settings.isQuickTypeEnabled
        autoFillSettingsVC.isFillPerfectResult = settings.autoFillPerfectMatch
        autoFillSettingsVC.isCopyOTPOnFill = settings.isCopyTOTPOnAutoFill
    }
}

extension AutoFillSettingsCoordinator {

    private func openSystemAutoFillSettings() {
        URLOpener(AppGroup.applicationShared).open(
            url: URL.Prefs.autoFillPreferences,
            completionHandler: { [weak self] success in
                guard let self else { return }
                if !success {
                    Diag.error("Failed to open AutoFill setup page")
                    HapticFeedback.play(.error)
                    autoFillSettingsVC.setupState = .activationFailed
                    refresh()
                }
            }
        )
    }

    private func showAutoFillSetupGuide() {
        URLOpener(AppGroup.applicationShared).open(
            url: URL.AppHelp.autoFillSetupGuide,
            completionHandler: { success in
                if !success {
                    Diag.error("Failed to open help article")
                }
            }
        )
    }

    private func maybeSetQuickAutoFill(_ enabled: Bool, presenter: AutoFillSettingsVC) {
        if ManagedAppConfig.shared.isManaged(key: .enableQuickTypeAutoFill) {
            presenter.showManagedSettingNotification()
            setQuickAutoFill(Settings.current.isQuickTypeEnabled, presenter: presenter)
            return
        }

        if enabled {
            performPremiumActionOrOfferUpgrade(
                for: .canUseQuickTypeAutoFill,
                in: presenter,
                actionHandler: { [weak self, weak presenter] in
                    guard let self, let presenter else { return }
                    setQuickAutoFill(true, presenter: presenter)
                }
            )
        } else {
            setQuickAutoFill(false, presenter: presenter)
        }
    }

    private func setQuickAutoFill(_ enabled: Bool, presenter: AutoFillSettingsVC) {
        Settings.current.isQuickTypeEnabled = enabled
        if !Settings.current.isQuickTypeEnabled {
            QuickTypeAutoFillStorage.removeAll()
        }
        refresh()
    }
}

extension AutoFillSettingsCoordinator: AutoFillSettingsVC.Delegate {
    func didPressAutoFillSetup(
        _ state: AutoFillSettingsVC.AutoFillState,
        in viewController: AutoFillSettingsVC
    ) {
        switch state {
        case .needsActivation:
            openSystemAutoFillSettings()
        case .activationFailed, .active:
            showAutoFillSetupGuide()
        case .unavailable:
            assertionFailure("This control should be disabled")
            return
        }
        refresh()
    }

    func didPressAutoFillHelp(in viewController: AutoFillSettingsVC) {
        showAutoFillSetupGuide()
    }

    func didChangeQuickAutoFillEnabled(_ isOn: Bool, in viewController: AutoFillSettingsVC) {
        maybeSetQuickAutoFill(isOn, presenter: viewController)
        refresh()
    }

    func didChangeFillPerfectResult(_ isOn: Bool, in viewController: AutoFillSettingsVC) {
        Settings.current.autoFillPerfectMatch = isOn
        viewController.showNotificationIfManaged(setting: .autoFillPerfectMatch)
        refresh()
    }

    func didChangeCopyOTPOnFill(_ isOn: Bool, in viewController: AutoFillSettingsVC) {
        Settings.current.isCopyTOTPOnAutoFill = isOn
        viewController.showNotificationIfManaged(setting: .copyTOTPOnAutoFill)
        refresh()
    }
}
