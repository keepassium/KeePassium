//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class RootSplitVC: UISplitViewController, UISplitViewControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.preferredDisplayMode = .allVisible
        self.delegate = self
    }
    
    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController
        ) -> Bool
    {
        if secondaryViewController is PlaceholderVC {
            return true 
        }
        return false
    }
}

extension RootSplitVC: FileKeeperDelegate {
    func shouldResolveImportConflict(
        target: URL,
        handler: @escaping (FileKeeper.ConflictResolution) -> Void)
    {
        DispatchQueue.main.async { 
            let fileName = target.lastPathComponent
            let choiceAlert = UIAlertController(
                title: fileName,
                message: LString.fileAlreadyExists,
                preferredStyle: .alert)
            let actionOverwrite = UIAlertAction(title: LString.actionOverwrite, style: .destructive) {
                (action) in
                handler(.overwrite)
            }
            let actionRename = UIAlertAction(title: LString.actionRename, style: .default) { (action) in
                handler(.rename)
            }
            let actionAbort = UIAlertAction(title: LString.actionCancel, style: .cancel) { (action) in
                handler(.abort)
            }
            choiceAlert.addAction(actionOverwrite)
            choiceAlert.addAction(actionRename)
            choiceAlert.addAction(actionAbort)
            let topModalVC = self.presentedViewController ?? self
            topModalVC.present(choiceAlert, animated: true)
        }
    }
}
