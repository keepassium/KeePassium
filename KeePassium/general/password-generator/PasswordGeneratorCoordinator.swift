//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol PasswordGeneratorCoordinatorDelegate: AnyObject {
    func didAcceptPassword(_ password: String, in coordinator: PasswordGeneratorCoordinator)
}

final class PasswordGeneratorCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    
    weak var context: AnyObject?
    weak var delegate: PasswordGeneratorCoordinatorDelegate?
    
    public private(set) var generatedPassword = ""
    
    private let router: NavigationRouter
    private let firstVC: UIViewController
    private var passGenVC: PasswordGeneratorVC?
    private var quickSheetVC: PasswordGeneratorQuickSheetVC?
    
    private let passwordGenerator = PasswordGenerator()
    private let passphraseGenerator = PassphraseGenerator()
    
    init(router: NavigationRouter, quickMode: Bool) {
        self.router = router
        if quickMode {
            let quickModeVC = PasswordGeneratorQuickSheetVC()
            self.quickSheetVC = quickModeVC
            firstVC = quickModeVC
        } else {
            let fullModeVC = PasswordGeneratorVC.instantiateFromStoryboard()
            self.passGenVC = fullModeVC
            firstVC = fullModeVC
            prepareFullModeGenerator(fullModeVC)
        }
        quickSheetVC?.delegate = self
        passGenVC?.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        setupDismissButton()
        router.push(firstVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
    
    private func setupDismissButton() {
        guard router.navigationController.topViewController == nil else {
            return
        }
        
        let closeButton = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction() { [weak self] _ in
                self?.dismiss()
            },
            menu: nil)
        firstVC.navigationItem.leftBarButtonItem = closeButton
    }
    
    private func prepareFullModeGenerator(_ passGenVC: PasswordGeneratorVC) {
        passGenVC.config = Settings.current.passwordGeneratorConfig
        passGenVC.mode = Settings.current.passwordGeneratorConfig.lastMode
    }
    
    private func dismiss() {
        router.pop(viewController: firstVC, animated: true)
    }
}

extension PasswordGeneratorCoordinator {
    public func generate(
        mode: PasswordGeneratorMode,
        config: PasswordGeneratorParams,
        animated: Bool,
        viewController: PasswordGeneratorVC
    ) {
        let requirements: PasswordGeneratorRequirements
        let generator: PasswordGenerator
        let isPassphrase: Bool
        switch mode {
        case .basic:
            requirements = config.basicModeConfig.toRequirements()
            generator = passwordGenerator
            isPassphrase = false
            break
        case .custom:
            requirements = config.customModeConfig.toRequirements()
            generator = passwordGenerator
            isPassphrase = false
            break
        case .passphrase:
            requirements = config.passphraseModeConfig.toRequirements()
            generator = passphraseGenerator
            isPassphrase = true
            break
        }
        
        do {
            let password = try generator.generate(with: requirements) 
            generatedPassword = password
            if isPassphrase {
                viewController.showPassphrase(password, animated: animated)
            } else {
                viewController.showPassword(password, animated: animated)
            }
        } catch {
            generatedPassword = ""
            viewController.showError(error)
        }
    }
    
    private func performCopyToClipboard(in viewController: UIViewController) {
        let clipboardTimeout = TimeInterval(Settings.current.clipboardTimeout.seconds)
        Clipboard.general.insert(text: generatedPassword, timeout: clipboardTimeout)
        HapticFeedback.play(.copiedToClipboard)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(
                notification: .announcement,
                argument: NSAttributedString(
                    string: LString.titleCopiedToClipboard,
                    attributes: [.accessibilitySpeechQueueAnnouncement: true]
                )    
            )
        } else {
            viewController.showNotification(
                LString.titleCopiedToClipboard,
                image: UIImage.get(.docOnDoc)?
                    .applyingSymbolConfiguration(.init(weight: .light))?
                    .withTintColor(.green, renderingMode: .alwaysTemplate),
                duration: 1)
        }
    }
}

extension PasswordGeneratorCoordinator: PasswordGeneratorDelegate {
    func didChangeConfig(_ config: PasswordGeneratorParams, in viewController: PasswordGeneratorVC) {
        Settings.current.passwordGeneratorConfig = config
    }
    
    func shouldGeneratePassword(
        mode: PasswordGeneratorMode,
        config: PasswordGeneratorParams,
        animated: Bool,
        in viewController: PasswordGeneratorVC
    ) {
        generate(mode: mode, config: config, animated: animated, viewController: viewController)
        if animated {
            HapticFeedback.play(.passwordGenerated)
        }
    }
    
    func didChangeMode(_ mode: PasswordGeneratorMode, in viewController: PasswordGeneratorVC) {
        let config = Settings.current.passwordGeneratorConfig
        config.lastMode = mode
        Settings.current.passwordGeneratorConfig = config
        
        generate(mode: mode, config: config, animated: false, viewController: viewController)
    }
    
    func didPressDone(in viewController: PasswordGeneratorVC) {
        delegate?.didAcceptPassword(generatedPassword, in: self)
        dismiss()
    }
    
    func didPressCopyToClipboard(in viewController: PasswordGeneratorVC) {
        performCopyToClipboard(in: viewController)
        dismiss()
    }
    
    func didPressWordlistInfo(wordlist: PassphraseWordlist, in viewController: PasswordGeneratorVC) {
        let urlOpener = URLOpener(viewController)
        urlOpener.open(url: wordlist.sourceURL)
    }
}

extension PasswordGeneratorCoordinator: PasswordGeneratorQuickSheetDelegate {
    func didSelectItem(_ text: String, in viewController: PasswordGeneratorQuickSheetVC) {
        guard let delegate = delegate else {
            didPressCopy(text, in: viewController)
            return
        }
        delegate.didAcceptPassword(text, in: self)
        dismiss()
    }
    
    func shouldGenerateText(
        mode: QuickRandomTextMode,
        in viewController: PasswordGeneratorQuickSheetVC
    ) -> String? {
        let config = Settings.current.passwordGeneratorConfig

        let result: String?
        switch mode {
        case .basic:
            result = try? passwordGenerator.generate(with: config.basicModeConfig.toRequirements())
        case .expert:
            result = try? passwordGenerator.generate(with: config.customModeConfig.toRequirements())
        case .passphrase:
            result = try? passwordGenerator.generate(with: config.passphraseModeConfig.toRequirements())
        }
        return result
    }
    
    func didPressCopy(_ text: String, in viewController: PasswordGeneratorQuickSheetVC) {
        generatedPassword = text
        performCopyToClipboard(in: viewController)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismiss()
        }
    }
    
    func didRequestFullMode(in viewController: PasswordGeneratorQuickSheetVC) {
        assert(passGenVC == nil, "Already in full mode?")
        let fullModeVC = PasswordGeneratorVC.instantiateFromStoryboard()
        fullModeVC.delegate = self
        self.passGenVC = fullModeVC
        prepareFullModeGenerator(fullModeVC)
        router.push(fullModeVC, animated: true, onPop: { [weak self] in
            self?.passGenVC = nil
            self?.quickSheetVC?.refresh()
        })
    }
}
