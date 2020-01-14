//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class DismissableNavigationController: UINavigationController {
    typealias DismissHandler = () -> Void
    
    public var dismissHandler: DismissHandler?
    
    init(
        rootViewController: UIViewController,
        leftButton: UIBarButtonItem.SystemItem? = nil,
        rightButton: UIBarButtonItem.SystemItem? = .done)
    {
        super.init(rootViewController: rootViewController)
        
        if let leftButtonSystemItem = leftButton {
            let leftButton = UIBarButtonItem(
                barButtonSystemItem: leftButtonSystemItem,
                target: self,
                action: #selector(didPressButton))
            rootViewController.navigationItem.leftBarButtonItem = leftButton
        }
        if let rightButtonSystemItem = rightButton {
            let rightButton = UIBarButtonItem(
                barButtonSystemItem: rightButtonSystemItem,
                target: self,
                action: #selector(didPressButton))
            rootViewController.navigationItem.rightBarButtonItem = rightButton
        }
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    @objc func didPressButton() {
        self.dismiss(animated: true) { 
            self.dismissHandler?()
        }
    }
}
