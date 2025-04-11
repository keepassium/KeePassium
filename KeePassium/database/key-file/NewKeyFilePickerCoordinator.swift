//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

protocol NewKeyFilePickerCoordinatorDelegate: AnyObject {
    func didPickKeyFile(_ keyFile: URLReference?, in coordinator: NewKeyFilePickerCoordinator)
    func didEliminateKeyFile(_ keyFile: URLReference, in coordinator: NewKeyFilePickerCoordinator)
}

class NewKeyFilePickerCoordinator: FilePickerCoordinator {
    weak var delegate: NewKeyFilePickerCoordinatorDelegate?

    init(router: NavigationRouter) {
        super.init(router: router, fileType: .keyFile, itemDecorator: nil, toolbarDecorator: nil)
        title = "Key Files"
    }

    override func didSelectFile(
        _ fileRef: URLReference,
        cause: FileActivationCause?,
        in viewController: FilePickerVC
    ) {
        assert(cause != nil, "Unexpected for single-panel mode")
        delegate?.didPickKeyFile(fileRef, in: self)
    }
}
