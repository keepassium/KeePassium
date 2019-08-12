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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case contactSupportCell:
            SupportEmailComposer.show(includeDiagnostics: false, completion: nil)
        case writeReviewCell:
            AppStoreHelper.writeReview()
        default:
            break
        } 
    }
}
