//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import AuthenticationServices
import OSLog

class CredentialProviderViewController: ASCredentialProviderViewController {
    let log = Logger(subsystem: "com.keepassium.autofill", category: "CredentialProviderVC")

    var autoFillCoordinator: AutoFillCoordinator! 

    override func viewDidLoad() {
        super.viewDidLoad()
        autoFillCoordinator = AutoFillCoordinator(rootController: self, context: extensionContext)
        autoFillCoordinator.prepare()
    }

    override func viewWillAppear(_ animated: Bool) {
        log.trace("viewWillAppear")
        super.viewWillAppear(animated)
        if !ProcessInfo.isRunningOnMac {
            cacheKeyboard()
            autoFillCoordinator?.start()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        log.trace("viewDidDisappear")
        super.viewDidDisappear(animated)
        autoFillCoordinator?.cleanup()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        autoFillCoordinator?.handleMemoryWarning()
    }

    private func cacheKeyboard() {
        let textField = UITextField()
        self.view.addSubview(textField)
        textField.becomeFirstResponder()
        textField.resignFirstResponder()
        textField.removeFromSuperview()
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        log.trace("prepareCredentialList")
        prepareCredentialList(for: serviceIdentifiers, mode: .credentials)
    }

    override func prepareInterfaceForExtensionConfiguration() {
        log.trace("prepareInterfaceForExtensionConfiguration")
        autoFillCoordinator.prepareConfigurationUI()
        if ProcessInfo.isRunningOnMac {
            autoFillCoordinator.start()
        }
    }

    private func prepareCredentialList(
        for serviceIdentifiers: [ASCredentialServiceIdentifier],
        mode: AutoFillMode
    ) {
        autoFillCoordinator.serviceIdentifiers = serviceIdentifiers
        autoFillCoordinator.autoFillMode = mode
        if ProcessInfo.isRunningOnMac {
            autoFillCoordinator.start()
        }
    }
}

extension CredentialProviderViewController {
    override func prepareOneTimeCodeCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        log.trace("prepareOneTimeCodeCredentialList")
        prepareCredentialList(for: serviceIdentifiers, mode: .oneTimeCode)
    }

#if !targetEnvironment(macCatalyst)
    override func prepareInterfaceForUserChoosingTextToInsert() {
        log.trace("prepareInterfaceForUserChoosingTextToInsert")
        prepareCredentialList(for: [], mode: .text)
    }
#endif

    override func prepareInterfaceToProvideCredential(for credentialRequest: ASCredentialRequest) {
        log.trace("prepareInterfaceToProvideCredential (iOS17+)")
        switch credentialRequest.type {
        case .password:
            autoFillCoordinator.prepareUI(
                autoFillMode: .credentials,
                for: CredentialProviderIdentity(credentialRequest.credentialIdentity)
            )
        case .oneTimeCode:
            if #available(iOS 18.0, *) {
                autoFillCoordinator.prepareUI(
                    autoFillMode: .oneTimeCode,
                    for: CredentialProviderIdentity(credentialRequest.credentialIdentity)
                )
            } else {
                log.error("Request type of oneTimeCode called on older iOS than 18")
                extensionContext.cancelRequest(withError: ASExtensionError(.failed))
            }
        default:
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
        }
    }

    override func provideCredentialWithoutUserInteraction(for credentialRequest: ASCredentialRequest) {
        log.trace("provideCredentialWithoutUserInteraction (iOS17+)")
        switch credentialRequest.type {
        case .password:
            autoFillCoordinator.provideWithoutUserInteraction(
                autoFillMode: .credentials,
                for: CredentialProviderIdentity(
                    credentialRequest.credentialIdentity
                )
            )
        case .oneTimeCode:
            if #available(iOS 18.0, *) {
                autoFillCoordinator.provideWithoutUserInteraction(
                    autoFillMode: .oneTimeCode,
                    for: CredentialProviderIdentity(credentialRequest.credentialIdentity)
                )
            } else {
                log.error("Request type of oneTimeCode called on older iOS than 18")
                extensionContext.cancelRequest(withError: ASExtensionError(.failed))
            }
        default:
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
        }
    }
}
