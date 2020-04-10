//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib


class ViewableFieldCellFactory {
    public static func dequeueAndConfigureCell(
        from tableView: UITableView,
        for indexPath: IndexPath,
        field: ViewableField
    ) -> ViewableFieldCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ViewableFieldCell.storyboardID,
            for: indexPath)
            as! ViewableFieldCell
        cell.field = field
        
        if field is TOTPViewableField {
            cell.decorator = TOTPFieldCellDecorator(cell: cell)
        } else if field.isProtected || (field.internalName == EntryField.password) {
            cell.decorator = ProtectedFieldCellDecorator(cell: cell)
        } else {
            cell.decorator = URLFieldCellDecorator(cell: cell)
        }
        cell.setupCell()
        return cell
    }
}

class OpenURLAccessoryButton: UIButton {
    required init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 80))
        setImage(UIImage(asset: .openURLCellAccessory), for: .normal)
        contentMode = .scaleAspectFit
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
}

class ToggleVisibilityAccessoryButton: UIButton {
    required init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 80))
        setImage(UIImage(asset: .unhideListitem), for: .normal)
        setImage(UIImage(asset: .hideListitem), for: .selected)
        setImage(UIImage(asset: .hideListitem), for: .highlighted)
        contentMode = .scaleAspectFit
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
}

protocol ViewableFieldCellDelegate: class {
    func cellHeightDidChange(_ cell: ViewableFieldCell)
    
    func didTapCellValue(_ cell: ViewableFieldCell)
    
    func didLongTapAccessoryButton(_ cell: ViewableFieldCell)
}

protocol ViewableFieldCellDecorator: class {
    func setupCell(_ cell: ViewableFieldCell)
    func getUserVisibleValue() -> String?
    init(cell: ViewableFieldCell)
}

class ViewableFieldCell: UITableViewCell {
    public static let storyboardID = "ViewableFieldCell"
    @IBOutlet fileprivate weak var nameLabel: UILabel!
    @IBOutlet weak var valueText: UITextView!
    @IBOutlet weak var valueScrollView: UIScrollView!
    @IBOutlet fileprivate weak var progressView: UIProgressView!
    
    weak var delegate: ViewableFieldCellDelegate?
    var decorator: ViewableFieldCellDecorator?
    weak var field: ViewableField?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCell()
        let textTapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(didTapValueTextView))
        textTapGestureRecognizer.numberOfTapsRequired = 1
        valueText.addGestureRecognizer(textTapGestureRecognizer)
        let scrollTapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(didTapValueTextView))
        scrollTapGestureRecognizer.numberOfTapsRequired = 1
        valueScrollView.addGestureRecognizer(scrollTapGestureRecognizer)
    }
    
    func setupCell() {
        let nameFont = UIFont.systemFont(ofSize: 15, weight: .thin)
        let nameFontMetrics = UIFontMetrics(forTextStyle: .subheadline)
        nameLabel.font = nameFontMetrics.scaledFont(for: nameFont)
        
        let valueFont = UIFont(name: "Menlo", size: 17) ?? UIFont.systemFont(ofSize: 17)
        let valueFontMetrics = UIFontMetrics(forTextStyle: .body)
        valueText.font = valueFontMetrics.scaledFont(for: valueFont)
        
        nameLabel.text = field?.visibleName
        valueText.text = decorator?.getUserVisibleValue()
        decorator?.setupCell(self)
    }
    
    @objc func didTapValueTextView(_ sender: Any) {
        if let selRange = valueText.selectedTextRange,
            !selRange.isEmpty
        {
            valueText.selectedTextRange = nil
        } else {
            delegate?.didTapCellValue(self)
        }
    }
}

class URLFieldCellDecorator: ViewableFieldCellDecorator {
    weak var cell: ViewableFieldCell?
    private var url: URL?

    required init(cell: ViewableFieldCell) {
        self.cell = cell
    }
    
    func setupCell(_ cell: ViewableFieldCell) {
        cell.progressView.isHidden = true
        guard let urlString = cell.field?.value, urlString.isOpenableURL else {
            url = nil
            cell.accessoryType = .none
            cell.accessoryView = nil
            return
        }
        
        url = URL(string: urlString)
        let openURLButton = OpenURLAccessoryButton()
        openURLButton.addTarget(
            self,
            action: #selector(didPressOpenURLButton),
            for: .touchUpInside)
        let longTapRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPressURLButton))
        openURLButton.addGestureRecognizer(longTapRecognizer)
        
        cell.accessoryView = openURLButton
        cell.accessoryType = .detailButton
    }
    
    func getUserVisibleValue() -> String? {
        return cell?.field?.value
    }

    @objc
    private func handleLongPressURLButton(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began else { return }
        guard let cell = self.cell else { return }
        cell.delegate?.didLongTapAccessoryButton(cell)
    }
    
    @objc
    private func didPressOpenURLButton(_ sender: UIButton) {
        guard let url = url else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

class ProtectedFieldCellDecorator: ViewableFieldCellDecorator {
    weak var cell: ViewableFieldCell?
    private let hiddenValueMask = "* * * *"
    private var toggleButton: ToggleVisibilityAccessoryButton? 
    
    required init(cell: ViewableFieldCell) {
        self.cell = cell
    }
    
    func setupCell(_ cell: ViewableFieldCell) {
        cell.progressView.isHidden = true
        
        let theButton = ToggleVisibilityAccessoryButton()
        theButton.addTarget(self, action: #selector(toggleValueHidden), for: .touchUpInside)
        theButton.isSelected = !(cell.field?.isValueHidden ?? true)
        cell.valueText.isSelectable = theButton.isSelected
        cell.accessoryView = theButton
        cell.accessoryType = .detailButton
        self.toggleButton = theButton
    }
    
    func getUserVisibleValue() -> String? {
        guard let field = cell?.field else { return nil }
        return field.isValueHidden ? hiddenValueMask : field.value
    }
    
    @objc func toggleValueHidden() {
        guard let toggleButton = toggleButton,
              let cell = cell,
              let field = cell.field else { return }
        
        toggleButton.isSelected = !toggleButton.isSelected
        field.isValueHidden = !toggleButton.isSelected
        cell.valueText.isSelectable = !field.isValueHidden
        UIView.animate(
            withDuration: 0.1,
            delay: 0.0,
            options: UIView.AnimationOptions.curveLinear,
            animations: {
                cell.valueText.alpha = 0.0
            },
            completion: {
                [weak self] _ in
                guard let _self = self else { return }
                let value = _self.getUserVisibleValue()
                if cell.field?.isValueHidden ?? true {
                    cell.valueText.attributedText = nil
                    cell.valueText.text = value
                    cell.valueText.textColor = .primaryText
                } else {
                    cell.valueText.attributedText = PasswordStringHelper.decorate(
                        value ?? "",
                        font: cell.valueText.font)
                }
                cell.delegate?.cellHeightDidChange(cell)
                UIView.animate(
                    withDuration: 0.2,
                    delay: 0.0,
                    options: UIView.AnimationOptions.curveLinear,
                    animations: {
                        cell.valueText.alpha = 1.0
                    },
                    completion: nil)
            }
        )
    }
}

class TOTPFieldCellDecorator: ViewableFieldCellDecorator {
    private let refreshInterval = 1.0
    weak var cell: ViewableFieldCell?

    required init(cell: ViewableFieldCell) {
        self.cell = cell
    }

    func getUserVisibleValue() -> String? {
        guard var value = cell?.field?.value else { return nil }
        switch value.count {
        case 5: value.insert(" ", at: String.Index(utf16Offset: 2, in: value))
        case 6: value.insert(" ", at: String.Index(utf16Offset: 3, in: value))
        case 7: value.insert(" ", at: String.Index(utf16Offset: 3, in: value))
        case 8: value.insert(" ", at: String.Index(utf16Offset: 4, in: value))
        default:
            break
        }
        return value
    }
    
    func setupCell(_ cell: ViewableFieldCell) {
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.progressView.isHidden = false
        refreshProgress()
        scheduleRefresh()
    }
    
    private func scheduleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + refreshInterval) {
            [weak self] in
            guard let cell = self?.cell else { return }
            cell.valueText.text = self?.getUserVisibleValue()
            self?.refreshProgress()
            self?.scheduleRefresh()
        }
    }
    
    private func refreshProgress() {
        guard let cell = cell else { return }
        guard let totpViewableField = cell.field as? TOTPViewableField else {
            assertionFailure()
            return
        }
        let progress = 1 - (totpViewableField.elapsedTimeFraction ?? 0.0)
        cell.progressView.setProgress(progress, animated: true)
    }
}


