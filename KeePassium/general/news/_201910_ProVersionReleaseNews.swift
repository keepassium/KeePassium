//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

fileprivate let gregoreanCalendar = Calendar(identifier: .gregorian)

fileprivate let validUntil = DateComponents(
    calendar: gregoreanCalendar,
    timeZone: TimeZone.autoupdatingCurrent,
    year: 2019, month: 10, day: 31,
    hour: 23, minute: 59, second: 59).date!

class _201910_ProVersionReleaseNews: NewsItem {
    let key = "201910_ProVersionReleaseNews"
    
    var isCurrent: Bool {
        if BusinessModel.type == .prepaid {
            return false 
        }
        
        let isBeforeEnd = gregoreanCalendar
            .compare(validUntil, to: Date.now, toGranularity: .minute) == .orderedDescending
        return isBeforeEnd
    }
    
    lazy var title = NSLocalizedString(
        "[News/2019/10/ProVersionReleaseNews/title] KeePassium Pro",
        value: "KeePassium Pro",
        comment: "Title of an announcement about the Pro version")
    
    #if MAIN_APP
    private var premiumCoordinator: PremiumCoordinator? 
    #endif
    
    func show(in viewController: UIViewController) {
        #if AUTOFILL_EXT
        let alert = UIAlertController.make(
            title: self.title,
            message: NSLocalizedString(
                "[News/AutoFill/stubText] Please open the main app for the full announcement.",
                value: "Please open the main app for the full announcement.",
                comment: "Message shown when opening an announcement in AutoFill"),
            cancelButtonTitle: LString.actionDismiss)
        viewController.present(alert, animated: true, completion: nil)
        #elseif MAIN_APP
        let premiumCoordinator = PremiumCoordinator(presentingViewController: viewController)
        premiumCoordinator.delegate = self
        premiumCoordinator.start(tryRestoringPurchasesFirst: false, startWithPro: true)
        self.premiumCoordinator = premiumCoordinator 
        isHidden = true 
        #endif
    }
    
}

#if MAIN_APP
extension _201910_ProVersionReleaseNews: PremiumCoordinatorDelegate {
    func didFinish(_ premiumCoordinator: PremiumCoordinator) {
    }
}
#endif
