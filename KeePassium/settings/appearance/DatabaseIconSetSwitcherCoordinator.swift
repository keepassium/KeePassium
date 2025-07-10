//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class DatabaseIconSetSwitcherCoordinator: BaseCoordinator {
    private let picker: DatabaseIconSetPicker

    override init(router: NavigationRouter) {
        picker = DatabaseIconSetPicker.instantiateFromStoryboard()
        super.init(router: router)
        picker.delegate = self
    }

    override func start() {
        super.start()
        picker.selectedItem = Settings.current.databaseIconSet
        _pushInitialViewController(picker, animated: true)
    }
}


extension DatabaseIconSetSwitcherCoordinator: DatabaseIconSetPickerDelegate {
    func didSelect(iconSet: DatabaseIconSet, in picker: DatabaseIconSetPicker) {
        Settings.current.databaseIconSet = iconSet
        _router.pop(animated: true)
    }
}
