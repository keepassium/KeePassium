//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol GroupEditorCoordinatorDelegate: AnyObject {
    func didUpdateGroup(_ group: Group, in coordinator: GroupEditorCoordinator)

    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL)
}

final class GroupEditorCoordinator: Coordinator {
    private let smartGroupDefaultQuery = "is:entry"
    enum Mode {
        case create(smart: Bool)
        case modify(group: Group)
    }
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: GroupEditorCoordinatorDelegate?

    private let router: NavigationRouter
    private let databaseFile: DatabaseFile
    private let database: Database
    private let parent: Group
    private let originalGroup: Group?
    private let isSmartGroup: Bool
    private let canSupportTags: Bool
    private let supportsNotes: Bool

    private let groupEditorVC: GroupEditorVC

    private var group: Group

    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return router }
    var saveSuccessHandler: (() -> Void)?

    init(router: NavigationRouter, databaseFile: DatabaseFile, parent: Group, mode: Mode) {
        self.router = router
        self.databaseFile = databaseFile
        self.database = databaseFile.database
        self.parent = parent

        let editorTitle: String
        switch mode {
        case .create(let isSmart):
            self.originalGroup = nil
            group = parent.createGroup(detached: true)
            isSmartGroup = isSmart
            if isSmartGroup {
                group.name = LString.defaultNewSmartGroupName
                group.notes = smartGroupDefaultQuery
                editorTitle = LString.titleNewSmartGroup
            } else {
                group.name = LString.defaultNewGroupName
                editorTitle = LString.titleNewGroup
            }
        case .modify(let targetGroup):
            self.originalGroup = targetGroup
            group = targetGroup.clone(makeNewUUID: false)
            isSmartGroup = targetGroup.isSmartGroup
            editorTitle = isSmartGroup ? LString.titleSmartGroup : LString.titleGroup
        }

        group.touch(.accessed)

        canSupportTags = database is Database2
        supportsNotes = database is Database2
        assert(!isSmartGroup || supportsNotes, "Got a smart group without Notes support, this is impossible")
        let extraFields: [GroupEditorVC.ExtraField?] = [
            canSupportTags ? .tags : nil,
            supportsNotes ? .notes : nil
        ]
        let groupProperties = isSmartGroup ? [] : GroupEditorVC.Property.makeAll(for: group, parent: parent)

        groupEditorVC = GroupEditorVC(
            group: group,
            parent: parent,
            extraFields: extraFields.compactMap({ $0 }),
            properties: groupProperties,
            isSmartGroup: isSmartGroup
        )
        groupEditorVC.title = editorTitle
        groupEditorVC.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(groupEditorVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        refresh()
    }

    private func refresh() {
        groupEditorVC.refresh()
    }

    private func abortAndDismiss() {
        router.pop(animated: true)
    }

    private func saveChangesAndDismiss() {
        group.touch(.modified, updateParents: false)
        if let originalGroup = originalGroup {
            group.apply(to: originalGroup, makeNewUUID: false)
            delegate?.didUpdateGroup(originalGroup, in: self)
        } else {
            parent.add(group: group)
            delegate?.didUpdateGroup(group, in: self)
        }

        saveDatabase(databaseFile)
    }

    private func showDiagnostics() {
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: router)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        addChildCoordinator(diagnosticsViewerCoordinator)
        diagnosticsViewerCoordinator.start()
    }

    func showIconPicker() {
        let iconPickerCoordinator = ItemIconPickerCoordinator(
            router: router,
            databaseFile: databaseFile,
            customFaviconUrl: nil
        )
        iconPickerCoordinator.item = group
        iconPickerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        iconPickerCoordinator.delegate = self
        addChildCoordinator(iconPickerCoordinator)
        iconPickerCoordinator.start()
    }

    func showPasswordGenerator(
        for textInput: TextInputView,
        in groupEditor: GroupEditorVC
    ) {
        let passGenCoordinator = PasswordGeneratorCoordinator(router: router, quickMode: true, hasTarget: true)
        passGenCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        passGenCoordinator.delegate = self
        passGenCoordinator.context = textInput
        passGenCoordinator.start()
        addChildCoordinator(passGenCoordinator)
    }
}

extension GroupEditorCoordinator: GroupEditorDelegate {
    func didPressCancel(in groupEditor: GroupEditorVC) {
        abortAndDismiss()
    }

    func didPressDone(in groupEditor: GroupEditorVC) {
        groupEditor.resignFirstResponder()
        if canSupportTags && group.tags.count > 0 {
            requestFormatUpgradeIfNecessary(in: groupEditor, for: database, and: .groupTags) { [weak self] in
                self?.saveChangesAndDismiss()
            }
        } else {
            saveChangesAndDismiss()
        }
    }

    func didPressChangeIcon(at popoverAnchor: PopoverAnchor, in groupEditor: GroupEditorVC) {
        showIconPicker()
    }

    func didPressRandomizer(for textInput: TextInputView, in groupEditor: GroupEditorVC) {
        showPasswordGenerator(for: textInput, in: groupEditor)
    }

    func didPressTags(in groupEditor: GroupEditorVC) {
        let tagsCoordinator = TagSelectorCoordinator(
            item: group,
            parent: originalGroup?.parent,
            databaseFile: databaseFile,
            router: router
        )
        tagsCoordinator.delegate = self
        tagsCoordinator.dismissHandler = { [weak self, tagsCoordinator] coordinator in
            self?.group.tags = tagsCoordinator.selectedTags
            self?.refresh()
            self?.removeChildCoordinator(coordinator)
        }
        tagsCoordinator.start()
        addChildCoordinator(tagsCoordinator)
    }
}

extension GroupEditorCoordinator: PasswordGeneratorCoordinatorDelegate {
    func didAcceptPassword(_ password: String, in coordinator: PasswordGeneratorCoordinator) {
        guard let context = coordinator.context,
              let textInput = context as? TextInputView
        else {
            assertionFailure()
            return
        }
        textInput.replaceText(in: textInput.selectedOrFullTextRange, withText: password)
        refresh()
    }
}

extension GroupEditorCoordinator: TagSelectorCoordinatorDelegate {
    func didUpdateTags(in coordinator: TagSelectorCoordinator) {
        refresh()
        delegate?.didUpdateGroup(group, in: self)
    }
}

extension GroupEditorCoordinator: ItemIconPickerCoordinatorDelegate {
    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: url)
    }

    func didSelectIcon(standardIcon: IconID, in coordinator: ItemIconPickerCoordinator) {
        group.iconID = standardIcon
        if let group2 = group as? Group2 {
            group2.customIconUUID = .ZERO
        }
        refresh()
    }

    func didSelectIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator) {
        guard let group2 = group as? Group2 else { return }
        group2.customIconUUID = customIcon
        refresh()
    }

    func didDeleteIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator) {
        if let group2 = group as? Group2,
           group2.customIconUUID == customIcon
        {
            delegate?.didUpdateGroup(group, in: self)
            refresh()
        }
    }
}

extension GroupEditorCoordinator: DatabaseSaving {
    func didCancelSaving(databaseFile: DatabaseFile) {
    }

    func didSave(databaseFile: DatabaseFile) {
        router.pop(animated: true)
    }

    func getDatabaseSavingErrorParent() -> UIViewController {
        return groupEditorVC
    }

    func getDiagnosticsHandler() -> (() -> Void)? {
        return showDiagnostics
    }

    func didRelocate(databaseFile: DatabaseFile, to newURL: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: newURL)
    }
}
