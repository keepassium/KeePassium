//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol FileInfoCoordinatorDelegate: AnyObject {
    func didEliminateFile(_ fileRef: URLReference, in coordinator: FileInfoCoordinator)
}

final class FileInfoCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    
    weak var delegate: FileInfoCoordinatorDelegate?
    
    private let router: NavigationRouter
    private let fileRef: URLReference
    private let fileType: FileType
    private let canExport: Bool
    private let fileInfoVC: FileInfoVC
    
    private var fileInfo: FileInfo?
    
    init(fileRef: URLReference, fileType: FileType, allowExport: Bool, router: NavigationRouter) {
        self.router = router
        self.fileRef = fileRef
        self.fileType = fileType
        self.canExport = allowExport
        fileInfoVC = FileInfoVC.instantiateFromStoryboard()
        fileInfoVC.delegate = self
        fileInfoVC.fileRef = fileRef
        fileInfoVC.fileType = fileType
        fileInfoVC.canExport = false 
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        setupCloseButton()
        router.push(fileInfoVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        refresh()
    }
    
    func dismiss() {
        router.pop(viewController: fileInfoVC, animated: true)
    }
    
    private func setupCloseButton() {
        guard router.navigationController.topViewController == nil else {
            return
        }
        
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(didPressDismiss))
        fileInfoVC.navigationItem.leftBarButtonItem = closeButton
    }
    
    @objc
    private func didPressDismiss(_ sender: Any) {
        dismiss()
    }
    
    func refresh() {
        fileInfoVC.showBusyIndicator(true, animated: false)
        fileInfoVC.updateFileInfo(fileInfo, error: nil) 
        
        fileRef.refreshInfo { [weak self] result in
            guard let self = self else { return }
            let fileInfoVC = self.fileInfoVC
            fileInfoVC.showBusyIndicator(false, animated: false)
            switch result {
            case .success(let fileInfo):
                self.fileInfo = fileInfo
                fileInfoVC.canExport = self.canExport
                fileInfoVC.isExcludedFromBackup = fileInfo.isExcludedFromBackup
                fileInfoVC.updateFileInfo(fileInfo, error: nil)
            case .failure(let accessError):
                fileInfoVC.canExport = false
                fileInfoVC.isExcludedFromBackup = nil
                fileInfoVC.updateFileInfo(nil, error: accessError)
            }
        }
        fileInfoVC.refresh()
    }
}

extension FileInfoCoordinator {
    private func setExcludedFromBackup(_ isExcluded: Bool) {
        fileRef.resolveAsync(timeout: 1.0) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(var url):
                if url.setExcludedFromBackup(isExcluded) {
                    Diag.info("File is \(isExcluded ? "" : "not ")excluded from iTunes/iCloud backup")
                } else {
                    Diag.error("Failed to change file attributes.")
                    self.fileInfoVC.showErrorAlert(LString.errorFailedToChangeFileAttributes)
                }
            case .failure(let error):
                Diag.error(error.localizedDescription)
                self.fileInfoVC.showErrorAlert(error)
            }
            self.refresh()
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
                if success {
                    self?.dismiss()
                } else {
                }
            }
        )
    }
    
    func canExcludeFromBackup(in viewController: FileInfoVC) -> Bool {
        let isLocalFile = fileRef.location.isInternal ||
                fileRef.fileProvider == .some(.localStorage)
        let isExclusionAttributeDefined = (fileInfo?.isExcludedFromBackup != nil)
        return isLocalFile && isExclusionAttributeDefined
    }
    
    func didChangeExcludeFromBackup(shouldExclude: Bool, in viewController: FileInfoVC) {
        setExcludedFromBackup(shouldExclude)
    }
}
