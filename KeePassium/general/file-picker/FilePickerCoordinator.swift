//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

class FilePickerCoordinator: UIResponder, Coordinator, Refreshable, FilePickerVC.Delegate {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    internal var _contentUnavailableConfiguration: UIContentUnavailableConfiguration? { nil }
    internal var noSelectionItem: FilePickerItem.TitleImage? {
        didSet {
            _filePickerVC.setNoSelectionItem(noSelectionItem)
        }
    }
    internal var announcements: [AnnouncementItem] = [] {
        didSet {
            _filePickerVC.setAnnouncements(announcements)
        }
    }
    internal var title: String? {
        get { _filePickerVC.title }
        set { _filePickerVC.title = newValue }
    }

    private let router: NavigationRouter
    private let fileType: FileType
    private var fileKeeperNotifications: FileKeeperNotifications!
    private let fileInfoReloader = FileInfoReloader()

    internal let _filePickerVC: FilePickerVC

    init(
        router: NavigationRouter,
        fileType: FileType,
        itemDecorator: FilePickerItemDecorator?,
        toolbarDecorator: FilePickerToolbarDecorator?,
        appearance: FilePickerAppearance
    ) {
        self.router = router
        self.fileType = fileType
        _filePickerVC = FilePickerVC(
            fileType: fileType,
            toolbarDecorator: toolbarDecorator,
            itemDecorator: itemDecorator,
            appearance: appearance
        )
        super.init()
        _filePickerVC.delegate = self
        fileKeeperNotifications = FileKeeperNotifications(observer: self)
    }

    deinit {
        fileKeeperNotifications.stopObserving()
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(_filePickerVC, animated: false, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        refresh()
        fileKeeperNotifications.startObserving()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
    }

    @objc private func appDidBecomeActive(_ sender: AnyObject?) {
        refresh()
    }

    func dismiss() {
        router.pop(viewController: _filePickerVC, animated: true)
    }

    func refresh() {
        let refs: [URLReference] = FileKeeper.shared.getAllReferences(
            fileType: fileType,
            includeBackup: Settings.current.isBackupFilesVisible)
        setFileRefs(refs)

        fileInfoReloader.getInfo(
            for: refs,
            update: { [weak self] _ in
                self?.setFileRefs(refs)
            },
            completion: { [weak self] in
                self?.setFileRefs(refs)
            }
        )
        _filePickerVC.refreshControls()
    }

    private func setFileRefs(_ refs: [URLReference]) {
        _filePickerVC.contentUnavailableConfiguration = refs.isEmpty ? _contentUnavailableConfiguration : nil
        _filePickerVC.setFileRefs(refs)
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        _filePickerVC.becomeFirstResponder()
    }

    public func setEnabled(_ enabled: Bool) {
        _filePickerVC.setEnabled(enabled)
    }

    public func selectFile(_ fileRef: URLReference?, animated: Bool) {
        _filePickerVC.selectFile(fileRef, animated: animated)
    }

    func needsRefresh(_ viewController: FilePickerVC) {
        refresh()
    }

    func shouldAcceptUserSelection(_ fileRef: URLReference, in viewController: FilePickerVC) -> Bool {
        return true
    }

    func didSelectFile(
        _ fileRef: URLReference?,
        cause: FileActivationCause?,
        in viewController: FilePickerVC
    ) {
        assertionFailure("Pure virtual method, override this")
    }

    func didEliminateFile(_ fileRef: URLReference, in coordinator: FilePickerCoordinator) {
    }
}

extension FilePickerCoordinator: FileKeeperObserver {
    func fileKeeper(didAddFile urlRef: URLReference, fileType: FileType) {
        refresh()
    }
    func fileKeeper(didRemoveFile urlRef: URLReference, fileType: FileType) {
        refresh()
    }
}
