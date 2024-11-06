//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib

class KeyFileTextField: ProtectedTextField {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        isSecureTextEntry = Settings.current.isKeyFileInputProtected
        isToggleEnabled = !ManagedAppConfig.shared.isManaged(key: .protectKeyFileInput)
    }

    override func resetVisibility(_ sender: Any) {}

    override func toggleVisibility(_ sender: Any) {
        let desiredValue = !isSecureTextEntry
        Settings.current.isKeyFileInputProtected = desiredValue
        let actualValue = Settings.current.isKeyFileInputProtected
        isSecureTextEntry = actualValue
    }
}
