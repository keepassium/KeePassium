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
    @IBOutlet weak var debugInfoCell: UITableViewCell!
    
    static func make() -> UIViewController {
        let vc = AboutVC.instantiateFromStoryboard()
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case contactSupportCell:
            SupportEmailComposer.show(includeDiagnostics: false, completion: nil)
        case writeReviewCell:
            AppStoreReviewHelper.writeReview()
        case debugInfoCell:
            resetAutoFillCleanExitFlag()
        default:
            break
        } 
    }
    
    private func resetAutoFillCleanExitFlag() {
        Settings.current.isAutoFillFinishedOK = true
        refresh()
    }
    
    private func refresh() {
        debugInfoCell.textLabel?.text = "AutoFill finished OK: \(Settings.current.isAutoFillFinishedOK)"
    }
}
