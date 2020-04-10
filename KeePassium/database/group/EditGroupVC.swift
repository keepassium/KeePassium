//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol EditGroupDelegate: class {
    func groupEditor(groupDidChange: Group)
}

class EditGroupVC: UIViewController, Refreshable {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameTextField: ValidatingTextField!
    
    private weak var delegate: EditGroupDelegate?

    private weak var group: Group! {
        didSet { rememberOriginalState() }
    }

    public enum Mode {
        case create
        case edit
    }
    private var mode: Mode = .edit
    
    
    static func make(
        mode: Mode,
        group: Group,
        popoverSource: UIView?,
        delegate: EditGroupDelegate?
        ) -> UIViewController
    {
        let editGroupVC = EditGroupVC.instantiateFromStoryboard()
        editGroupVC.delegate = delegate
        editGroupVC.mode = mode
        switch mode {
        case .create:
            let newGroup = group.createGroup()
            newGroup.name = LString.defaultNewGroupName
            editGroupVC.group = newGroup
        case .edit:
            editGroupVC.group = group
        }
        
        let navVC = UINavigationController(rootViewController: editGroupVC)
        navVC.modalPresentationStyle = .formSheet
        navVC.presentationController?.delegate = editGroupVC
        if let popover = navVC.popoverPresentationController, let popoverSource = popoverSource {
            popover.sourceView = popoverSource
            popover.sourceRect = popoverSource.bounds
        }
        return navVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DatabaseManager.shared.addObserver(self)
        nameTextField.delegate = self
        nameTextField.validityDelegate = self
        switch mode {
        case .create:
            title = LString.titleCreateGroup
        case .edit:
            title = LString.titleEditGroup
        }
        group?.touch(.accessed)
        refresh()
    }
    
    deinit {
        DatabaseManager.shared.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameTextField.becomeFirstResponder()
        if nameTextField.text == LString.defaultNewGroupName {
            nameTextField.selectAll(nil)
        }
    }
    
    func refresh() {
        nameTextField.text = group.name
        let icon = UIImage.kpIcon(forGroup: group)
        imageView.image = icon
    }
    
    func dismissPopover(animated: Bool, completion: (() -> Void)?) {
        resignFirstResponder()
        if let navVC = navigationController {
            navVC.dismiss(animated: animated, completion: completion)
        } else {
            dismiss(animated: animated, completion: completion)
        }
    }

    
    private var originalGroup: Group? 
    
    func rememberOriginalState() {
        guard let group = group else { fatalError() }
        originalGroup = group.clone(makeNewUUID: false)
    }
    
    func restoreOriginalState() {
        if let group = group, let originalGroup = originalGroup {
            originalGroup.apply(to: group, makeNewUUID: false)
        }
    }
    

    @IBAction func didPressCancel(_ sender: Any) {
        switch mode {
        case .create:
            group.parent?.remove(group: group)
        case .edit:
            restoreOriginalState()
        }
        dismissPopover(animated: true, completion: nil)
    }
    
    @IBAction func didPressDone(_ sender: Any) {
        resignFirstResponder()
        applyChangesAndSaveDatabase()
    }
    
    @IBAction func didTapIcon(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            didPressChangeIcon(gestureRecognizer)
        }
    }
    
    @IBAction func didPressChangeIcon(_ sender: Any) {
        let chooseIconVC = ChooseIconVC.make(selectedIconID: group.iconID, delegate: self)
        navigationController?.pushViewController(chooseIconVC, animated: true)
    }
    

    private func applyChangesAndSaveDatabase() {
        guard nameTextField.isValid else {
            nameTextField.becomeFirstResponder()
            nameTextField.shake()
            return
        }
        group.name = nameTextField.text ?? ""
        group.touch(.modified, updateParents: false)
        DatabaseManager.shared.startSavingDatabase()
    }
    
    private var savingOverlay: ProgressOverlay?
    
    fileprivate func showSavingOverlay() {
        savingOverlay = ProgressOverlay.addTo(
            view,
            title: LString.databaseStatusSaving,
            animated: true)
        if #available(iOS 13, *) {
            isModalInPresentation = true 
        }
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    fileprivate func hideSavingOverlay() {
        guard savingOverlay != nil else { return }
        navigationController?.setNavigationBarHidden(false, animated: true)
        savingOverlay?.dismiss(animated: true) {
            [weak self] (finished) in
            guard let _self = self else { return }
            _self.savingOverlay?.removeFromSuperview()
            _self.savingOverlay = nil
        }
    }
}

extension EditGroupVC: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        showSavingOverlay()
    }

    func databaseManager(progressDidChange progress: ProgressEx) {
        savingOverlay?.update(with: progress)
    }

    func databaseManager(didSaveDatabase urlRef: URLReference) {
        hideSavingOverlay()
        self.dismissPopover(animated: true, completion: nil)
        if let group = group {
            delegate?.groupEditor(groupDidChange: group)
            GroupChangeNotifications.post(groupDidChange: group)
        }
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        hideSavingOverlay()
    }

    func databaseManager(
        database urlRef: URLReference,
        savingError message: String,
        reason: String?)
    {
        hideSavingOverlay()

        let errorAlert = UIAlertController(title: message, message: reason, preferredStyle: .alert)
        let showDetailsAction = UIAlertAction(title: LString.actionShowDetails, style: .default)
        {
            [unowned self] _ in
            self.present(ViewDiagnosticsVC.make(), animated: true, completion: nil)
        }
        let cancelAction = UIAlertAction(
            title: LString.actionDismiss,
            style: .cancel,
            handler: nil)
        errorAlert.addAction(showDetailsAction)
        errorAlert.addAction(cancelAction)
        present(errorAlert, animated: true, completion: nil)
    }
}

extension EditGroupVC: IconChooserDelegate {
    func iconChooser(didChooseIcon iconID: IconID?) {
        if let iconID = iconID {
            group.iconID = iconID
            imageView.image = UIImage.kpIcon(forGroup: group)
        }
    }
}

extension EditGroupVC: ValidatingTextFieldDelegate {
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        let newName = sender.text ?? ""
        let isReserved = group.isNameReserved(name: newName)
        return newName.isNotEmpty && !isReserved
    }
    
    func validatingTextField(_ sender: ValidatingTextField, validityDidChange isValid: Bool) {
        self.navigationItem.rightBarButtonItem?.isEnabled = isValid
    }
}

extension EditGroupVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didPressDone(self)
        return true
    }
}


extension EditGroupVC: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didPressCancel(presentationController)
    }
}
