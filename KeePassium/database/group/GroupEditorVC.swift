//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol GroupEditorDelegate: class {
    func didPressCancel(in groupEditor: GroupEditorVC)
    func didPressDone(in groupEditor: GroupEditorVC)
    func didPressChangeIcon(at popoverAnchor: PopoverAnchor, in groupEditor: GroupEditorVC)
}

final class GroupEditorVC: UIViewController, Refreshable {
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var nameTextField: ValidatingTextField!
    
    weak var delegate: GroupEditorDelegate?
    
    weak var group: Group? {
        didSet {
            refresh()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        nameTextField.delegate = self
        nameTextField.validityDelegate = self

        refresh()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameTextField.becomeFirstResponder()
        if nameTextField.text == LString.defaultNewGroupName {
            nameTextField.selectAll(nil)
        }
        refresh()
    }
    
    func refresh() {
        guard isViewLoaded,
              let group = group
        else {
            return
        }
        nameTextField.text = group.name
        imageView.image = UIImage.kpIcon(forGroup: group)
        navigationItem.rightBarButtonItem?.isEnabled = nameTextField.isValid
    }
    

    @IBAction func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }
    
    @IBAction func didPressDone(_ sender: Any) {
        guard nameTextField.isValid else {
            nameTextField.becomeFirstResponder()
            nameTextField.shake()
            return
        }
        nameTextField.resignFirstResponder()
        group?.name = nameTextField.text ?? ""
        delegate?.didPressDone(in: self)
    }
    
    @IBAction func didTapIcon(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            didPressChangeIcon(self)
        }
    }
    
    @IBAction func didPressChangeIcon(_ sender: Any) {
        let popoverAnchor = PopoverAnchor(sourceView: imageView, sourceRect: imageView.bounds)
        delegate?.didPressChangeIcon(at: popoverAnchor, in: self)
    }
}

extension GroupEditorVC: ValidatingTextFieldDelegate {
    
    private func isValid(groupName: String) -> Bool {
        guard let group = group else {
            assertionFailure()
            return false
        }
        let isReserved = group.isNameReserved(name: groupName)
        let isValid = groupName.isNotEmpty && !isReserved
        return isValid
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return isValid(groupName: sender.text ?? "")
    }
    
    func validatingTextField(_ sender: ValidatingTextField, validityDidChange isValid: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = nameTextField.isValid
    }
    
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        group?.name = text
    }
}

extension GroupEditorVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didPressDone(self)
        return true
    }
}
