//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import UniformTypeIdentifiers

class FilePickerCoordinator: BaseCoordinator, FilePickerVC.Delegate {
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

    internal var _fileReferences = [URLReference]()
    private let fileType: FileType
    private var fileKeeperNotifications: FileKeeperNotifications!
    private let fileInfoReloader = FileInfoReloader()

    internal let _dismissButtonStyle: UIBarButtonItem.SystemItem?

    internal let _filePickerVC: FilePickerVC

    internal var _allowedDropUTIs: [UTType] { [UTType.fileURL] }

    init(
        router: NavigationRouter,
        fileType: FileType,
        itemDecorator: FilePickerItemDecorator?,
        toolbarDecorator: FilePickerToolbarDecorator?,
        dismissButtonStyle: UIBarButtonItem.SystemItem?,
        appearance: FilePickerAppearance
    ) {
        self.fileType = fileType
        _filePickerVC = FilePickerVC(
            fileType: fileType,
            toolbarDecorator: toolbarDecorator,
            itemDecorator: itemDecorator,
            appearance: appearance
        )
        self._dismissButtonStyle = dismissButtonStyle
        super.init(router: router)
        _filePickerVC.allowedDropUTIs = _allowedDropUTIs
        _filePickerVC.delegate = self
        fileKeeperNotifications = FileKeeperNotifications(observer: self)
    }

    deinit {
        fileKeeperNotifications.stopObserving()
    }

    override func start() {
        super.start()
        _pushInitialViewController(_filePickerVC, dismissButtonStyle: _dismissButtonStyle, animated: true)
        refresh(animated: false, reloadInfo: true)
        fileKeeperNotifications.startObserving()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidBecomeActive),
            name: UIScene.didActivateNotification,
            object: nil)
    }

    @objc private func sceneDidBecomeActive(_ sender: AnyObject?) {
        refresh(animated: true, reloadInfo: true)
    }

    override func refresh() {
        super.refresh()
        refresh(animated: false, reloadInfo: true)
    }

    func refresh(animated: Bool, reloadInfo: Bool) {
        _fileReferences = FileKeeper.shared.getAllReferences(
            fileType: fileType,
            includeBackup: Settings.current.isBackupFilesVisible)

        let sortOrder = Settings.current.filesSortOrder
        _fileReferences.sort { sortOrder.compare($0, $1) }

        showFileRefs(_fileReferences)
        if reloadInfo {
            fileInfoReloader.getInfo(
                for: _fileReferences,
                update: { [weak self] _ in
                    guard let self else { return }
                    showFileRefs(self._fileReferences)
                },
                completion: { [weak self] in
                    guard let self else { return }
                    _fileReferences.sort { sortOrder.compare($0, $1) }
                    showFileRefs(self._fileReferences)
                }
            )
        }
        _updateAnnouncements()
        _filePickerVC.refresh(animated: animated)
        UIMenu.rebuildMainMenu()
    }

    override func settingsDidChange(key: Settings.Keys) {
        switch key {
        case .recentUserActivityTimestamp:
            return
        case .backupFilesVisible:
            refresh(animated: false, reloadInfo: true)
        case .filesSortOrder:
            fallthrough
        default:
            return
        }
    }

    internal func _updateAnnouncements() {
    }

    internal func _didUpdateFileReferences() {
    }

    private func showFileRefs(_ refs: [URLReference]) {
        _didUpdateFileReferences()
        _filePickerVC.contentUnavailableConfiguration = refs.isEmpty ? _contentUnavailableConfiguration : nil
        _filePickerVC.setFileRefs(refs)
    }

    internal func _startSelecting() {
        _filePickerVC.setEditing(true, animated: true)
    }

    internal func _didPressDoneBulkEditing() {
        _filePickerVC.setEditing(false, animated: true)
    }

    @discardableResult
    func becomeFirstResponder() -> Bool {
        return _filePickerVC.becomeFirstResponder()
    }

    public func setEnabled(_ enabled: Bool) {
        _filePickerVC.setEnabled(enabled)
    }

    public func selectFile(_ fileRef: URLReference?, animated: Bool) {
        _filePickerVC.selectFile(fileRef, animated: animated)
    }

    func needsRefresh(_ viewController: FilePickerVC) {
        refresh(animated: true, reloadInfo: true)
    }

    func shouldAcceptUserSelection(_ fileRef: URLReference, in viewController: FilePickerVC) -> Bool {
        return true
    }

    func didSelectFile(
        _ fileRef: URLReference?,
        cause: ItemActivationCause?,
        in viewController: FilePickerVC
    ) {
        assertionFailure("Pure virtual method, override this")
    }

    func didPressEliminateFiles(_ fileRefs: [URLReference], in viewController: FilePickerVC) {
        _confirmAndBulkDeleteFiles(fileRefs, at: nil)
    }

    func didToggleEditing(_ editing: Bool, in viewController: FilePickerVC) {
        refresh(animated: true, reloadInfo: false)
    }

    func didEliminateFile(_ fileRef: URLReference, in coordinator: FilePickerCoordinator) {
    }

    internal func _confirmAndBulkDeleteFiles(_ fileRefs: [URLReference], at popoverAnchor: PopoverAnchor?) {
        guard fileRefs.count > 0 else { return }

        let confirmation = UIAlertController(
            title: String.localizedStringWithFormat(LString.itemsSelectedCountTemplate, fileRefs.count),
            message: nil,
            preferredStyle: popoverAnchor != nil ? .actionSheet : .alert
        )

        let destructiveTitle = (fileRefs.count > 1) ? LString.actionDeleteAll : LString.actionDelete
        confirmation.addAction(title: destructiveTitle, style: .destructive) { [weak self] _ in
            guard let self else { return }
            eliminateFilesConfirmed(fileRefs, in: _filePickerVC)
        }
        confirmation.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        if let popoverAnchor {
            confirmation.modalPresentationStyle = .popover
            popoverAnchor.apply(to: confirmation.popoverPresentationController)
        }
        _filePickerVC.present(confirmation, animated: true)
    }

    private func eliminateFilesConfirmed(_ fileRefs: [URLReference], in viewController: FilePickerVC) {
        var remaining = fileRefs.count
        for ref in fileRefs {
            FileDestructionHelper.destroyFile(
                ref,
                fileType: fileType,
                withConfirmation: false,
                at: nil,
                parent: viewController,
                completion: { [weak self] isEliminated in
                    guard let self else { return }
                    if isEliminated {
                        didEliminateFile(ref, in: self)
                    }
                    remaining -= 1
                    if remaining == 0 {
                        refresh(animated: true, reloadInfo: false)
                    }
                }
            )
        }
    }

    func didDropItem(_ itemProvider: NSItemProvider, in viewController: FilePickerVC) {
        let matchingUTI = _allowedDropUTIs
            .map { $0.identifier }
            .first { itemProvider.hasItemConformingToTypeIdentifier($0) }

        if let matchingUTI {
            Diag.debug("Received a dropped item [uti: \(matchingUTI)]")
            itemProvider.loadItem(forTypeIdentifier: matchingUTI, options: nil) {
                [weak self] data, error in
                self?.processDroppedFile(
                    url: data as? URL,
                    error: error,
                    isTemporary: false,
                    viewController: viewController
                )
            }
        } else {
            itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) {
                [weak self] url, error in
                self?.processDroppedFile(url: url, error: error, isTemporary: true, viewController: viewController)
            }
        }
    }

    private func processDroppedFile(url: URL?, error: Error?, isTemporary: Bool, viewController: FilePickerVC) {
        if let error {
            Diag.error("Failed to load file [message: \(error.localizedDescription)]")
            return
        }

        guard let url else {
            Diag.error("Dropped URL is nil")
            return
        }

        if isTemporary {
            guard let inboxURL = FileKeeper.shared.copyToInboxSync(from: url) else {
                Diag.error("Failed to copy dropped file to inbox, ignoring it")
                return
            }
            didDropFile(inboxURL, to: viewController)
        } else {
            didDropFile(url, to: viewController)
        }
    }

    func didDropFile(_ fileURL: URL, to viewController: FilePickerVC) {
    }
}

extension FilePickerCoordinator: FileKeeperObserver {
    func fileKeeperDidUpdate() {
        refresh(animated: true, reloadInfo: true)
    }
}
