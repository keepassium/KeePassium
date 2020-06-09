//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class WatchdogAwareTextView: UITextView {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onTextChanged),
            name: UITextView.textDidChangeNotification,
            object: self)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(
            self, name: UITextView.textDidChangeNotification, object: self)
    }
    
    @objc
    func onTextChanged() {
        Watchdog.shared.restart()
    }
}
