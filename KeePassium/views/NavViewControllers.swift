//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import UIKit

extension UIViewController {
    @objc func popView() {
        if (navigationController?.viewControllers.count ?? 0 <= 1) {
            dismissView()
        } else {
            previousView()
        }
    }
    
    func registerNavKeys() {
        addKeyCommand(UIKeyCommand(action: #selector(popView), input: UIKeyCommand.inputEscape))
        addKeyCommand(UIKeyCommand(action: #selector(dismissView), input: "w", modifierFlags: [.command]))
    }
    
    @objc func dismissView() {
        dismiss(animated: true)
    }
    
    @objc func previousView() {
        navigationController?.popViewController(animated: true)
    }
}

class NavViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        registerNavKeys()
    }
}

class NavTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        registerNavKeys()
    }
}

class NavCollectionViewController: UICollectionViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        registerNavKeys()
    }
}
