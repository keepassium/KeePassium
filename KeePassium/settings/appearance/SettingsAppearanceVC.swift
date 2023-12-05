//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol SettingsAppearanceViewControllerDelegate: AnyObject {
    func didPressAppIconSettings(in viewController: SettingsAppearanceVC)
    func didPressDatabaseIconsSettings(in viewController: SettingsAppearanceVC)
    func didPressEntryTextFontSettings(
        at popoverAnchor: PopoverAnchor,
        in viewController: SettingsAppearanceVC)
}

final class SettingsAppearanceVC: UITableViewController, Refreshable {

    @IBOutlet private weak var appIconCell: UITableViewCell!
    @IBOutlet private weak var databaseIconsCell: UITableViewCell!
    @IBOutlet private weak var textFontCell: UITableViewCell!
    @IBOutlet private weak var resetTextParametersButton: UIButton!

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

        textFontCell.textLabel?.text = LString.titleTextFont
        textScaleLabel.text = LString.titleTextSize
        entryTextScaleSlider.accessibilityLabel = LString.titleTextSize
        resetTextParametersButton.setTitle(LString.actionRestoreDefaults, for: .normal)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredContentSizeChanged(_:)),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = LString.titleAppearanceSettings
        refresh()
    }

    func refresh() {
        let settings = Settings.current

        hideProtectedFieldsSwitch.isOn = settings.isHideProtectedFields

        let entryTextFont = getEntryTextFont()
        let textScale = settings.textScale
        entryTextScaleSlider.value = Float(textScale)
        tableView.performBatchUpdates { [weak textScaleLabel] in
            textScaleLabel?.font = entryTextFont.withRelativeSize(textScale)
        }

        let isDefaultFont = (settings.entryTextFontDescriptor == nil)
        let fontName = isDefaultFont ? LString.titleDefaultFont : entryTextFont.familyName
        textFontCell.detailTextLabel?.text = fontName

        let isDefaultSize = abs(settings.textScale - 1.0).isLessThanOrEqualTo(.ulpOfOne)
        resetTextParametersButton.isEnabled = (!isDefaultFont || !isDefaultSize)

        databaseIconsCell.imageView?.image = settings.databaseIconSet.getIcon(.key)
    }

    private func getEntryTextFont() -> UIFont {
        let fontDescriptor = Settings.current.entryTextFontDescriptor
        return UIFont.monospaceFont(descriptor: fontDescriptor, style: .body)
    }

    private func resetTextParameters() {
        let settings = Settings.current
        settings.textScale = CGFloat(1.0)
        settings.entryTextFontDescriptor = nil
    }

    @objc private func preferredContentSizeChanged(_ notification: Notification) {
        refresh()
    }


    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
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
        didSelectRowAt indexPath: IndexPath
    ) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        switch cell {
        case appIconCell:
            delegate?.didPressAppIconSettings(in: self)
        case databaseIconsCell:
            delegate?.didPressDatabaseIconsSettings(in: self)
        case textFontCell:
            tableView.deselectRow(at: indexPath, animated: true)
            let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
            delegate?.didPressEntryTextFontSettings(at: popoverAnchor, in: self)
        default:
            break
        }
    }

    @IBAction private func didChangeTextScale(_ sender: UISlider) {
        Settings.current.textScale = CGFloat(entryTextScaleSlider.value)
    }

    @IBAction private func didPressResetTextScale(_ sender: UIButton) {
        Settings.current.textScale = CGFloat(1.0)
    }

    @IBAction private func didToggleHideProtectedFieldsSwitch(_ sender: UISwitch) {
        Settings.current.isHideProtectedFields = hideProtectedFieldsSwitch.isOn
        showNotificationIfManaged(setting: .hideProtectedFields)
    }

    @IBAction private func didPressResetTextParameters(_ sender: Any) {
        resetTextParameters()
    }
}
