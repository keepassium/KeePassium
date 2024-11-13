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
        log.trace("I live again /3")
        super.viewDidLoad()
        autoFillCoordinator = AutoFillCoordinator(rootController: self, context: extensionContext)
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
}

extension CredentialProviderViewController {
    override func prepareInterfaceForExtensionConfiguration() {
        log.trace("prepareInterfaceForExtensionConfiguration")
        autoFillCoordinator.startConfigurationUI()
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        log.trace("prepareCredentialList for passwords")
        autoFillCoordinator.startUI(forServices: serviceIdentifiers, mode: .credentials)
    }

    override func prepareCredentialList(
        for serviceIdentifiers: [ASCredentialServiceIdentifier],
        requestParameters: ASPasskeyCredentialRequestParameters
    ) {
        log.trace("prepareCredentialList for passwords+passkeys")
        autoFillCoordinator.startPasskeyUI(requestParameters, forServices: serviceIdentifiers)
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
        log.trace("prepareInterfaceToProvideCredential")
        let identity = credentialRequest.credentialIdentity
        switch credentialRequest.type {
        case .password:
            autoFillCoordinator.startUI(forIdentity: identity, mode: .credentials)
        case .oneTimeCode:
            autoFillCoordinator.startUI(forIdentity: identity, mode: .oneTimeCode)
        case .passkeyAssertion:
            autoFillCoordinator.startUI(forIdentity: identity, mode: .passkey)
        default:
            log.error("Unexpected credential request type: \(credentialRequest.type.debugDescription, privacy: .public)")
            assertionFailure()
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
        }
    }

    override func provideCredentialWithoutUserInteraction(for credentialRequest: ASCredentialRequest) {
        let type = credentialRequest.type.debugDescription
        log.trace("provideCredentialWithoutUserInteraction: \(type, privacy: .public)")
        let identity = credentialRequest.credentialIdentity
        switch credentialRequest.type {
        case .password:
            autoFillCoordinator.provideWithoutUI(forIdentity: identity, mode: .credentials)
        case .oneTimeCode:
            autoFillCoordinator.provideWithoutUI(forIdentity: identity, mode: .oneTimeCode)
        case .passkeyAssertion:
            guard let request = credentialRequest as? ASPasskeyCredentialRequest else {
                log.error("Passkey assertion request has a wrong type, cancelling")
                assertionFailure()
                extensionContext.cancelRequest(withError: ASExtensionError(.failed))
                return
            }
            autoFillCoordinator.providePasskeyWithoutUI(
                forIdentity: identity as! ASPasskeyCredentialIdentity,
                clientDataHash: request.clientDataHash)
        default:
            log.error("Unexpected credential request type: \(credentialRequest.type.debugDescription, privacy: .public)")
            assertionFailure()
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
        }
    }
}
