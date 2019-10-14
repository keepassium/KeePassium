//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class AboutVC: UITableViewController {
    @IBOutlet weak var contactSupportCell: UITableViewCell!
    @IBOutlet weak var writeReviewCell: UITableViewCell!
    @IBOutlet weak var versionLabel: UILabel!
    
    let cellTagToURL: [Int: String] = [
        10: "https://github.com/keepassium/KeePassium-L10n",
        20: "https://keepass.info",
        30: "https://feathericons.com",
        40: "http://ionicons.com",
        50: "https://designmodo.com/linecons-free/",
        55: "https://icons8.com/paid-license-99",
        60: "http://subtlepatterns.com",
        70: "http://vicons.superatic.com",
        80: "https://github.com/tadija/AEXML",
        90: "",
        100: "https://github.com/P-H-C/phc-winner-argon2",
        110: "https://cr.yp.to/salsa20.html",
        120: "http://www.cartotype.com/downloads/twofish/twofish.cpp",
        130: "https://github.com/1024jp/GzipSwift",
        140: "https://github.com/norio-nomura/Base32",
        150: "https://github.com/MengTo/Spring/blob/master/Spring/KeyboardLayoutConstraint.swift",
    ]
    
    static func make() -> UIViewController {
        let vc = AboutVC.instantiateFromStoryboard()
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        
        if Settings.current.isTestEnvironment {
            versionLabel.text = "v\(AppInfo.version).\(AppInfo.build) beta"
        } else {
            versionLabel.text = "v\(AppInfo.version).\(AppInfo.build)"
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0.1
        } else {
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case contactSupportCell:
            SupportEmailComposer.show(subject: .supportRequest)
        case writeReviewCell:
            AppStoreHelper.writeReview()
        default:
            if let urlString = cellTagToURL[selectedCell.tag], let url = URL(string: urlString) {
                AppGroup.applicationShared?.open(url, options: [:], completionHandler: nil)
            }
        } 
    }
}
