//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

struct PopoverAnchor {
    enum Kind {
        case barButton
        case viewRect
    }
    public let kind: Kind
    public let barButtonItem: UIBarButtonItem?
    public let sourceView: UIView?
    public let sourceRect: CGRect?
    
    init(barButtonItem: UIBarButtonItem) {
        self.kind = .barButton
        self.barButtonItem = barButtonItem
        self.sourceView = nil
        self.sourceRect = nil
    }
    
    init(sourceView: UIView, sourceRect: CGRect) {
        self.kind = .viewRect
        self.barButtonItem = nil
        self.sourceView = sourceView
        self.sourceRect = sourceRect
    }
    
    public func apply(to popover: UIPopoverPresentationController) {
        switch kind {
        case .barButton:
            assert(barButtonItem != nil)
            popover.barButtonItem = barButtonItem
        case .viewRect:
            assert(sourceView != nil && sourceRect != nil)
            popover.sourceView = sourceView
            popover.sourceRect = sourceRect!
        }
    }
}
