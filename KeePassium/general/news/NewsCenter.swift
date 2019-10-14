//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol NewsItem: class {
    var key: String { get }
    
    var title: String { get }
 
    var isHidden: Bool { get set }
    
    var isCurrent: Bool { get }
    
    func show(in viewController: UIViewController)
}

extension NewsItem {
    var userDefaultsKey: String { return "com.keepassium.news." + key }

    var isHidden: Bool {
        set {
            UserDefaults.appGroupShared.set(newValue, forKey: userDefaultsKey)
        }
        get {
            return UserDefaults.appGroupShared.bool(forKey: userDefaultsKey)
        }
    }
}

class NewsCenter {
    public static let shared = NewsCenter()
    
    let specialPricesNews = _201908_SpecialPricesExpireNews()
    
    public func getTopItem() -> NewsItem? {
        if Settings.current.isTestEnvironment {
        } else {
        }
        
        if specialPricesNews.isCurrent
            && !specialPricesNews.isHidden
            && PremiumManager.shared.status != .subscribed
        {
            return specialPricesNews
        }
        return nil
    }
}
