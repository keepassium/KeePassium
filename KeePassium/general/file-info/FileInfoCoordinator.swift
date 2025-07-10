//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol FileInfoCoordinatorDelegate: AnyObject {
    func didEliminateFile(_ fileRef: URLReference, in coordinator: FileInfoCoordinator)
}

final class FileInfoCoordinator: BaseCoordinator {
    weak var delegate: FileInfoCoordinatorDelegate?

    private let fileRef: URLReference
    private let fileType: FileType
    private let canExport: Bool
    private let fileInfoVC: FileInfoVC

    private var fileInfo: FileInfo?

    init(fileRef: URLReference, fileType: FileType, allowExport: Bool, router: NavigationRouter) {
        self.fileRef = fileRef
        self.fileType = fileType
        self.canExport = allowExport
        fileInfoVC = FileInfoVC.instantiateFromStoryboard()
        super.init(router: router)

        fileInfoVC.delegate = self
        fileInfoVC.fileRef = fileRef
        fileInfoVC.fileType = fileType
        fileInfoVC.canExport = allowExport
    }

    override func start() {
        super.start()
        _pushInitialViewController(fileInfoVC, dismissButtonStyle: .close, animated: true)
        refresh()
    }

    override func refresh() {
        super.refresh()
        fileInfoVC.showBusyIndicator(true, animated: true)
        fileInfoVC.updateFileInfo(fileInfo, error: nil)

        fileRef.refreshInfo { [weak self] result in
            guard let self else { return }
            let fileInfoVC = self.fileInfoVC
            fileInfoVC.showBusyIndicator(false, animated: true)
            switch result {
            case .success(let fileInfo):
                self.fileInfo = fileInfo
                fileInfoVC.canExport = self.canExport
                fileInfoVC.updateFileInfo(fileInfo, error: nil)
            case .failure(let accessError):
                fileInfoVC.canExport = false
                fileInfoVC.updateFileInfo(nil, error: accessError)
            }
        }
        fileInfoVC.refresh()
    }
}

extension FileInfoCoordinator {
    func setFileAttribute(_ attribute: FileInfo.Attribute, to value: Bool) {
        fileRef.resolveAsync(timeout: Timeout(duration: 1.0)) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(var url):
                guard url.setFileAttribute(attribute, to: value) else {
                    Diag.error("Failed to change file attributes.")
                    fileInfoVC.showErrorAlert(LString.errorFailedToChangeFileAttributes)
                    return
                }
                Diag.info("File attribute changed [\(attribute): \(value)]")
            case .failure(let error):
                Diag.error(error.localizedDescription)
                fileInfoVC.showErrorAlert(error)
            }
            refresh()
        }
    }
}

extension FileInfoCoordinator: FileInfoDelegate {
    func didPressExport(at popoverAnchor: PopoverAnchor, in viewController: FileInfoVC) {
        if ProcessInfo.isRunningOnMac {
            FileExportHelper.revealInFinder(fileRef)
        } else {
            FileExportHelper.showFileExportSheet(fileRef, at: popoverAnchor, parent: viewController)
        }
    }

    func didPressEliminate(at popoverAnchor: PopoverAnchor, in viewController: FileInfoVC) {
        FileDestructionHelper.destroyFile(
            fileRef,
            fileType: fileType,
            withConfirmation: true,
            at: popoverAnchor,
            parent: viewController,
            completion: { [weak self] success in
                guard let self else { return }
                if success {
                    delegate?.didEliminateFile(fileRef, in: self)
                    dismiss()
                } else {
                }
            }
        )
    }

    func shouldShowAttribute(_ attribute: FileInfo.Attribute, in viewController: FileInfoVC) -> Bool {
        guard fileRef.location.isInternal || fileRef.fileProvider == .some(.localStorage) else {
            return false
        }
        let isAvailable = fileInfo?.attributes[attribute] != nil
        return isAvailable
    }

    func didChangeAttribute(_ attribute: FileInfo.Attribute, to value: Bool, in viewController: FileInfoVC) {
        setFileAttribute(attribute, to: value)
    }
}
