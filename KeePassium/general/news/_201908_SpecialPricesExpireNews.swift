//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

fileprivate let gregoreanCalendar = Calendar(identifier: .gregorian)

fileprivate let validFrom = DateComponents(
    calendar: gregoreanCalendar,
    timeZone: TimeZone.autoupdatingCurrent,
    year: 2019, month: 8, day: 21,
    hour: 0, minute: 0, second: 0).date!
fileprivate let validUntil = DateComponents(
    calendar: gregoreanCalendar,
    timeZone: TimeZone.autoupdatingCurrent,
    year: 2019, month: 8, day: 31,
    hour: 23, minute: 59, second: 59).date!
fileprivate let formattedDateUntil = DateFormatter
    .localizedString(from: validUntil, dateStyle: .medium, timeStyle: .none)

class _201908_SpecialPricesExpireNews: NewsItem {
    let key = "201908_SpecialPricesExpire"
    
    var isCurrent: Bool {
        let now = Date()
        let isPastStart = gregoreanCalendar
            .compare(validFrom, to: now, toGranularity: .minute) == .orderedAscending
        let isBeforeEnd = gregoreanCalendar
            .compare(validUntil, to: now, toGranularity: .minute) == .orderedDescending
        return isPastStart && isBeforeEnd
    }
    
    lazy var title = String.localizedStringWithFormat(
        NSLocalizedString(
            "[News/2019/08/SpecialPricesExpire/title] Early bird promo ends %@",
            value: "Early bird promo ends %@",
            comment: "Title of an announcement [expiryDateFormatted: String]"),
        formattedDateUntil)
    
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
        premiumCoordinator.start()
        isHidden = true 
        #endif
    }
    
}

#if MAIN_APP
extension _201908_SpecialPricesExpireNews: PremiumCoordinatorDelegate {
    func didFinish(_ premiumCoordinator: PremiumCoordinator) {
    }
}
#endif
