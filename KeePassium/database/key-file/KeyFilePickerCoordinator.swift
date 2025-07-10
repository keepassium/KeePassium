//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

protocol KeyFilePickerCoordinatorDelegate: AnyObject {
    func didSelectKeyFile(
        _ fileRef: URLReference?,
        cause: FileActivationCause?,
        in coordinator: KeyFilePickerCoordinator
    )

    func didEliminateKeyFile(_ keyFile: URLReference, in coordinator: KeyFilePickerCoordinator)
}

class KeyFilePickerCoordinator: FilePickerCoordinator {
    enum AddingMode {
        case `import`
        case use
    }

    weak var delegate: KeyFilePickerCoordinatorDelegate?

    internal var _selectedKeyFile: URLReference?
    internal var _addingMode: AddingMode?
    internal var _fileExportHelper: FileExportHelper?

    init(router: NavigationRouter) {
        let itemDecorator = ItemDecorator()
        let toolbarDecorator = ToolbarDecorator()
        super.init(
            router: router,
            fileType: .keyFile,
            itemDecorator: itemDecorator,
            toolbarDecorator: toolbarDecorator,
            appearance: .insetGrouped
        )
        title = LString.titleKeyFiles
        itemDecorator.coordinator = self
        toolbarDecorator.coordinator = self
        noSelectionItem = .init(
            title: LString.titleNoKeyFile,
            subtitle: LString.noKeyFileDescription,
            image: .symbol(.xmark))
    }

    public func selectKeyFile(_ fileRef: URLReference?, animated: Bool) {
        _selectedKeyFile = fileRef
        selectFile(fileRef, animated: animated)
    }

    override var _contentUnavailableConfiguration: UIContentUnavailableConfiguration? {
        return EmptyListConfigurator.makeConfiguration(for: self)
    }

    override func didSelectFile(
        _ fileRef: URLReference?,
        cause: FileActivationCause?,
        in viewController: FilePickerVC
    ) {
        assert(cause != nil, "Unexpected for single-panel mode")
        delegate?.didSelectKeyFile(fileRef, cause: cause, in: self)
        dismiss()
    }

    override func didEliminateFile(_ fileRef: URLReference, in coordinator: FilePickerCoordinator) {
        super.didEliminateFile(fileRef, in: coordinator)
        delegate?.didEliminateKeyFile(fileRef, in: self)
    }
}
