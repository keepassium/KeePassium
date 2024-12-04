//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import LocalAuthentication
import UIKit

protocol OnboardingCoordinatorDelegate: AnyObject {
    func didPressCreateDatabase(in coordinator: OnboardingCoordinator)
    func didPressAddExistingDatabase(in coordinator: OnboardingCoordinator)
    func didPressConnectToServer(in coordinator: OnboardingCoordinator)
}

final class OnboardingCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    weak var delegate: OnboardingCoordinatorDelegate?

    private let router: NavigationRouter
    private var onboardingStepsVC: OnboardingPagesVC!
    private var autoFillCheckTimer: Timer?

    private lazy var onboardingSteps: [OnboardingStep] = [
        OnboardingStep(
            id: .intro,
            title: LString.Onboarding.introTitle,
            text: [
                LString.Onboarding.introText1,
                LString.Onboarding.introText2,
            ].joined(separator: "\n"),
            illustration: UIImage.symbol(.onboardingLogo),
            actions: [
                UIAction(title: LString.actionContinue) { [unowned self] _ in
                    self.showNext()
                }
            ]
        ),
        OnboardingStep(
            id: .autoFill,
            title: LString.Onboarding.autoFillTitle,
            text: [
                LString.Onboarding.autoFillText1,
                LString.Onboarding.autoFillText2,
            ].joined(separator: "\n"),
            canSkip: true,
            illustration: UIImage.symbol(.onboardingAutoFill),
            actions: [
                UIAction(title: LString.Onboarding.actionActivateAutoFill) { [unowned self] _ in
                    self.startAutoFillSetup()
                },
            ],
            skipAction: UIAction(title: LString.actionSkip) { [weak self] _ in self?.showNext() }
        ),
        OnboardingStep(
            id: .dataProtection,
            title: LString.Onboarding.securityTitle,
            text: [
                LString.Onboarding.securityText1,
                LString.Onboarding.securityText2,
            ].joined(separator: "\n"),
            illustration: UIImage.symbol(.onboardingDataProtection),
            actions: [
                UIAction(title: LString.actionContinue) { [unowned self] _ in
                    self.showNext()
                }
            ]
        ),
        OnboardingStep(
            id: .appProtection,
            title: LString.Onboarding.appProtectionTitle,
            text: LString.Onboarding.appProtectionText1,
            canSkip: !ManagedAppConfig.shared.isRequireAppPasscodeSet,
            illustration: biometryIllustration,
            actions: [
                UIAction(title: LString.Onboarding.actionActivateAppProtection) { [unowned self] _ in
                    self.startAppProtectionSetup()
                },
            ],
            skipAction: UIAction(title: LString.actionSkip) { [weak self] _ in self?.showNext() }
        ),
        OnboardingStep(
            id: .databaseSetup,
            title: LString.Onboarding.databasesTitle,
            text: [
                LString.Onboarding.databasesText1,
                LString.Onboarding.databasesText2
            ].joined(separator: "\n"),
            illustration: UIImage.symbol(.onboardingVault),
            actions: [
                UIAction(title: LString.Onboarding.createNewDatabaseAction) { [unowned self] _ in
                    self.delegate?.didPressCreateDatabase(in: self)
                },
                UIAction(
                    title: LString.Onboarding.addExistingDatabaseAction,
                    attributes: ManagedAppConfig.shared.areSystemFileProvidersAllowed ? [] : [.hidden]
                ) { [unowned self] _ in
                    self.delegate?.didPressAddExistingDatabase(in: self)
                },
                UIAction(
                    title: LString.Onboarding.connectToServerAction,
                    attributes: ManagedAppConfig.shared.areInAppFileProvidersAllowed ? [] : [.hidden]
                ) { [unowned self] _ in
                    self.delegate?.didPressConnectToServer(in: self)
                }
            ]
        ),
    ]

    private var biometryIllustration: UIImage? {
        switch LAContext.getBiometryType() {
        case .touchID:
            return .symbol(.onboardingTouchID)
        case .faceID:
            return .symbol(.onboardingFaceID)
        case .opticID:
            return .symbol(.onboardingOpticID)
        default:
            return UIImage.symbol(.onboardingPIN)
        }
    }

    init(router: NavigationRouter) {
        self.router = router

        if isAutoFillEnabledInSystem() || BusinessModel.isIntuneEdition  {
            onboardingSteps.removeAll(where: { $0.id == .autoFill })
        }
        if !ManagedAppConfig.shared.isAppProtectionAllowed {
            onboardingSteps.removeAll(where: { $0.id == .appProtection })
        }

        onboardingStepsVC = OnboardingPagesVC(steps: onboardingSteps)
        onboardingStepsVC.onStateUpdate = { [weak self] onboardingStepsVC in
            self?.router.isModalInPresentation = !onboardingStepsVC.canSkipRemainingSteps
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(onboardingStepsVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }

    func dismiss(completion: (() -> Void)? = nil) {
        router.pop(animated: true, completion: completion)
    }

    private func startAppProtectionSetup() {
        let passcodeInputVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeInputVC.delegate = self
        passcodeInputVC.mode = .setup
        passcodeInputVC.modalPresentationStyle = .formSheet
        passcodeInputVC.isCancelAllowed = true
        router.present(passcodeInputVC, animated: true, completion: nil)
    }

    private func showNext() {
        if !onboardingStepsVC.showNext() {
            dismiss()
        }
    }
}

extension OnboardingCoordinator {
    private func startAutoFillSetup() {
        let urlOpener = URLOpener(AppGroup.applicationShared)
        urlOpener.open(url: URL.Prefs.autoFillPreferences) { [weak self, weak urlOpener] success in
            if success {
                self?.startAutoFillCheckTimer()
            } else {
                Diag.error("Failed to open system AutoFill settings, falling back to online guide")
                urlOpener?.open(url: URL.AppHelp.autoFillSetupGuide)
            }
        }
    }

    private func isAutoFillEnabledInSystem() -> Bool {
        return QuickTypeAutoFillStorage.isEnabled
    }

    private func startAutoFillCheckTimer() {
        guard autoFillCheckTimer == nil else { return }
        autoFillCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkIfAutoFillSetupComplete()
        }
    }

    @objc
    private func appDidBecomeActive(_ notification: Notification) {
        checkIfAutoFillSetupComplete()
    }

    private func checkIfAutoFillSetupComplete() {
        guard onboardingStepsVC.currentStep?.id == .autoFill else {
            autoFillCheckTimer?.invalidate()
            autoFillCheckTimer = nil
            return
        }
        if isAutoFillEnabledInSystem() {
            Diag.info("AutoFill successfully enabled in system settings")
            autoFillCheckTimer?.invalidate()
            autoFillCheckTimer = nil
            showNext()
        }
    }
}

extension OnboardingCoordinator: PasscodeInputDelegate {
    func passcodeInputDidCancel(_ sender: PasscodeInputVC) {
        guard sender.mode == .setup else {
            return
        }
        do {
            try Keychain.shared.removeAppPasscode()
        } catch {
            Diag.error(error.localizedDescription)
            sender.showErrorAlert(error, title: LString.titleKeychainError)
            return
        }
        sender.dismiss(animated: true, completion: nil)
    }

    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode passcode: String) {
        sender.dismiss(animated: true) { [weak self] in
            do {
                let keychain = Keychain.shared
                try keychain.setAppPasscode(passcode)
                keychain.prepareBiometricAuth(true)
                Settings.current.isBiometricAppLockEnabled = true
                self?.showNext()
            } catch {
                Diag.error(error.localizedDescription)
                sender.showErrorAlert(error, title: LString.titleKeychainError)
            }
        }
    }
}

extension LString {
    public enum Onboarding {
        public static let introTitle = NSLocalizedString(
            "[Onboarding/Intro/title]",
            value: "Welcome",
            comment: "Title of the introductory onboarding screen."
        )
        public static let introText1 = NSLocalizedString(
            "[Onboarding/Intro/text1]",
            value: "KeePassium keeps your passwords and other sensitive info securely encrypted.",
            comment: "Text in the introductory onboarding screen."
        )
        public static let introText2 = NSLocalizedString(
            "[Onboarding/Intro/text2]",
            value: "There are no ads and no tracking.",
            comment: "Text in the introductory onboarding screen."
        )
        public static let introText3 = NSLocalizedString(
            "[Onboarding/Intro/text3]",
            value: "We don't know anything about you.",
            comment: "Text in the introductory onboarding screen."
        )
        public static let introText4 = NSLocalizedString(
            "[Onboarding/Intro/text4]",
            value: "Your data belongs to you.",
            comment: "Text in the introductory onboarding screen."
        )

        public static let securityTitle = NSLocalizedString(
            "[Onboarding/Security/title]",
            value: "Maximum Security",
            comment: "Title of the Security intro screen"
        )
        public static let securityText1 = NSLocalizedString(
            "[Onboarding/Security/text1]",
            value: "Your info is encrypted in a safe box (database). Safe boxes are stored in a vault (KeePassium).",
            comment: "Text in the Security intro screen"
        )
        public static let securityText2 = NSLocalizedString(
            "[Onboarding/Security/text2]",
            value: "The vault and safe boxes have different keys and only you will know them.",
            comment: "Text in the Security intro screen"
        )

        public static let appProtectionTitle = NSLocalizedString(
            "[Onboarding/AppProtection/title]",
            value: "For Your Eyes Only",
            comment: "Title of the App Protection onboarding screen"
        )
        public static let appProtectionText1 = NSLocalizedString(
            "[Onboarding/AppProtection/text1]",
            value: "KeePassium is your vault. App protection ensures that only you can open it.",
            comment: "Text in the App Protection onboarding screen."
        )
        public static let actionActivateAppProtection = NSLocalizedString(
            "[Onboarding/AppProtection/activate]",
            value: "Activate App Protection",
            comment: "Action/button to set up the App Protection feature. Not a call to action."
        )

        public static let autoFillTitle = NSLocalizedString(
            "[Onboarding/AutoFill/title]",
            value: "Password AutoFill",
            comment: "Title of the Password AutoFill onboarding screen"
        )
        public static let autoFillText1 = NSLocalizedString(
            "[Onboarding/AutoFill/text1]",
            value: "With AutoFill you can breeze through sign-in pages with a single button press.",
            comment: "Text in the Password AutoFill onboarding screen."
        )
        public static let autoFillText2 = NSLocalizedString(
            "[Onboarding/AutoFill/text2]",
            value: "To start, activate Password AutoFill in system settings.",
            comment: "Text in the Password AutoFill onboarding screen."
        )
        public static let actionActivateAutoFill = NSLocalizedString(
            "[Onboarding/AutoFill/activate]",
            value: "Activate AutoFill",
            comment: "Action/button to set up the Password AutoFill feature. Not a call to action."
        )

        public static let databasesTitle = NSLocalizedString(
            "[Onboarding/DataEncryption/title]",
            value: "Data Encryption",
            comment: "Title of the Data Encryption intro screen"
        )
        public static let databasesText1 = NSLocalizedString(
            "[Onboarding/DataEncryption/text1]",
            value: "Your safe box is an encrypted database.",
            comment: "Text in the Data Encryption intro screen"
        )
        public static let databasesText2 = NSLocalizedString(
            "[Onboarding/DataEncryption/text2]",
            value: "You can keep databases in your favorite cloud or locally on device.",
            comment: "Text in the Data Encryption intro screen"
        )

        public static let createNewDatabaseAction = NSLocalizedString(
            "[Onboarding/CreateNewDatabase/action]",
            value: "Create New Database",
            comment: "Action/button"
        )
        public static let addExistingDatabaseAction = NSLocalizedString(
            "[Onboarding/AddExistingDatabase/action]",
            value: "Add Existing Database",
            comment: "Action/button"
        )
        public static let connectToServerAction = LString.actionConnectToServer
    }
}
