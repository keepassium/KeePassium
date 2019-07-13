//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

protocol LongPressAwareNavigationControllerDelegate: UINavigationControllerDelegate {
    func didLongPressLeftSide(in navigationController: LongPressAwareNavigationController)
}

class LongPressAwareNavigationController: UINavigationController {
    init() {
        super.init(navigationBarClass: nil, toolbarClass: nil)
        let longPressGestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(didLongPressNavigationBar))
        navigationBar.addGestureRecognizer(longPressGestureRecognizer)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
    
    @objc func didLongPressNavigationBar(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard let delegate = self.delegate as? LongPressAwareNavigationControllerDelegate,
            gestureRecognizer.state == .began else { return }
        let touchPoint = gestureRecognizer.location(in: navigationBar)
        
        let leftSideWidth = navigationBar.bounds.width / 4
        let leftSideRect = navigationBar.bounds
            .divided(atDistance: leftSideWidth, from: .minXEdge)
            .slice
        
        if leftSideRect.contains(touchPoint) {
            delegate.didLongPressLeftSide(in: self)
        }
    }
}
