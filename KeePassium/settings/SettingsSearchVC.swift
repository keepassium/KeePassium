//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class SettingsSearchVC: UITableViewController {
    @IBOutlet weak var startWithSearchSwitch: UISwitch!
    @IBOutlet weak var searchFieldNamesSwitch: UISwitch!
    @IBOutlet weak var searchProtectedValuesSwitch: UISwitch!
    
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
        let settings = Settings.current
        startWithSearchSwitch.isOn = settings.isStartWithSearch
        searchFieldNamesSwitch.isOn = settings.isSearchFieldNames
        searchProtectedValuesSwitch.isOn = settings.isSearchProtectedValues
    }
    
    @IBAction func didToggleStartWithSearch(_ sender: UISwitch) {
        Settings.current.isStartWithSearch = sender.isOn
        refresh()
    }
    
    @IBAction func didToggleSearchFieldNames(_ sender: UISwitch) {
        Settings.current.isSearchFieldNames = sender.isOn
        refresh()
    }
    
    @IBAction func didToggleSearchProtectedValues(_ sender: UISwitch) {
        Settings.current.isSearchProtectedValues = sender.isOn
        refresh()
    }
}

extension SettingsSearchVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}
