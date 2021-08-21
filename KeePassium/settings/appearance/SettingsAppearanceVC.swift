//
//  SettingsAppearanceVC.swift
//  KeePassium
//
//  Created by Andrei on 29/11/2020.
//  Copyright © 2020 Andrei Popleteev. All rights reserved.
//

import KeePassiumLib

protocol SettingsAppearanceViewControllerDelegate: AnyObject {
    func didPressAppIconSettings(in viewController: SettingsAppearanceVC)
    func didPressDatabaseIconsSettings(in viewController: SettingsAppearanceVC)
}

final class SettingsAppearanceVC: NavTableViewController {
    
    @IBOutlet private weak var appIconCell: UITableViewCell!
    @IBOutlet private weak var databaseIconsCell: UITableViewCell!
    
    @IBOutlet private weak var textScaleLabel: UILabel!
    @IBOutlet private weak var entryTextScaleSlider: UISlider!
    @IBOutlet private weak var hideProtectedFieldsSwitch: UISwitch!
    
    weak var delegate: SettingsAppearanceViewControllerDelegate?
    
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
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath)
    {
        if indexPath.section == 0,
           indexPath.row == 0
        {
            cell.isHidden = !UIApplication.shared.supportsAlternateIcons
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0,
           indexPath.row == 0,
           !UIApplication.shared.supportsAlternateIcons
        {
            return 0 
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
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
            delegate?.didPressAppIconSettings(in: self)
        case databaseIconsCell:
            delegate?.didPressDatabaseIconsSettings(in: self)
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
}
