//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol ItemIconPickerCoordinatorDelegate: class {
    func didSelectIcon(standardIcon: IconID, in coordinator: ItemIconPickerCoordinator)
}

class ItemIconPickerCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    
    typealias DismissHandler = (ItemIconPickerCoordinator) -> Void
    var dismissHandler: DismissHandler?
    
    weak var delegate: ItemIconPickerCoordinatorDelegate?
    
    private let router: NavigationRouter
    private let iconPicker: ItemIconPicker
    
    init(router: NavigationRouter) {
        self.router = router
        iconPicker = ItemIconPicker.instantiateFromStoryboard()
        iconPicker.delegate = self
    }
    
    func start() {
        start(selectedIconID: nil)
    }
    
    func start(selectedIconID: IconID?) {
        iconPicker.selectedIconID = selectedIconID
        router.push(iconPicker, animated: true, onPop: { [self] (viewController) in 
            self.dismissHandler?(self)
        })
    }
}

extension ItemIconPickerCoordinator: ItemIconPickerDelegate {
    func didSelectIcon(iconID: IconID?, in viewController: ItemIconPicker) {
        if let selectedIconID = iconID {
            delegate?.didSelectIcon(standardIcon: selectedIconID, in: self)
        }
        router.pop(animated: true)
    }
    
    func didPressCancel(in viewController: ItemIconPicker) {
        router.pop(animated: true)
    }
}
