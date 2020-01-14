//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit


class DismissablePopover: NSObject, UIPopoverPresentationControllerDelegate {
    private let leftButtonSystemItem: UIBarButtonItem.SystemItem?
    private let rightButtonSystemItem: UIBarButtonItem.SystemItem?
    
    init(
        leftButton: UIBarButtonItem.SystemItem? = nil,
        rightButton: UIBarButtonItem.SystemItem? = .done)
    {
        self.leftButtonSystemItem = leftButton
        self.rightButtonSystemItem = rightButton
    }
    
    func presentationController(
        _ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle
        ) -> UIViewController?
    {
        let dismissableVC = DismissableNavigationController(
            rootViewController: controller.presentedViewController,
            leftButton: leftButtonSystemItem,
            rightButton: rightButtonSystemItem)
        return dismissableVC
    }
    
}
