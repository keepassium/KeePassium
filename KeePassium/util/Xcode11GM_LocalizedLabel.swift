//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.
//
//
//  This is a workaround for https://github.com/keepassium/KeePassium/issues/60
//  (Xcode 11 GM does not apply translation to static UITableViewCell)
//  We apply this class to problematic labels, so they are translated in code.

import UIKit

class Xcode11GM_LocalizedLabel: UILabel {
    
    @IBInspectable
    var l10nKey: String?
    
    @IBInspectable
    var l10nTable: String?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        guard let localizationKey = l10nKey, let localizationTable = l10nTable else { return }
        let translatedText = NSLocalizedString(
            localizationKey,
            tableName: localizationTable,
            bundle: Bundle.main,
            comment: "")
        if translatedText != localizationKey {
            text = translatedText
        }
    }
}
