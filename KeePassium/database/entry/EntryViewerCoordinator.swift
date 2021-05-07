//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol EntryViewerCoordinatorDelegate: AnyObject {
    
}

final class EntryViewerCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    
    var dismissHandler: CoordinatorDismissHandler?
    private let router: NavigationRouter
    private var entry: Entry
    
    private fieldViewerVC: EntryFieldViewerVC
    
    init(router: NavigationRouter) {
        self.router = router
        
        fieldViewerVC = EntryFieldViewerVC.instantiateFromStoryboard()
        fieldViewerVC.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        <#code#>
    }
    
    public func setEntry(_ entry: Entry) {
        self.entry = entry
        
        refresh()
    }
}
