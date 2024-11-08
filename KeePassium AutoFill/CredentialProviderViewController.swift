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
        log.trace("I live again /2")
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
}

extension CredentialProviderViewController {
    override func prepareInterfaceForExtensionConfiguration() {
        log.trace("prepareInterfaceForExtensionConfiguration")
        autoFillCoordinator.startConfigurationUI()
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        log.trace("prepareCredentialList")
        autoFillCoordinator.startUI(forServices: serviceIdentifiers, mode: .credentials)
    }

    override func prepareOneTimeCodeCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        log.trace("prepareOneTimeCodeCredentialList")
        autoFillCoordinator.startUI(forServices: serviceIdentifiers, mode: .oneTimeCode)
    }

#if !targetEnvironment(macCatalyst)
    override func prepareInterfaceForUserChoosingTextToInsert() {
        log.trace("prepareInterfaceForUserChoosingTextToInsert")
        autoFillCoordinator.startUI(forServices: [], mode: .text)
    }
#endif

    override func prepareInterfaceToProvideCredential(for credentialRequest: ASCredentialRequest) {
        log.trace("prepareInterfaceToProvideCredential (iOS17+)")
        let identity = CredentialProviderIdentity(credentialRequest.credentialIdentity)
        switch credentialRequest.type {
        case .password:
            autoFillCoordinator.startUI(forIdentity: identity, mode: .credentials)
        case .oneTimeCode:
            autoFillCoordinator.startUI(forIdentity: identity, mode: .oneTimeCode)
        default:
            log.error("Unexpected credential request type: \(credentialRequest.type.rawValue)")
            assertionFailure()
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
        }
    }

    override func provideCredentialWithoutUserInteraction(for credentialRequest: ASCredentialRequest) {
        log.trace("provideCredentialWithoutUserInteraction (iOS17+)")
        let identity = CredentialProviderIdentity(credentialRequest.credentialIdentity)
        switch credentialRequest.type {
        case .password:
            autoFillCoordinator.provideWithoutUI(forIdentity: identity, mode: .credentials)
        case .oneTimeCode:
            autoFillCoordinator.provideWithoutUI(forIdentity: identity, mode: .oneTimeCode)
        default:
            log.error("Unexpected credential request type: \(credentialRequest.type.rawValue)")
            assertionFailure()
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
        }
    }
}
