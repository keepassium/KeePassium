//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

protocol DatabasePickerCoordinatorDelegate: AnyObject {
    func didPressShowDiagnostics(at popoverAnchor: PopoverAnchor?, in viewController: UIViewController)
    func didPressShowAppSettings(at popoverAnchor: PopoverAnchor?, in viewController: UIViewController)
    func didPressShowRandomGenerator(at popoverAnchor: PopoverAnchor?, in viewController: UIViewController)

    func shouldAcceptUserSelection(
        _ fileRef: URLReference,
        in coordinator: DatabasePickerCoordinator) -> Bool

    func didSelectDatabase(
        _ fileRef: URLReference?,
        cause: FileActivationCause?,
        in coordinator: DatabasePickerCoordinator
    )
}

extension DatabasePickerCoordinatorDelegate {
    func shouldAcceptUserSelection(
        _ fileRef: URLReference,
        in coordinator: DatabasePickerCoordinator
    ) -> Bool {
        return true
    }
    func didPressShowDiagnostics(at popoverAnchor: PopoverAnchor?, in viewController: UIViewController) {
        assertionFailure("Called a method not implemented by delegate")
    }
    func didPressShowAppSettings(at popoverAnchor: PopoverAnchor?, in viewController: UIViewController) {
        assertionFailure("Called a method not implemented by delegate")
    }
    func didPressShowRandomGenerator(at popoverAnchor: PopoverAnchor?, in viewController: UIViewController) {
        assertionFailure("Called a method not implemented by delegate")
    }
}

class DatabasePickerCoordinator: FilePickerCoordinator {
    weak var delegate: DatabasePickerCoordinatorDelegate?
    let mode: DatabasePickerMode

    internal var _selectedDatabase: URLReference?

    init(router: NavigationRouter, mode: DatabasePickerMode) {
        self.mode = mode
        let toolbarDecorator = ToolbarDecorator()
        let itemDecorator = ItemDecorator()
        super.init(
            router: router,
            fileType: .database,
            itemDecorator: itemDecorator,
            toolbarDecorator: toolbarDecorator,
            appearance: .plain
        )
        title = LString.titleDatabases
        itemDecorator.coordinator = self
        toolbarDecorator.coordinator = self
    }

    internal func enumerateDatabases(
        sorted: Bool = false,
        excludeBackup: Bool = false,
        excludeWithErrors: Bool = false,
        excludeNeedingReinstatement: Bool = false
    ) -> [URLReference] {
        var result = FileKeeper.shared.getAllReferences(fileType: .database, includeBackup: !excludeBackup)
        if excludeWithErrors {
            result = result.filter { !$0.hasError }
        }
        if excludeNeedingReinstatement {
            result = result.filter { !$0.needsReinstatement }
        }
        if sorted {
            let sortOrder = Settings.current.filesSortOrder
            result = result.sorted(by: { sortOrder.compare($0, $1) })
        }
        return result
    }

    public func isKnownDatabase(_ databaseRef: URLReference) -> Bool {
        let knownDatabases = enumerateDatabases(
            excludeBackup: false,
            excludeWithErrors: false,
            excludeNeedingReinstatement: false
        )
        return knownDatabases.contains(databaseRef)
    }

    public func canBeOpenedAutomatically(databaseRef: URLReference) -> Bool {
        let validDatabases = enumerateDatabases(
            excludeBackup: !Settings.current.isBackupFilesVisible,
            excludeWithErrors: true,
            excludeNeedingReinstatement: true
        )
        return validDatabases.contains(databaseRef)
    }

    public func getListedDatabaseCount() -> Int {
        let listedDatabases = enumerateDatabases(
            excludeBackup: !Settings.current.isBackupFilesVisible,
            excludeWithErrors: false,
            excludeNeedingReinstatement: false
        )
        return listedDatabases.count
    }

    public func getFirstListedDatabase() -> URLReference? {
        let shownDBs = enumerateDatabases(sorted: true, excludeBackup: !Settings.current.isBackupFilesVisible)
        return shownDBs.first
    }

    private func getAnnouncements() -> [AnnouncementItem] {
        var announcements: [AnnouncementItem] = []
        if mode == .autoFill,
           FileKeeper.shared.areSandboxFilesLikelyMissing()
        {
            let sandboxUnreachableAnnouncement = AnnouncementItem(
                title: nil,
                body: LString.messageLocalFilesMissing,
                actionTitle: LString.callToActionOpenTheMainApp,
                image: .symbol(.questionmarkFolder),
                onDidPressAction: { announcementView in
                    URLOpener(announcementView).open(url: AppGroup.launchMainAppURL)
                }
            )
            announcements.append(sandboxUnreachableAnnouncement)
        }
        return announcements
    }

    override func refresh() {
        announcements = getAnnouncements()
        super.refresh()
    }

    override var _contentUnavailableConfiguration: UIContentUnavailableConfiguration? {
        return EmptyListConfigurator.makeConfiguration(for: self)
    }

    override func shouldAcceptUserSelection(_ fileRef: URLReference, in viewController: FilePickerVC) -> Bool {
        return delegate?.shouldAcceptUserSelection(fileRef, in: self) ?? true
    }

    override func didSelectFile(
        _ fileRef: URLReference?,
        cause: FileActivationCause?,
        in viewController: FilePickerVC
    ) {
        guard let fileRef else {
            Diag.warning("Unexpectedly selected no database, ignoring")
            assertionFailure("DB Picker does not have no-selection option")
            return
        }
        if let cause {
            _paywallDatabaseSelection(fileRef, animated: true, in: viewController) { [weak self] fileRef in
                guard let self else { return }
                selectDatabase(fileRef, animated: true)
                delegate?.didSelectDatabase(fileRef, cause: cause, in: self)
            }
        } else {
            selectDatabase(fileRef, animated: true)
            delegate?.didSelectDatabase(fileRef, cause: nil, in: self)
        }
    }
}
