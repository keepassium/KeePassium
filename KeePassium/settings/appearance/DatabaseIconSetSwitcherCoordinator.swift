//  KeePassium Password Manager
//  Copyright © 2018–2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class DatabaseIconSetSwitcherCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    
    private let router: NavigationRouter
    private let picker: DatabaseIconSetPicker
    
    init(router: NavigationRouter) {
        self.router = router
        picker = DatabaseIconSetPicker.instantiateFromStoryboard()
        picker.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        picker.selectedItem = Settings.current.databaseIconSet
        router.push(picker, animated: true, onPop: {
            [weak self] (viewController) in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
}


extension DatabaseIconSetSwitcherCoordinator: DatabaseIconSetPickerDelegate {
    func didSelect(iconSet: DatabaseIconSet, in picker: DatabaseIconSetPicker) {
        Settings.current.databaseIconSet = iconSet
        router.pop(animated: true)
    }
}
