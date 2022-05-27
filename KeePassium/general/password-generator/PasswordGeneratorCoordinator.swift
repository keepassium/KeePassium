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

    weak var delegate: PasswordGeneratorCoordinatorDelegate?
    
    public private(set) var generatedPassword = ""
    
    private let router: NavigationRouter
    private let passGenVC: PasswordGeneratorVC
    
    private let passwordGenerator = PasswordGenerator()
    private let passphraseGenerator = PassphraseGenerator()
    
    init(router: NavigationRouter) {
        self.router = router
        passGenVC = PasswordGeneratorVC.instantiateFromStoryboard()
        passGenVC.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        setupDismissButton()
        
        passGenVC.config = Settings.current.passwordGeneratorConfig
        passGenVC.mode = Settings.current.passwordGeneratorConfig.lastMode
        
        router.push(passGenVC, animated: true, onPop: { [weak self] in
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
        passGenVC.navigationItem.leftBarButtonItem = closeButton
    }
    
    private func dismiss() {
        router.pop(viewController: passGenVC, animated: true)
    }
}

extension PasswordGeneratorCoordinator {
    public func generate(
        mode: PasswordGeneratorMode,
        config: PasswordGeneratorParams,
        animated: Bool
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
                passGenVC.showPassphrase(password, animated: animated)
            } else {
                passGenVC.showPassword(password, animated: animated)
            }
        } catch {
            generatedPassword = ""
            passGenVC.showError(error)
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
        generate(mode: mode, config: config, animated: animated)
        if animated {
            HapticFeedback.play(.passwordGenerated)
        }
    }
    
    func didChangeMode(_ mode: PasswordGeneratorMode, in viewController: PasswordGeneratorVC) {
        let config = Settings.current.passwordGeneratorConfig
        config.lastMode = mode
        Settings.current.passwordGeneratorConfig = config
        
        generate(mode: mode, config: config, animated: false)
    }
    
    func didPressDone(in viewController: PasswordGeneratorVC) {
        delegate?.didAcceptPassword(generatedPassword, in: self)
        dismiss()
    }
    
    func didPressCopyToClipboard(in viewController: PasswordGeneratorVC) {
        let clipboardTimeout = TimeInterval(Settings.current.clipboardTimeout.seconds)
        Clipboard.general.insert(text: generatedPassword, timeout: clipboardTimeout)
        HapticFeedback.play(.copiedToClipboard)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: LString.titleCopiedToClipboard)
        } else {
            viewController.showNotification(
                LString.titleCopiedToClipboard,
                image: UIImage.get(.docOnDoc)?
                    .applyingSymbolConfiguration(.init(weight: .light))?
                    .withTintColor(.green, renderingMode: .alwaysTemplate),
                duration: 1)
        }
    }
    
    func didPressWordlistInfo(wordlist: PassphraseWordlist, in viewController: PasswordGeneratorVC) {
        let urlOpener = URLOpener(viewController)
        urlOpener.open(url: wordlist.sourceURL)
    }
}
