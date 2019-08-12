//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class _201908_BetaTransitionNews: NewsItem {
    let key = "201908_SpecialPricesExpire"
    
    let isCurrent = true 
    
    var title = "Now on the App Store!".localized(comment: "News title for beta testers: the app is now available on the App Store.")
    
    func show(in viewController: UIViewController) {
        #if AUTOFILL_EXT
        let alert = UIAlertController.make(
            title: self.title,
            message: "Please open the main app for the full announcement.",
            cancelButtonTitle: LString.actionDismiss)
        viewController.present(alert, animated: true, completion: nil)
        #elseif MAIN_APP
        let vc = BetaTransitionVC.instantiateFromStoryboard()
        vc.newsItem = self
        let wrapperVC = UINavigationController(rootViewController: vc)
        wrapperVC.modalPresentationStyle = .formSheet
        viewController.present(wrapperVC, animated: true, completion: nil)
        #endif
    }
}
