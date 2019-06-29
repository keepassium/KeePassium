//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class AppStoreReviewHelper {
    static private let appStoreID = 1435127111
    
    static func writeReview() {
        guard let url = URL(string: "itms-apps://apps.apple.com/app/id\(appStoreID)&action=write-review") else {
            assertionFailure("Invalid AppStore URL")
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
