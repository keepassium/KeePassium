//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import UIKit

struct OnboardingStep {
    enum Identifier {
        case intro
        case dataProtection
        case appProtection
        case autoFill
        case databaseSetup
    }
    let id: Identifier
    let title: String?
    let text: String?
    let canSkip: Bool
    let illustration: UIImage?
    let actions: [UIAction]
    let skipAction: UIAction?

    init(
        id: Identifier,
        title: String? = nil,
        text: String? = nil,
        canSkip: Bool = true,
        illustration: UIImage?,
        actions: [UIAction],
        skipAction: UIAction? = nil
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.canSkip = canSkip
        self.illustration = illustration
        self.actions = actions
        self.skipAction = skipAction
    }
}
