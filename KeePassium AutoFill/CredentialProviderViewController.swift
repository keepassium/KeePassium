//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import AuthenticationServices

class CredentialProviderViewController: ASCredentialProviderViewController {

    var autoFillCoordinator: AutoFillCoordinator! 
    
    override func viewDidLoad() {
        super.viewDidLoad()
        autoFillCoordinator = AutoFillCoordinator(rootController: self, context: extensionContext)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 14, *) {
            cacheKeyboard()
        }
        autoFillCoordinator?.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        autoFillCoordinator?.cleanup()
        DispatchQueue.main.async {
            exit(0)
        }
    }
    
    override func didReceiveMemoryWarning() {
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
