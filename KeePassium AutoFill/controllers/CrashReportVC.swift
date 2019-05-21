//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

protocol CrashReportDelegate: class {
    func didPressDismiss(in crashReport: CrashReportVC)
}

class CrashReportVC: UIViewController {

    public weak var delegate: CrashReportDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    @IBAction func didPressDismiss(_ sender: Any) {
        delegate?.didPressDismiss(in: self)
    }
}
