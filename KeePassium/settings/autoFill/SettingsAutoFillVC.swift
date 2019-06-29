//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class SettingsAutoFillVC: UITableViewController {

    @IBOutlet weak var copyTOTPSwitch: UISwitch!

    private var settingsNotifications: SettingsNotifications!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsNotifications = SettingsNotifications(observer: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingsNotifications.startObserving()
        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        settingsNotifications.stopObserving()
        super.viewWillDisappear(animated)
    }
    
    func refresh() {
        copyTOTPSwitch.isOn = Settings.current.isCopyTOTPOnAutoFill
    }
    
    
    @IBAction func didToggleCopyTOTP(_ sender: UISwitch) {
        Settings.current.isCopyTOTPOnAutoFill = copyTOTPSwitch.isOn
        refresh()
    }
}

extension SettingsAutoFillVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}
