//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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

    @available(iOS 13, *)
    private lazy var relativeTimeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.formattingContext = .listItem
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
        if #available(iOS 14, *) {
            datePicker.preferredDatePickerStyle = .inline
        }
        expiresLabel.isAccessibilityElement = false
        neverExpiresSwitch.accessibilityLabel = LString.expiryDateNever
        
        if #available(iOS 14, *) {
            presetButton.setTitle(LString.titlePresets, for: .normal)
            presetButton.accessibilityLabel = LString.titlePresets
            presetButton.isHidden = false
            presetButton.menu = makePresetsMenu()
            presetButton.showsMenuAsPrimaryAction = true
        }
        
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

        guard #available(iOS 13, *) else {
            remainingTimeLabel.isHidden = true
            return
        }

        remainingTimeLabel.text = relativeTimeFormatter.string(for: datePicker.date) 
        let isRelativeTimeHidden = !datePicker.isEnabled
        self.remainingTimeLabel.isHidden = isRelativeTimeHidden
    }
    
    
    @available(iOS 14, *)
    private func makePresetMenuAction(_ interval: TimeInterval) -> UIAction {
        let title = presetTimeFormatter.string(from: interval)!
        let action = UIAction(title: title) { [weak self] _ in
            self?.datePicker.date = .now.addingTimeInterval(interval)
            self?.neverExpiresSwitch.isOn = false
            self?.refresh()
        }
        return action
    }
    
    private func makePresetsMenu() -> UIMenu {
        let weeksMenu = UIMenu.make(reverse: true, options: .displayInline, children: [
            makePresetMenuAction(1 * .week),
            makePresetMenuAction(2 * .week),
        ])
        let monthsMenu = UIMenu.make(reverse: true, options: .displayInline, children: [
            makePresetMenuAction(31 * .day),  
            makePresetMenuAction(91 * .day),  
            makePresetMenuAction(182 * .day), 
        ])
        let yearsMenu = UIMenu.make(reverse: true, options: .displayInline, children: [
            makePresetMenuAction(1 * .year),
            makePresetMenuAction(2 * .year),
        ])
        return UIMenu.make(
            title: LString.titlePresets,
            reverse: true,
            children: [weeksMenu, monthsMenu, yearsMenu])
    }
    
    
    @IBAction func didToggleNeverExpiresSwitch(_ sender: UISwitch) {
        refresh()
    }
    
    @IBAction func didChangeDate(_ sender: UIDatePicker) {
        refresh()
    }
    
    @IBAction func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }
    
    @IBAction func didPressDone(_ sender: Any) {
        assert(isModified)
        canExpire = !neverExpiresSwitch.isOn
        expiryDate = datePicker.date
        Diag.debug("Did select expiry date [date: \(expiryDate), canExpire: \(canExpire)]")
        delegate?.didChangeExpiryDate(expiryDate, canExpire: canExpire, in: self)
    }
}
