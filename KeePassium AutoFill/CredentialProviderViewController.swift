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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        log.trace("viewDidAppear")
        if ProcessInfo.isRunningOnMac {
            autoFillCoordinator.start()
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

    @available(iOS 14, *)
    private func cacheKeyboard() {
        let textField = UITextField()
        self.view.addSubview(textField)
        textField.becomeFirstResponder()
        textField.resignFirstResponder()
        textField.removeFromSuperview()
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        autoFillCoordinator.serviceIdentifiers = serviceIdentifiers
    }

    override func prepareInterfaceToProvideCredential(
        for credentialIdentity: ASPasswordCredentialIdentity
    ) {
        autoFillCoordinator.prepareUI(for: credentialIdentity)
    }

    override func provideCredentialWithoutUserInteraction(
        for credentialIdentity: ASPasswordCredentialIdentity
    ) {
        autoFillCoordinator.provideWithoutUserInteraction(for: credentialIdentity)
    }
}
