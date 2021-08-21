//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol AboutDelegate: AnyObject {
    func didPressContactSupport(at popoverAnchor: PopoverAnchor, in viewController: AboutVC)
    func didPressWriteReview(at popoverAnchor: PopoverAnchor, in viewController: AboutVC)
    func didPressOpenLicense(url: URL, at popoverAnchor: PopoverAnchor, in viewController: AboutVC)
}

final class AboutVC: NavTableViewController {
    @IBOutlet private weak var appTitleLabel: UILabel!
    @IBOutlet private weak var contactSupportCell: UITableViewCell!
    @IBOutlet private weak var writeReviewCell: UITableViewCell!
    @IBOutlet private weak var versionLabel: UILabel!
    @IBOutlet private weak var resetTextScaleCell: UITableViewCell!
    
    weak var delegate: AboutDelegate?
    
    let cellTagToURL: [Int: String] = [
        10: "https://github.com/keepassium/KeePassium-L10n",
        20: "https://keepass.info",
        30: "https://feathericons.com",
        40: "http://ionicons.com",
        50: "https://designmodo.com/linecons-free/",
        53: "https://icons8.com/paid-license-99",
        55: "https://en.wikipedia.org/wiki/Nuvola",
        57: "https://github.com/keepassxreboot/keepassxc/pull/4699",
        60: "http://subtlepatterns.com",
        70: "http://vicons.superatic.com",
        80: "https://github.com/tadija/AEXML",
        90: "",
        100: "https://github.com/P-H-C/phc-winner-argon2",
        110: "https://cr.yp.to/salsa20.html",
        120: "http://www.cartotype.com/downloads/twofish/twofish.cpp",
        122: "https://github.com/Yubico/yubikit-ios",
        125: "https://github.com/tikhop/TPInAppReceipt",
        130: "https://github.com/1024jp/GzipSwift",
        140: "https://github.com/norio-nomura/Base32",
        150: "https://github.com/MengTo/Spring/blob/master/Spring/KeyboardLayoutConstraint.swift",
        160: "https://github.com/scalessec/Toast-Swift",
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        
        var versionParts = ["v\(AppInfo.version).\(AppInfo.build)"]
        if Settings.current.isTestEnvironment {
            versionParts.append("beta")
        } else {
            if BusinessModel.type == .prepaid {
                versionParts.append("Pro")
            }
        }
        versionLabel.text = versionParts.joined(separator: " ")
        
        contactSupportCell.detailTextLabel?.text = SupportEmailComposer.getSupportEmail()
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
        
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        switch selectedCell {
        case contactSupportCell:
            delegate?.didPressContactSupport(at: popoverAnchor, in: self)
        case writeReviewCell:
            delegate?.didPressWriteReview(at: popoverAnchor, in: self)
        case resetTextScaleCell:
            Settings.current.textScale = 1.0
            Diag.info("Text scale reset to 1.0")
            resetTextScaleCell.detailTextLabel?.text = "Done!" 
            tableView.beginUpdates()
            tableView.endUpdates()
        default:
            if let urlString = cellTagToURL[selectedCell.tag], let url = URL(string: urlString) {
                delegate?.didPressOpenLicense(url: url, at: popoverAnchor, in: self)
            }
        } 
    }
}
