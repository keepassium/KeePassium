//
//  SettingsAppearanceVC.swift
//  KeePassium
//
//  Created by Andrei on 29/11/2020.
//  Copyright © 2020 Andrei Popleteev. All rights reserved.
//

import KeePassiumLib

class SettingsAppearanceVC: UITableViewController {
    
    @IBOutlet weak var appIconCell: UITableViewCell!
    @IBOutlet weak var databaseIconsCell: UITableViewCell!
    
    @IBOutlet weak var textScaleLabel: UILabel!
    @IBOutlet weak var entryTextScaleSlider: UISlider!
    @IBOutlet weak var hideProtectedFieldsSwitch: UISwitch!
    
    weak var router: NavigationRouter?
    private var appIconSwitcherCoordinator: AppIconSwitcherCoordinator?
    private var databaseIconSwitcherCoordinator: DatabaseIconSetSwitcherCoordinator?
    
    deinit {
        appIconSwitcherCoordinator = nil
        databaseIconSwitcherCoordinator = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        
        let textScaleRange = Settings.current.textScaleAllowedRange
        entryTextScaleSlider.minimumValue = Float(textScaleRange.lowerBound)
        entryTextScaleSlider.maximumValue = Float(textScaleRange.upperBound)
        
        let textSizeString = NSLocalizedString(
            "[Appearance/TextSize/title]",
            value: "Text Size",
            comment: "Title of a setting option: font size")
        textScaleLabel.text = textSizeString
        entryTextScaleSlider.accessibilityLabel = textSizeString
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }
    
    private func refresh() {
        let settings = Settings.current

        hideProtectedFieldsSwitch.isOn = settings.isHideProtectedFields

        let textScale = settings.textScale
        entryTextScaleSlider.value = Float(textScale)
        tableView.performBatchUpdates(
            { [weak textScaleLabel] in
                textScaleLabel?.font = UIFont.monospaceFont(ofSize: 17 * textScale, forTextStyle: .body)
            },
            completion: nil
        )
        
        databaseIconsCell.imageView?.image = settings.databaseIconSet.getIcon(.key)
    }
    
    
    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath)
    {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        switch cell {
        case appIconCell:
            showAppIconSettings()
        case databaseIconsCell:
            showDatabaseIconSwitcher()
        default:
            break
        }
    }

    @IBAction func didChangeTextScale(_ sender: UISlider) {
        Settings.current.textScale = CGFloat(entryTextScaleSlider.value)
        refresh()
    }
    
    @IBAction func didPressResetTextScale(_ sender: UIButton) {
        Settings.current.textScale = CGFloat(1.0)
        refresh()
    }
    
    @IBAction func didToggleHideProtectedFieldsSwitch(_ sender: UISwitch) {
        Settings.current.isHideProtectedFields = hideProtectedFieldsSwitch.isOn
        refresh()
    }
    
    private func showAppIconSettings() {
        assert(appIconSwitcherCoordinator == nil)
        guard let router = router else { assertionFailure(); return }
        appIconSwitcherCoordinator = AppIconSwitcherCoordinator(router: router)
        appIconSwitcherCoordinator!.dismissHandler = { [weak self] (coordinator) in
            self?.appIconSwitcherCoordinator = nil
        }
        appIconSwitcherCoordinator!.start()
    }
    
    private func showDatabaseIconSwitcher() {
        assert(databaseIconSwitcherCoordinator == nil)
        guard let router = router else { assertionFailure(); return }
        databaseIconSwitcherCoordinator = DatabaseIconSetSwitcherCoordinator(router: router)
        databaseIconSwitcherCoordinator!.dismissHandler = { [weak self] (coordinator) in
            self?.databaseIconSwitcherCoordinator = nil
        }
        databaseIconSwitcherCoordinator!.start()
    }
}
