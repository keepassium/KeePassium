//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

public protocol PasswordGeneratorDelegate: AnyObject {
    func didPressDone(in viewController: PasswordGeneratorVC)
    func didPressCopyToClipboard(in viewController: PasswordGeneratorVC)
    func didChangeConfig(_ config: PasswordGeneratorParams, in viewController: PasswordGeneratorVC)
    func didChangeMode(_ mode: PasswordGeneratorMode, in viewController: PasswordGeneratorVC)
    func didPressWordlistInfo(wordlist: PassphraseWordlist, in viewController: PasswordGeneratorVC)
    func shouldGeneratePassword(
        mode: PasswordGeneratorMode,
        config: PasswordGeneratorParams,
        animated: Bool,
        in viewController: PasswordGeneratorVC)
}

final public class PasswordGeneratorVC: UIViewController, Refreshable {
    private typealias Mode = PasswordGeneratorMode
    
    private enum CellID {
        static let wideCell = "WideCell"
        static let fixedSetCell = "FixedSetCell"
        static let customSetCell = "CustomSetCell"
        static let sliderCell = "SliderCell"
        static let stepperCell = "StepperCell"
    }
    
    private enum CellIndex {
        static let commonSectionCount = 1
        static let modeSelector = IndexPath(row: 0, section: 0)
        
        static let basicModeSectionCount = 1
        static let basicModeSectionSizes = [0, 1] 
        static let basicModeLength = IndexPath(row: 0, section: 1)
        
        static let customModeSectionCount = 3
        static let customModeSectionSizes = [0, 1, 8, 1] 
        static let customModeLength = IndexPath(row: 0, section: 1)
        
        static let customModeIncludeUpperCase = IndexPath(row: 0, section: 2)
        static let customModeIncludeLowerCase = IndexPath(row: 1, section: 2)
        static let customModeIncludeDigits = IndexPath(row: 2, section: 2)
        static let customModeIncludeSpecials = IndexPath(row: 3, section: 2)
        static let customModeIncludeLookalikes = IndexPath(row: 4, section: 2)
        static let customModeRequireList = IndexPath(row: 5, section: 2)
        static let customModeAllowList = IndexPath(row: 6, section: 2)
        static let customModeBlockList = IndexPath(row: 7, section: 2)

        static let customModeMaxConsecutive = IndexPath(row: 0, section: 3)

        static let passphraseModeSectionCount = 2
        static let passphraseModeSectionSizes = [0, 2, 2] 
        static let passphraseModeLength = IndexPath(row: 0, section: 1)
        static let passphraseModeWordList = IndexPath(row: 1, section: 1)
        static let passphraseModeSeparator = IndexPath(row: 0, section: 2)
        static let passphraseModeWordCase = IndexPath(row: 1, section: 2)
    }
    
    @IBOutlet private weak var passwordLabel: PasswordGeneratorLabel!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var copyButton: UIBarButtonItem!
    @IBOutlet private weak var updateButton: UIBarButtonItem!
    @IBOutlet private weak var doneButton: UIBarButtonItem!
    @IBOutlet private weak var altDoneButton: UIBarButtonItem!
    
    public weak var delegate: PasswordGeneratorDelegate?
    
    public internal(set) var config: PasswordGeneratorParams!
    public internal(set) var mode: PasswordGeneratorMode = .basic
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = LString.PasswordGenerator.titleRandomGenerator
        
        copyButton.accessibilityLabel = LString.actionCopy
        updateButton.accessibilityLabel = LString.PasswordGenerator.actionGenerate
        
        tableView.delegate = self
        tableView.dataSource = self
        generate(animated: false)
        
        setupAccessibility(passwordLabel)
        UIAccessibility.post(notification: .screenChanged, argument: passwordLabel )
    }
    
    func refresh() {
        self.tableView.reloadData()
    }
    
    private func saveConfig() {
        config.lastMode = mode
        delegate?.didChangeConfig(config, in: self)
    }

    private func generate(animated: Bool) {
        delegate?.shouldGeneratePassword(mode: mode, config: config, animated: animated, in: self)
    }
    
    @IBAction private func didPressRegenerate(_ sender: Any) {
        generate(animated: true)
        UIAccessibility.post(notification: .layoutChanged, argument: passwordLabel)
    }
    
    @IBAction private func didPressDone(_ sender: Any) {
        delegate?.didPressDone(in: self)
    }
    
    @IBAction func didPressCopyToClipboard(_ sender: Any) {
        delegate?.didPressCopyToClipboard(in: self)
    }
}

extension PasswordGeneratorVC {
    public func showPassphrase(_ passphrase: String, animated: Bool) {
        if animated {
            animateTransition(passwordLabel)
        }
        passwordLabel.attributedText = nil
        passwordLabel.text = passphrase
        passwordLabel.font = .preferredFont(forTextStyle: .body)
        passwordLabel.textColor = .primaryText
        passwordLabel.lineBreakMode = .byWordWrapping
        passwordLabel.accessibilityIsPhrase = true
        
        doneButton.isEnabled = true
        altDoneButton.isEnabled = true
        copyButton.isEnabled = true
    }
    
    public func showPassword(_ password: String, animated: Bool) {
        if animated {
            animateTransition(passwordLabel)
        }
        passwordLabel.text = nil
        passwordLabel.lineBreakMode = .byCharWrapping
        passwordLabel.attributedText = PasswordStringHelper.decorate(
            password,
            font: .monospaceFont(forTextStyle: .body))
        passwordLabel.accessibilityIsPhrase = false
        
        doneButton.isEnabled = true
        altDoneButton.isEnabled = true
        copyButton.isEnabled = true
    }
    
    private func setupAccessibility(_ label: PasswordGeneratorLabel) {
        let acceptAction = UIAccessibilityCustomAction(name: LString.actionDone) {
            [weak self] action in
            self?.didPressDone(action)
            return true
        }
        let copyAction = UIAccessibilityCustomAction(name: LString.actionCopy) {
            [weak self] action in
            self?.didPressCopyToClipboard(action)
            return true
        }
        let generateAction = UIAccessibilityCustomAction(name: LString.PasswordGenerator.actionGenerate) {
            [weak self] action in
            self?.didPressRegenerate(action)
            return true
        }
        label.accessibilityCustomActions = [acceptAction, copyAction, generateAction]
    }
    
    public func showError(_ error: Error) {
        passwordLabel.attributedText = nil
        passwordLabel.text = error.localizedDescription
        passwordLabel.font = .preferredFont(forTextStyle: .body)
        passwordLabel.textColor = .errorMessage
        passwordLabel.lineBreakMode = .byWordWrapping
        
        passwordLabel.accessibilityLabel = LString.PasswordGeneratorError.titleCannotGenerateText
        passwordLabel.accessibilityValue = error.localizedDescription
        passwordLabel.accessibilityIsPhrase = true
        passwordLabel.accessibilityCustomActions = nil
        HapticFeedback.play(.error)
        
        let errorIntro = NSAttributedString(
            string: LString.PasswordGeneratorError.titleCannotGenerateText,
            attributes: [.accessibilitySpeechQueueAnnouncement: true])
        let errorDescription = NSAttributedString(
            string: error.localizedDescription,
            attributes: [.accessibilitySpeechQueueAnnouncement: true])
        UIAccessibility.post(notification: .announcement, argument: errorIntro)
        UIAccessibility.post(notification: .announcement, argument: errorDescription)
        
        doneButton.isEnabled = false
        altDoneButton.isEnabled = false
        copyButton.isEnabled = false
    }
    
    private func animateTransition(_ view: UIView) {
        let animation = CATransition()
        animation.type = .reveal
        animation.subtype = .fromBottom
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.duration = 0.3
        view.layer.add(animation, forKey: CATransitionType.fade.rawValue)
    }
}

extension PasswordGeneratorVC: UITableViewDataSource {
    
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        switch mode {
        case .basic:
            return CellIndex.commonSectionCount + CellIndex.basicModeSectionCount
        case .custom:
            return CellIndex.commonSectionCount + CellIndex.customModeSectionCount
        case .passphrase:
            return CellIndex.commonSectionCount + CellIndex.passphraseModeSectionCount
        }
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (mode, section) {
        case (_, CellIndex.modeSelector.section): 
            return 1
        case (.basic, _):
            return CellIndex.basicModeSectionSizes[section]
        case (.custom, _):
            return CellIndex.customModeSectionSizes[section]
        case (.passphrase, _):
            return CellIndex.passphraseModeSectionSizes[section]
        }
    }
    
    public func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        switch (mode, section) {
        default:
            return nil
        }
    }
    
    public func tableView(
        _ tableView: UITableView,
        titleForFooterInSection section: Int
    ) -> String? {
        switch (mode, section) {
        case (.custom, CellIndex.customModeMaxConsecutive.section):
            return LString.PasswordGenerator.maxConsecutiveDescription
        default:
            return nil
        }
    }
    
    
    public func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: getReusableCellID(for: indexPath),
            for: indexPath
        )
        resetCellStyle(cell)
        switch (mode, indexPath.section) {
        case (_, CellIndex.modeSelector.section):
            configureModeSelectorCell(cell)
        case (.basic, _):
            configureBasicModeCell(cell, at: indexPath)
        case (.custom, _):
            configureCustomModeCell(cell, at: indexPath)
        case (.passphrase, _):
            configurePassphraseModeCell(cell, at: indexPath)
        }
        return cell
    }
    
    private func getReusableCellID(for indexPath: IndexPath) -> String {
        switch (mode, indexPath) {
        case (_, CellIndex.modeSelector):
            return CellID.wideCell
        case (.basic, CellIndex.customModeLength):
            return CellID.sliderCell
        case (.custom, CellIndex.customModeLength):
            return CellID.sliderCell
        case (.custom, CellIndex.customModeIncludeUpperCase),
             (.custom, CellIndex.customModeIncludeLowerCase),
             (.custom, CellIndex.customModeIncludeDigits),
             (.custom, CellIndex.customModeIncludeSpecials),
             (.custom, CellIndex.customModeIncludeLookalikes):
            return CellID.fixedSetCell
        case (.custom, CellIndex.customModeMaxConsecutive):
            return CellID.stepperCell
        case (.custom, CellIndex.customModeBlockList),
             (.custom, CellIndex.customModeAllowList),
             (.custom, CellIndex.customModeRequireList):
            return CellID.customSetCell
        case (.passphrase, CellIndex.passphraseModeLength):
            return CellID.sliderCell
        case (.passphrase, CellIndex.passphraseModeSeparator),
             (.passphrase, CellIndex.passphraseModeWordCase),
             (.passphrase, CellIndex.passphraseModeWordList):
            return CellID.customSetCell
        default:
            return CellID.customSetCell
        }
    }
    
    private func resetCellStyle(_ cell: UITableViewCell) {
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.textColor = .primaryText
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .footnote)
        cell.detailTextLabel?.textColor = .auxiliaryText
        cell.imageView?.image = nil
        cell.accessoryType = .none
        
        cell.textLabel?.accessibilityLabel = nil
        cell.detailTextLabel?.accessibilityLabel = nil
        cell.accessibilityTraits = []
        cell.accessibilityValue = nil
        cell.accessibilityHint = nil
    }
    
    private func configureModeSelectorCell(_ cell: UITableViewCell) {
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.text = LString.PasswordGeneratorMode.title
        cell.detailTextLabel?.text = mode.description
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .body)
        cell.imageView?.image = UIImage.get(.sliderVertical3)
    }
}

extension PasswordGeneratorVC: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        switch (mode, indexPath) {
        case (_, CellIndex.modeSelector):
            showModeSelector(at: popoverAnchor)
            break
        case (.custom, CellIndex.customModeRequireList):
            showCustomSetEditor(at: indexPath, condition: .required)
            break
        case (.custom, CellIndex.customModeAllowList):
            showCustomSetEditor(at: indexPath, condition: .allowed)
            break
        case (.custom, CellIndex.customModeBlockList):
            showCustomSetEditor(at: indexPath, condition: .excluded)
            break
        case (.passphrase, CellIndex.passphraseModeWordList):
            showWordlistSelector(at: popoverAnchor)
            break
        case (.passphrase, CellIndex.passphraseModeWordCase):
            showWordCaseSelector(at: popoverAnchor)
            break
        case (.passphrase, CellIndex.passphraseModeSeparator):
            showWordSeparatorEditor()
            break
        default:
            break
        }
    }
    
    public func tableView(
        _ tableView: UITableView,
        accessoryButtonTappedForRowWith indexPath: IndexPath
    ) {
        switch (mode, indexPath) {
        case (.passphrase, CellIndex.passphraseModeWordList):
            delegate?.didPressWordlistInfo(wordlist: config.passphraseModeConfig.wordlist, in: self)
        default:
            break
        }
    }
    
    public func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        switch mode {
        case .custom:
            return getCustomModeContextMenu(at: indexPath)
        default:
            return nil
        }
    }
    
    private func showModeSelector(at popoverAnchor: PopoverAnchor) {
        let sheet = UIAlertController(
            title: LString.PasswordGeneratorMode.title,
            message: nil,
            preferredStyle: .actionSheet)
        let modes: [PasswordGeneratorMode] = [.basic, .custom, .passphrase]
        for mode in modes {
            sheet.addAction(title: mode.description, style: .default) { [weak self] _ in
                self?.setMode(mode)
                let cellToReturn = self?.tableView.cellForRow(at: CellIndex.modeSelector)
                UIAccessibility.post(notification: .layoutChanged, argument: cellToReturn)
            }
        }
        sheet.addAction(title: LString.actionCancel, style: .cancel) { [weak self] _ in
            let cellToReturn = self?.tableView.cellForRow(at: CellIndex.modeSelector)
            UIAccessibility.post(notification: .layoutChanged, argument: cellToReturn)
        }
        sheet.modalPresentationStyle = .popover
        popoverAnchor.apply(to: sheet.popoverPresentationController)
        present(sheet, animated: true)
    }
    
    private func setMode(_ mode: PasswordGeneratorMode) {
        self.mode = mode
        refresh()
        delegate?.didChangeMode(mode, in: self)
    }
}


extension PasswordGeneratorVC {
    private func configureBasicModeCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        switch indexPath {
        case CellIndex.basicModeLength:
            configureBasicModeLengthCell(cell as! PasswordGeneratorLengthCell)
        default:
            assertionFailure("Unexpected cell")
        }
    }
    
    private func configureBasicModeLengthCell(_ cell: PasswordGeneratorLengthCell) {
        cell.title = LString.PasswordGenerator.titlePasswordLength
        let lengthRange = BasicPasswordGeneratorParams.lengthRange
        cell.minValue = lengthRange.lowerBound
        cell.maxValue = lengthRange.upperBound
        cell.value = config.basicModeConfig.length
        cell.valueChanged = { [weak self] value in
            self?.config.basicModeConfig.length = value
            self?.saveConfig()
            self?.generate(animated: false)
        }
    }
}


extension PasswordGeneratorVC {
    
    private func configureCustomModeCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        switch indexPath {
        case CellIndex.customModeLength:
            configureCustomModeLengthCell(cell as! PasswordGeneratorLengthCell)
        case CellIndex.customModeIncludeUpperCase:
            configureCustomModeFixedSetCell(
                cell as! PasswordGeneratorFixedSetCell,
                set: .upperCase,
                conditions: [.required, .allowed, .inactive])
        case CellIndex.customModeIncludeLowerCase:
            configureCustomModeFixedSetCell(
                cell as! PasswordGeneratorFixedSetCell,
                set: .lowerCase,
                conditions: [.required, .allowed, .inactive])
        case CellIndex.customModeIncludeDigits:
            configureCustomModeFixedSetCell(
                cell as! PasswordGeneratorFixedSetCell,
                set: .digits,
                conditions: [.required, .allowed, .inactive])
        case CellIndex.customModeIncludeSpecials:
            configureCustomModeFixedSetCell(
                cell as! PasswordGeneratorFixedSetCell,
                set: .specials,
                conditions: [.required, .allowed, .inactive])
        case CellIndex.customModeIncludeLookalikes:
            configureCustomModeFixedSetCell(
                cell as! PasswordGeneratorFixedSetCell,
                set: .lookalikes,
                conditions: [.excluded, .inactive])
        case CellIndex.customModeMaxConsecutive:
            configureCustomModeMaxConsecutiveCell(cell as! PasswordGeneratorStepperCell)
        case CellIndex.customModeBlockList:
            configureCustomModeCustomSetCell(cell, condition: .excluded)
        case CellIndex.customModeAllowList:
            configureCustomModeCustomSetCell(cell, condition: .allowed)
        case CellIndex.customModeRequireList:
            configureCustomModeCustomSetCell(cell, condition: .required)
        default:
            assertionFailure("Unexpected cell")
        }
    }
    
    private func configureCustomModeLengthCell(_ cell: PasswordGeneratorLengthCell) {
        cell.title = LString.PasswordGenerator.titlePasswordLength
        let lengthRange = CustomPasswordGeneratorParams.lengthRange
        cell.minValue = lengthRange.lowerBound
        cell.maxValue = lengthRange.upperBound
        cell.value = config.customModeConfig.length
        cell.valueChanged = { [weak self] value in
            self?.config.customModeConfig.length = value
            self?.saveConfig()
            self?.generate(animated: false)
        }
    }
    
    private func configureCustomModeFixedSetCell(
        _ cell: PasswordGeneratorFixedSetCell,
        set: CustomPasswordGeneratorParams.FixedSet,
        conditions: [InclusionCondition]
    ) {
        cell.textLabel?.text = set.title
        cell.textLabel?.accessibilityLabel = set.description
        cell.availableValues = conditions
        cell.value = config.customModeConfig.fixedSets[set] ?? .allowed
        cell.valueChangeHandler = { [weak self] newValue in
            self?.config.customModeConfig.fixedSets[set] = newValue
            self?.saveConfig()
            self?.generate(animated: true)
        }
    }
    
    private func configureCustomModeCustomSetCell(
        _ cell: UITableViewCell,
        condition: InclusionCondition
    ) {
        var customSetDescription = config.customModeConfig.customLists[condition] ?? ""
        cell.textLabel?.accessibilityLabel = LString.PasswordGenerator.titleCustomCharacters
        if customSetDescription.isEmpty {
            customSetDescription = LString.PasswordGenerator.titleCustomSetEmpty
            cell.textLabel?.text = nil
            cell.textLabel?.attributedText = NSAttributedString(
                string: customSetDescription,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .body).addingTraits(.traitItalic),
                    .foregroundColor: UIColor.disabledText
                ]
            )
            cell.accessibilityValue = LString.PasswordGenerator.titleCustomSetEmpty
        } else {
            cell.textLabel?.attributedText = nil
            cell.textLabel?.text = customSetDescription
            cell.accessibilityAttributedValue = NSAttributedString(
                string: customSetDescription,
                attributes: [.accessibilitySpeechSpellOut: true])
        }
        cell.detailTextLabel?.text = condition.description
        cell.imageView?.image = condition.image
        cell.accessoryType = .disclosureIndicator
    }
    
    private func showCustomSetEditor(at indexPath: IndexPath, condition: InclusionCondition) {
        let alert = UIAlertController(title: condition.description, message: nil, preferredStyle: .alert)
        alert.addTextField { [self] textField in
            textField.text = config.customModeConfig.customLists[condition]
            textField.accessibilityLabel = LString.PasswordGenerator.titleCustomCharacters
        }
        alert.addAction(title: LString.actionOK, style: .default) {
            [weak self, weak alert] _ in
            guard let self = self else { return }
            let text = alert?.textFields!.first!.text ?? ""
            self.config.customModeConfig.customLists[condition] = text.removingRepetitions()
            self.saveConfig()
            self.refresh()
            self.generate(animated: true)
            
            let returnToCell = self.tableView.cellForRow(at: indexPath)
            UIAccessibility.post(notification: .layoutChanged, argument: returnToCell)
        }
        alert.addAction(title: LString.actionCancel, style: .cancel) { [weak self] _ in
            let returnToCell = self?.tableView.cellForRow(at: indexPath)
            UIAccessibility.post(notification: .layoutChanged, argument: returnToCell)
        }
        present(alert, animated: true)
    }
    
    private func configureCustomModeMaxConsecutiveCell(
        _ cell: PasswordGeneratorStepperCell
    ) {
        cell.title = LString.PasswordGenerator.maxConsecutiveTitle
        cell.imageView?.image = nil
        cell.value = config.customModeConfig.maxConsecutive
        cell.valueChangeHandler = { [weak self] newValue in
            self?.config.customModeConfig.maxConsecutive = newValue
            self?.saveConfig()
            self?.generate(animated: true)
        }
    }
    
    private func getCustomModeSetTextForCopying(at indexPath: IndexPath) -> String? {
        guard mode == .custom else {
            return nil
        }
        
        let textToCopy: String?
        switch indexPath {
        case CellIndex.customModeIncludeUpperCase:
            textToCopy = CustomPasswordGeneratorParams.FixedSet.upperCase.value.sorted().joined()
            break
        case CellIndex.customModeIncludeLowerCase:
            textToCopy = CustomPasswordGeneratorParams.FixedSet.lowerCase.value.sorted().joined()
            break
        case CellIndex.customModeIncludeDigits:
            textToCopy = CustomPasswordGeneratorParams.FixedSet.digits.value.sorted().joined()
            break
        case CellIndex.customModeIncludeSpecials:
            textToCopy = CustomPasswordGeneratorParams.FixedSet.specials.value.sorted().joined()
            break
        case CellIndex.customModeIncludeLookalikes:
            textToCopy = CustomPasswordGeneratorParams.FixedSet.lookalikes.value.sorted().joined()
            break
        case CellIndex.customModeRequireList:
            textToCopy = config.customModeConfig.customLists[.required]
            break
        case CellIndex.customModeAllowList:
            textToCopy = config.customModeConfig.customLists[.allowed]
            break
        case CellIndex.customModeBlockList:
            textToCopy = config.customModeConfig.customLists[.excluded]
            break
        default:
            return nil
        }
        
        if textToCopy?.isEmpty ?? true {
            return nil
        }
        return textToCopy
    }
    
    private func getCustomModeContextMenu(at indexPath: IndexPath) -> UIContextMenuConfiguration? {
        guard let textForCopying = getCustomModeSetTextForCopying(at: indexPath) else {
            return nil
        }
        let copyAction = UIAction(title: LString.actionCopy, image: .get(.docOnDoc)) { _ in
            let timeout = Double(Settings.current.clipboardTimeout.seconds)
            Clipboard.general.insert(text: textForCopying, timeout: timeout)
        }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(title: "", children: [copyAction])
        }
    }
}

extension PasswordGeneratorVC {
    private func configurePassphraseModeCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        switch indexPath {
        case CellIndex.passphraseModeLength:
            configurePassphraseModeLengthCell(cell as! PasswordGeneratorLengthCell)
        case CellIndex.passphraseModeSeparator:
            configurePassphraseModeSeparatorCell(cell)
        case CellIndex.passphraseModeWordCase:
            configurePassphraseModeWordCaseCell(cell)
        case CellIndex.passphraseModeWordList:
            configurePassphraseModeWordListCell(cell)
        default:
            assertionFailure("Unexpected cell")
        }
    }
    
    private func configurePassphraseModeLengthCell(_ cell: PasswordGeneratorLengthCell) {
        cell.title = LString.PasswordGenerator.titleWordCount
        let lengthRange = PassphraseGeneratorParams.wordCountRange
        cell.minValue = lengthRange.lowerBound
        cell.maxValue = lengthRange.upperBound
        cell.value = config.passphraseModeConfig.wordCount
        cell.valueChanged = { [weak self] value in
            self?.config.passphraseModeConfig.wordCount = value
            self?.saveConfig()
            self?.generate(animated: false)
        }
    }
    
    private func configurePassphraseModeSeparatorCell(_ cell: UITableViewCell) {
        cell.textLabel?.text = LString.PasswordGenerator.titleWordSepartor
        cell.imageView?.image = UIImage.get(.arrowLeftAndRight)
        cell.detailTextLabel?.text = getSeparatorDescription(config.passphraseModeConfig.separator)
        cell.accessoryType = .disclosureIndicator
    }
    private func configurePassphraseModeWordCaseCell(_ cell: UITableViewCell) {
        let wordCase = config.passphraseModeConfig.wordCase
        cell.textLabel?.text = LString.PasswordGenerator.WordCase.title
        cell.imageView?.image = UIImage.get(.textformat)
        cell.detailTextLabel?.text = wordCase.description
        cell.accessoryType = .disclosureIndicator
    }
    private func configurePassphraseModeWordListCell(_ cell: UITableViewCell) {
        cell.textLabel?.text = LString.PasswordGenerator.titleWordlist
        cell.imageView?.image = UIImage.get(.bookClosed)
        cell.detailTextLabel?.text = config.passphraseModeConfig.wordlist.description
        cell.accessoryType = .detailDisclosureButton
    }
    
    private func showWordlistSelector(at popoverAnchor: PopoverAnchor) {
        let sheet = UIAlertController(
            title: LString.PasswordGenerator.titleWordlist,
            message: nil,
            preferredStyle: .actionSheet
        )
        for wordlist in PassphraseWordlist.allCases {
            sheet.addAction(title: wordlist.description, style: .default) { [weak self] _ in
                self?.setWordlist(wordlist)
            }
        }
        sheet.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        sheet.modalPresentationStyle = .popover
        popoverAnchor.apply(to: sheet.popoverPresentationController)
        present(sheet, animated: true)
    }
    
    private func setWordlist(_ wordlist: PassphraseWordlist) {
        config.passphraseModeConfig.wordlist = wordlist
        saveConfig()
        refresh()
        generate(animated: true)
    }
    
    private func showWordCaseSelector(at popoverAnchor: PopoverAnchor) {
        let sheet = UIAlertController(
            title: LString.PasswordGenerator.WordCase.title,
            message: nil,
            preferredStyle: .actionSheet
        )
        for wordCase in PassphraseGenerator.WordCase.allCases {
            let action = UIAlertAction(title: wordCase.description, style: .default) { [weak self] _ in
                self?.setWordCase(wordCase)
            }
            sheet.addAction(action)
        }
        sheet.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        sheet.modalPresentationStyle = .popover
        popoverAnchor.apply(to: sheet.popoverPresentationController)
        present(sheet, animated: true)
    }
    
    private func setWordCase(_ wordCase: PassphraseGenerator.WordCase) {
        config.passphraseModeConfig.wordCase = wordCase
        saveConfig()
        refresh()
        generate(animated: true)
    }
    
    private func showWordSeparatorEditor() {
        let alert = UIAlertController(
            title: LString.PasswordGenerator.titleWordSepartor,
            message: nil,
            preferredStyle: .alert
        )
        alert.addTextField()
        alert.textFields!.first?.text = config.passphraseModeConfig.separator
        alert.addAction(title: LString.actionOK, style: .default) { [weak self, weak alert] _ in
            let text = alert?.textFields!.first!.text ?? ""
            self?.setWordSeparator(text)
        }
        alert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        present(alert, animated: true)
    }
    
    private func setWordSeparator(_ separator: String) {
        config.passphraseModeConfig.separator = separator
        saveConfig()
        refresh()
        generate(animated: true)
    }
    
    private func getSeparatorDescription(_ separator: String) -> String {
        if separator == " " {
            return LString.PasswordGenerator.spaceCharacterName
        }
        return separator
    }
}


extension String {
    func removingRepetitions() -> String {
        var present = Set<Character>()
        return self.filter { present.insert($0).inserted }
    }
}
