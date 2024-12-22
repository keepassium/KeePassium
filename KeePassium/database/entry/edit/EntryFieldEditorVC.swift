//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

protocol EntryFieldEditorDelegate: AnyObject {
    func didPressCancel(in viewController: EntryFieldEditorVC)
    func didPressDone(in viewController: EntryFieldEditorVC)

    func didPressAddField(in viewController: EntryFieldEditorVC)
    func didPressDeleteField(_ field: EditableField, in viewController: EntryFieldEditorVC)

    func didModifyContent(in viewController: EntryFieldEditorVC)

    func isTOTPSetupAvailable(_ viewController: EntryFieldEditorVC) -> Bool
    func isQRScannerAvailable(_ viewController: EntryFieldEditorVC) -> Bool
    func didPressQRCodeOTPSetup(in viewController: EntryFieldEditorVC)
    func didPressManualOTPSetup(in viewController: EntryFieldEditorVC)

    func getUserNameGeneratorMenu(
        for field: EditableField,
        in viewController: EntryFieldEditorVC) -> UIMenu?

    func didPressPasswordGenerator(
        for input: TextInputView,
        viaMenu: Bool,
        in viewController: EntryFieldEditorVC
    )
    func didPressPickIcon(
        in viewController: EntryFieldEditorVC
    )
    func didPressDownloadFavicon(
        for field: EditableField,
        in viewController: EntryFieldEditorVC
    )
    func didPressTags(
        in viewController: EntryFieldEditorVC
    )
}

final class EntryFieldEditorVC: UITableViewController, Refreshable {
    @IBOutlet private weak var addFieldButton: UIBarButtonItem!
    @IBOutlet private weak var doneButton: UIBarButtonItem!
    @IBOutlet private weak var otpSetupButton: UIButton!

    public var shouldFocusOnTitleField = true

    var fields = [EditableField]()
    weak var delegate: EntryFieldEditorDelegate?
    var entryIcon: UIImage?
    var shouldHighlightIcon = false
    var isDownloadingFavicon = false

    var itemCategory = ItemCategory.default
    var allowsCustomFields = false
    var supportsFaviconDownload = true

    private weak var iconButton: UIButton?


    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0

        configureOTPSetupButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
        if shouldFocusOnTitleField {
            shouldFocusOnTitleField = false
            DispatchQueue.main.async { [weak self] in
                self?.focusOnCell(at: IndexPath(row: 0, section: 0))
            }
        }
    }

    func refresh() {
        refreshControls()
        tableView.reloadData()
    }

    private func refreshControls() {
        addFieldButton.isEnabled = allowsCustomFields
        fields.sort {
            itemCategory.compare($0.internalName, $1.internalName)
        }
        revalidate()
    }

    func revalidate() {
        var isAllFieldsValid = true
        for field in fields {
            field.isValid = isFieldValid(field: field)
            isAllFieldsValid = isAllFieldsValid && field.isValid
        }
        tableView.visibleCells.forEach {
            ($0 as? EditableFieldCell)?.validate()
        }
        doneButton.isEnabled = isAllFieldsValid
    }

    private func focusOnCell(at indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        _ = cell.becomeFirstResponder()
    }

    private func selectCustomFieldName(at indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? EntryFieldEditorCustomFieldCell else {
            return
        }
        cell.selectNameText()
    }

    private func configureOTPSetupButton() {
        let isOTPSetupSupported = delegate?.isTOTPSetupAvailable(self) ?? false
        guard isOTPSetupSupported else {
            tableView.tableFooterView = nil
            return
        }

        let isQRScannerAvailable = delegate?.isQRScannerAvailable(self) ?? false
        let qrCodeSetupAction = UIAction(
            title: LString.otpSetupScanQRCode,
            image: .symbol(.qrcode),
            attributes: isQRScannerAvailable ? [] : [.disabled]
        ) { [weak self] _ in
            self?.didPressQRCodeOTPSetup()
        }
        let manualSetupAction = UIAction(
            title: LString.otpSetupEnterManually,
            image: .symbol(.keyboard)
        ) { [weak self] _ in
            self?.didPressManualOTPSetup()
        }

        otpSetupButton.setTitle(LString.otpSetUpOTPAction, for: .normal)
        if ProcessInfo.isRunningOnMac {
            otpSetupButton.addAction(manualSetupAction, for: .touchUpInside)
        } else {
            otpSetupButton.showsMenuAsPrimaryAction = true
            otpSetupButton.menu = UIMenu(children: [qrCodeSetupAction, manualSetupAction])
        }
    }


    private func confirmOverwritingOTPConfig(completion: @escaping () -> Void) {
        guard let otpField = fields.first(where: { $0.internalName == EntryField.otp }),
              let value = otpField.value,
              !value.isEmpty
        else { 
            completion()
            return
        }

        let choiceAlert = UIAlertController
            .make(
                title: LString.titleWarning,
                message: LString.otpConfigOverwriteWarning,
                dismissButtonTitle: LString.actionCancel)
            .addAction(title: LString.actionOverwrite, style: .destructive) { _ in
                completion()
            }
        present(choiceAlert, animated: true, completion: nil)
    }

    private func didPressQRCodeOTPSetup() {
        guard let isTOTPSetupSupported = delegate?.isTOTPSetupAvailable(self),
              let isQRScannerAvailable = delegate?.isQRScannerAvailable(self),
              isTOTPSetupSupported,
              isQRScannerAvailable
        else {
            assertionFailure("Tried to use an unavailable TOTP setup option")
            return
        }
        confirmOverwritingOTPConfig { [weak self] in
            guard let self else { return }
            self.delegate?.didPressQRCodeOTPSetup(in: self)
        }

    }

    private func didPressManualOTPSetup() {
        guard let isTOTPSetupSupported = delegate?.isTOTPSetupAvailable(self),
              isTOTPSetupSupported
        else {
            assertionFailure("Tried to use an unavailable TOTP setup option")
            return
        }
        confirmOverwritingOTPConfig { [weak self] in
            guard let self else { return }
            self.delegate?.didPressManualOTPSetup(in: self)
        }
    }

    @IBAction private func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }

    @IBAction private func didPressDone(_ sender: Any) {
        delegate?.didPressDone(in: self)
    }

    @IBAction private func didPressAddField(_ sender: Any) {
        assert(allowsCustomFields)
        let fieldCountBefore = fields.count
        delegate?.didPressAddField(in: self) 
        let fieldCountAfter = fields.count

        guard fieldCountAfter > fieldCountBefore else {
            Diag.warning("Field was not added")
            assertionFailure()
            return
        }

        let newIndexPath = IndexPath(row: fields.count - 1, section: 0)
        tableView.beginUpdates()
        tableView.insertRows(at: [newIndexPath], with: .fade)
        tableView.endUpdates()

        UIView.animate(
            withDuration: 0.3,
            animations: { [weak self] in
                self?.tableView.scrollToRow(at: newIndexPath, at: .top, animated: false)
            },
            completion: { [weak self] _ in
                self?.focusOnCell(at: newIndexPath)
                self?.selectCustomFieldName(at: newIndexPath)
            }
        )
        refreshControls()
    }

    func didPressDeleteField(at indexPath: IndexPath) {
        assert(allowsCustomFields)
        let fieldIndex = indexPath.row
        let field = fields[fieldIndex]
        let fieldCountBefore = fields.count
        delegate?.didPressDeleteField(field, in: self)
        let fieldCountAfter = fields.count

        guard fieldCountAfter < fieldCountBefore else {
            Diag.warning("Field was not deleted")
            assertionFailure()
            return
        }

        tableView.beginUpdates()
        tableView.deleteRows(at: [indexPath], with: .fade)
        tableView.endUpdates()
        refreshControls()
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let fieldNumber = indexPath.row
        return !fields[fieldNumber].isFixed
    }

    override func tableView(
        _ tableView: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        return UITableViewCell.EditingStyle.delete
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        if editingStyle == .delete {
            didPressDeleteField(at: indexPath)
        }
    }
}

extension EntryFieldEditorVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fields.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let fieldNumber = indexPath.row
        let field = fields[fieldNumber]

        let cell: EditableFieldCell & UITableViewCell
        if field.isFixed {
            cell = configureFixedFieldCell(field: field, tableView: tableView, at: indexPath)
        } else {
            cell = configureNonFixedFieldCell(field: field, tableView: tableView, at: indexPath)
        }
        cell.delegate = self
        cell.validate() 
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let fieldNumber = indexPath.row
        let field = fields[fieldNumber]

        switch field.internalName {
        case EntryField.tags:
            delegate?.didPressTags(in: self)
        default:
            break
        }
    }

    private func configureFixedFieldCell(
        field: EditableField,
        tableView: UITableView,
        at indexPath: IndexPath
    ) -> EditableFieldCell & UITableViewCell {
        switch (field.internalName, field.isMultiline, field.isProtected) {
        case (EntryField.title, _, _):
            return configureTitleCell(field: field, tableView: tableView, at: indexPath)
        case (EntryField.userName, _, _):
            return configureUserNameCell(field: field, tableView: tableView, at: indexPath)
        case (EntryField.password, _, _):
            return configureProtectedSingleLineCell(field: field, tableView: tableView, at: indexPath)
        case (EntryField.url, _, _):
            return configureURLCell(field: field, tableView: tableView, at: indexPath)
        case (EntryField.tags, _, _):
            return configureTagsFieldEditorCell(field: field, tableView: tableView, at: indexPath)
        case (_, true, _):
            return configureMultilineCell(field: field, tableView: tableView, at: indexPath)
        case (_, false, true):
            return configureProtectedSingleLineCell(field: field, tableView: tableView, at: indexPath)
        case (_, false, false):
            return configureSingleLineCell(field: field, tableView: tableView, at: indexPath)
        }
    }

    private func configureNonFixedFieldCell(
        field: EditableField,
        tableView: UITableView,
        at indexPath: IndexPath
    ) -> EditableFieldCell & UITableViewCell {
        return configureCustomFieldCell(field: field, tableView: tableView, at: indexPath)
    }

    private func configureCustomFieldCell(
        field: EditableField,
        tableView: UITableView,
        at indexPath: IndexPath
    ) -> EditableFieldCell & UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: EntryFieldEditorCustomFieldCell.storyboardID,
            for: indexPath)
            as! EntryFieldEditorCustomFieldCell
        cell.field = field
        return cell
    }

    private func configureTitleCell(
        field: EditableField,
        tableView: UITableView,
        at indexPath: IndexPath
    ) -> EntryFieldEditorTitleCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: EntryFieldEditorTitleCell.storyboardID,
            for: indexPath)
            as! EntryFieldEditorTitleCell
        cell.icon = entryIcon
        if shouldHighlightIcon {
            cell.pulsateIcon()
            shouldHighlightIcon = false
        }
        cell.field = field
        iconButton = cell.iconButton
        return cell
    }

    private func configureUserNameCell(
        field: EditableField,
        tableView: UITableView,
        at indexPath: IndexPath
    ) -> EntryFieldEditorSingleLineCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: EntryFieldEditorSingleLineCell.storyboardID,
            for: indexPath)
            as! EntryFieldEditorSingleLineCell
        cell.field = field

        cell.textField.keyboardType = .emailAddress
        cell.actionButton.isHidden = false
        cell.actionButton.setTitle(LString.actionChooseUserName, for: .normal)
        cell.actionButton.setImage(nil, for: .normal)
        cell.actionButton.configuration = nil
        cell.actionButton.isEnabled = true
        return cell
    }

    private func configureURLCell(
        field: EditableField,
        tableView: UITableView,
        at indexPath: IndexPath
    ) -> EntryFieldEditorSingleLineCell {
        let cell = configureSingleLineCell(field: field, tableView: tableView, at: indexPath)
        cell.textField.keyboardType = .URL
        return cell
    }

    private func configureSingleLineCell(
        field: EditableField,
        tableView: UITableView,
        at indexPath: IndexPath
    ) -> EntryFieldEditorSingleLineCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: EntryFieldEditorSingleLineCell.storyboardID,
            for: indexPath)
            as! EntryFieldEditorSingleLineCell
        cell.field = field

        cell.textField.keyboardType = .default
        cell.actionButton.isHidden = true
        return cell
    }

    private func configureProtectedSingleLineCell(
        field: EditableField,
        tableView: UITableView,
        at indexPath: IndexPath
    ) -> PasswordEntryFieldCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: PasswordEntryFieldCell.storyboardID,
            for: indexPath)
            as! PasswordEntryFieldCell
        cell.field = field
        return cell
    }

    private func configureMultilineCell(
        field: EditableField,
        tableView: UITableView,
        at indexPath: IndexPath
    ) -> EntryFieldEditorMultiLineCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: EntryFieldEditorMultiLineCell.storyboardID,
            for: indexPath)
            as! EntryFieldEditorMultiLineCell
        cell.field = field
        return cell
    }

    private func configureTagsFieldEditorCell(
        field: EditableField,
        tableView: UITableView,
        at indexPath: IndexPath
    ) -> TagsFieldEditorCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: TagsFieldEditorCell.storyboardID,
            for: indexPath)
            as! TagsFieldEditorCell
        cell.selectionStyle = .default
        cell.field = field
        return cell
    }
}

extension EntryFieldEditorVC: ValidatingTextFieldDelegate {
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        guard let titleField = fields.first(where: { $0.internalName == EntryField.title }) else {
            assertionFailure("There is no entry title field")
            sender.text = ""
            return
        }
        titleField.value = text
        delegate?.didModifyContent(in: self)
    }

    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return sender.text?.isNotEmpty ?? false
    }

    func validatingTextField(_ sender: ValidatingTextField, validityDidChange isValid: Bool) {
        revalidate()
    }
}

extension EntryFieldEditorVC: EditableFieldCellDelegate {
    func didPressButton(
        for field: EditableField,
        at popoverAnchor: PopoverAnchor,
        in cell: EditableFieldCell
    ) {
        switch cell {
        case is EntryFieldEditorSingleLineCell where field.internalName == EntryField.url:
            delegate?.didPressDownloadFavicon(for: field, in: self)
        default:
            assertionFailure("Button pressed in an unknown field")
        }
    }

    func didPressReturn(for field: EditableField, in cell: EditableFieldCell) {
        didPressDone(self)
    }

    func didChangeField(_ field: EditableField, in cell: EditableFieldCell) {
        delegate?.didModifyContent(in: self)
        revalidate()
    }

    func didPressDelete(_ field: EditableField, in cell: EditableFieldCell) {
        guard let tableCell = cell as? UITableViewCell,
              let indexPath = tableView.indexPath(for: tableCell)
        else {
            assertionFailure("Sending cell not found")
            return
        }
        didPressDeleteField(at: indexPath)
    }

    func didPressRandomize(for input: TextInputView, viaMenu: Bool, in cell: EditableFieldCell) {
        delegate?.didPressPasswordGenerator(for: input, viaMenu: viaMenu, in: self)
    }

    func isFieldValid(field: EditableField) -> Bool {
        if field.internalName == EntryField.title {
            return field.value?.isNotEmpty ?? false
        }

        if field.internalName.isEmpty {
            return false
        }

        var sameNameCount = 0
        for f in fields {
            if f.internalName == field.internalName {
                sameNameCount += 1
            }
        }
        return (sameNameCount == 1)
    }

    func getActionConfiguration(for field: EditableField) -> EntryFieldActionConfiguration {
        var menu: UIMenu?
        var state = Set<EntryFieldActionConfiguration.State>()
        switch field.internalName {
        case EntryField.title:
            if isDownloadingFavicon {
                state = [.busy]
            } else {
                state = [.enabled]
            }
            menu = makeIconButtonMenu()
        case EntryField.userName:
            menu = delegate?.getUserNameGeneratorMenu(for: field, in: self)
            state = [.enabled]
        case EntryField.url:
            state = [.hidden]
            iconButton?.menu = makeIconButtonMenu()
        default:
            state = [.hidden]
        }
        return EntryFieldActionConfiguration(state: state, menu: menu)
    }

    private func makeIconButtonMenu() -> UIMenu {
        let changeIconAction = UIAction(
            title: LString.actionChangeIcon,
            image: .symbol(.squareAndPencil),
            handler: { [weak self] _ in
                guard let self else { return }
                self.delegate?.didPressPickIcon(in: self)
            }
        )

        var faviconDownloadAttributes = UIMenuElement.Attributes()
        if !supportsFaviconDownload {
            faviconDownloadAttributes.insert(.hidden)
        }
        if !ManagedAppConfig.shared.isFaviconDownloadAllowed {
            faviconDownloadAttributes.insert(.disabled)
        }

        if let urlField = fields.first(where: { $0.internalName == EntryField.url }),
           URL.from(malformedString: urlField.resolvedValue ?? "") != nil
        {
        } else {
            faviconDownloadAttributes.insert(.disabled)
        }

        let downloadFaviconAction = UIAction(
            title: LString.actionDownloadFavicon,
            image: .symbol(.wandAndStars),
            attributes: faviconDownloadAttributes,
            handler: { [weak self] _ in
                if let self,
                   let urlField = fields.first(where: { $0.internalName == EntryField.url }) {
                    self.delegate?.didPressDownloadFavicon(for: urlField, in: self)
                }
            }
        )
        return UIMenu(children: [changeIconAction, downloadFaviconAction])
    }
}
