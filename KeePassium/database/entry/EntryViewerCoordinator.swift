//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol EntryViewerCoordinatorDelegate: AnyObject {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryViewerCoordinator)
}

final class EntryViewerCoordinator: Coordinator, Refreshable {
    var childCoordinators = [Coordinator]()

    weak var delegate: EntryViewerCoordinatorDelegate?
    
    var dismissHandler: CoordinatorDismissHandler?
    private let router: NavigationRouter
    
    private let database: Database
    private let entry: Entry
    
    private let fieldViewerVC: EntryFieldViewerVC
    
    init(entry: Entry, database: Database, router: NavigationRouter) {
        self.entry = entry
        self.database = database
        self.router = router
        
        fieldViewerVC = EntryFieldViewerVC.instantiateFromStoryboard()
        fieldViewerVC.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        entry.touch(.accessed)
        router.push(fieldViewerVC, animated: true, onPop: {
            [weak self] viewController in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        refresh()
    }
       
    func refresh() {
        let category = ItemCategory.get(for: entry)
        let fields = ViewableEntryFieldFactory.makeAll(
            from: entry,
            in: database,
            excluding: [.title, .emptyValues]
        )
        fieldViewerVC.setFields(fields, category: category)
    }
}

extension EntryViewerCoordinator {
    private func showEntryFieldEditor() {
        guard let parent = entry.parent else {
            Diag.warning("Entry's parent group is undefined")
            assertionFailure()
            return
        }

        let modalRouter = NavigationRouter.createModal(style: .formSheet, at: nil)
        let entryFieldEditorCoordinator = EntryFieldEditorCoordinator(
            router: modalRouter,
            database: database,
            parent: parent,
            target: entry
        )
        entryFieldEditorCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        entryFieldEditorCoordinator.delegate = self
        entryFieldEditorCoordinator.start()
        modalRouter.dismissAttemptDelegate = entryFieldEditorCoordinator
        
        router.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(entryFieldEditorCoordinator)
    }
    
    func showExportDialog(
        for value: String,
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        var items: [Any] = [value]
        if value.isOpenableURL, let url = URL(string: value) {
            items = [url]
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        popoverAnchor.apply(to: activityVC.popoverPresentationController)
        viewController.present(activityVC, animated: true)
    }
}

extension EntryViewerCoordinator: EntryFieldViewerDelegate {
    func canEditEntry(in viewController: EntryFieldViewerVC) -> Bool {
        return !entry.isDeleted
    }
    
    func didPressEdit(
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldViewerVC
    ) {
        showEntryFieldEditor()
    }
    
    func didPressCopyField(
        text: String,
        from viewableField: ViewableField,
        in viewController: EntryFieldViewerVC
    ) {
        entry.touch(.accessed)
        Clipboard.general.insert(text)
    }
    
    func didPressExportField(
        text: String,
        from viewableField: ViewableField,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldViewerVC
    ) {
        showExportDialog(for: text, at: popoverAnchor, in: viewController)
    }
}

extension EntryViewerCoordinator: EntryFieldEditorCoordinatorDelegate {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryFieldEditorCoordinator) {
        fieldViewerVC.refresh()
        delegate?.didUpdateEntry(entry, in: self)
    }
}
