//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

open class AppCoverVC: UIViewController {

    static public func make() -> UIViewController {
        let vc = AppCoverVC.instantiateFromStoryboard()
        return vc
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ImageAsset.appCoverPattern.asColor()
    }
}
