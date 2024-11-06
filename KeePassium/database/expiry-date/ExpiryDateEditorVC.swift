//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol ExpiryDateEditorDelegate: AnyObject {
    func didPressCancel(in viewController: ExpiryDateEditorVC)
    func didChangeExpiryDate(
        _ expiryDate: Date,
        canExpire: Bool,
        in viewController: ExpiryDateEditorVC)
}

final class ExpiryDateEditorVC: UIViewController, Refreshable {

    @IBOutlet weak var neverExpiresSwitch: UISwitch!
    @IBOutlet weak var expiresLabel: UILabel!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var presetButton: UIButton!
    @IBOutlet weak var doneButton: UIBarButtonItem!

    weak var delegate: ExpiryDateEditorDelegate?
    var canExpire = false
    var expiryDate = Date.now
    var isModified: Bool {
        return canExpire != !neverExpiresSwitch.isOn || datePicker.date != expiryDate
    }

    private lazy var relativeTimeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.formattingContext = .beginningOfSentence
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter
    }()

    private lazy var presetTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowsFractionalUnits = false
        formatter.includesApproximationPhrase = false
        formatter.includesTimeRemainingPhrase = false
        formatter.unitsStyle = .full
        formatter.collapsesLargestUnit = false
        formatter.maximumUnitCount = 1
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = LString.itemExpiryDate
        expiresLabel.text = LString.expiryDateNever
        datePicker.preferredDatePickerStyle = .inline

        expiresLabel.isAccessibilityElement = false
        neverExpiresSwitch.accessibilityLabel = LString.expiryDateNever

        presetButton.setTitle(LString.titlePresets, for: .normal)
        presetButton.accessibilityLabel = LString.titlePresets
        presetButton.isHidden = false
        presetButton.menu = makePresetsMenu()
        presetButton.showsMenuAsPrimaryAction = true

        preferredContentSize = CGSize(width: 320, height: 370)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        neverExpiresSwitch.isOn = !canExpire
        datePicker.date = expiryDate
        refresh()
    }

    func refresh() {
        datePicker.isEnabled = !neverExpiresSwitch.isOn
        doneButton.isEnabled = isModified

        remainingTimeLabel.text = relativeTimeFormatter.string(for: datePicker.date)
        let isRelativeTimeHidden = !datePicker.isEnabled
        self.remainingTimeLabel.isHidden = isRelativeTimeHidden
    }


    private func makePresetMenuAction(_ delta: DateComponents) -> UIAction {
        let targetDate = Calendar.autoupdatingCurrent.date(byAdding: delta, to: .now) ?? .now

        let title: String
        if targetDate.timeIntervalSinceNow < .hour {
            title = relativeTimeFormatter.localizedString(for: targetDate, relativeTo: .now)
        } else {
            title = presetTimeFormatter.string(from: .now, to: targetDate) ?? "?"
        }

        let action = UIAction(title: title) { [weak self, delta] _ in
            let targetDate = Calendar.autoupdatingCurrent.date(byAdding: delta, to: .now) ?? .now
            self?.datePicker.date = targetDate
            self?.neverExpiresSwitch.isOn = false
            self?.refresh()
        }
        return action
    }

    private func makePresetsMenu() -> UIMenu {
        let todayMenu = UIMenu.make(reverse: true, options: .displayInline, children: [
            makePresetMenuAction(DateComponents(second: 0))
        ])
        let weeksMenu = UIMenu.make(reverse: true, options: .displayInline, children: [
            makePresetMenuAction(DateComponents(minute: 1, weekOfYear: 1)),
            makePresetMenuAction(DateComponents(minute: 1, weekOfYear: 2)),
        ])
        let monthsMenu = UIMenu.make(reverse: true, options: .displayInline, children: [
            makePresetMenuAction(DateComponents(month: 1, minute: 1)),
            makePresetMenuAction(DateComponents(month: 3, minute: 1)),
            makePresetMenuAction(DateComponents(month: 6, minute: 1)),
        ])
        let yearsMenu = UIMenu.make(reverse: true, options: .displayInline, children: [
            makePresetMenuAction(DateComponents(year: 1, minute: 1)),
            makePresetMenuAction(DateComponents(year: 2, minute: 1)),
        ])
        return UIMenu.make(
            title: LString.titlePresets,
            reverse: true,
            children: [todayMenu, weeksMenu, monthsMenu, yearsMenu])
    }


    @IBAction private func didToggleNeverExpiresSwitch(_ sender: UISwitch) {
        refresh()
    }

    @IBAction private func didChangeDate(_ sender: UIDatePicker) {
        refresh()
    }

    @IBAction private func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }

    @IBAction private func didPressDone(_ sender: Any) {
        assert(isModified)
        canExpire = !neverExpiresSwitch.isOn
        expiryDate = datePicker.date
        Diag.debug("Did select expiry date [date: \(expiryDate), canExpire: \(canExpire)]")
        delegate?.didChangeExpiryDate(expiryDate, canExpire: canExpire, in: self)
    }
}
