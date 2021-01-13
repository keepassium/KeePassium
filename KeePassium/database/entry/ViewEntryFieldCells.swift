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
        
        let shouldHideField =
            (field.isProtected || (field.internalName == EntryField.password))
            && Settings.current.isHideProtectedFields
        let isOpenableURL = field.resolvedValue?.isOpenableURL ?? false
        
        let cell: ViewableFieldCell
        if field is TOTPViewableField {
            cell = tableView.dequeueReusableCell(
                withIdentifier: TOTPFieldCell.storyboardID,
                for: indexPath)
                as! TOTPFieldCell
        } else if shouldHideField {
            cell = tableView.dequeueReusableCell(
                withIdentifier: ProtectedFieldCell.storyboardID,
                for: indexPath)
                as! ProtectedFieldCell
        } else if isOpenableURL {
            cell = tableView.dequeueReusableCell(
                withIdentifier: URLFieldCell.storyboardID,
                for: indexPath)
                as! URLFieldCell
        } else if field.internalName == EntryField.notes {
            cell = tableView.dequeueReusableCell(
                withIdentifier: ExpandableFieldCell.storyboardID,
                for: indexPath)
                as! ExpandableFieldCell
        } else {
            cell = tableView.dequeueReusableCell(
                withIdentifier: ViewableFieldCell.storyboardID,
                for: indexPath)
                as! ViewableFieldCell
        }
        cell.field = field
        cell.setupCell()
        return cell
    }
}


protocol ViewableFieldCellDelegate: class {
    func cellHeightDidChange(_ cell: ViewableFieldCell)
    
    func cellDidExpand(_ cell: ViewableFieldCell)
    
    func didTapCellValue(_ cell: ViewableFieldCell)
    
    func didLongTapAccessoryButton(_ cell: ViewableFieldCell)
}

extension ViewableFieldCellDelegate {
    func didTapCellValue(_ cell: ViewableFieldCell) {
    }
    func didLongTapAccessoryButton(_ cell: ViewableFieldCell) {
    }
}


protocol ViewableFieldCellBase: class {
    var nameLabel: UILabel! { get }
    var valueText: UITextView! { get }
    var valueScrollView: UIScrollView! { get }
    
    var delegate: ViewableFieldCellDelegate? { get set }
    var field: ViewableField? { get set }
    
    func setupCell()
    func getUserVisibleValue() -> String?
}

class ViewableFieldCell: UITableViewCell, ViewableFieldCellBase {
    class var storyboardID: String { "ViewableFieldCell" }
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var valueText: UITextView!
    @IBOutlet weak var valueScrollView: UIScrollView!
        
    weak var delegate: ViewableFieldCellDelegate?
    weak var field: ViewableField?
    
    override func awakeFromNib() {
        super.awakeFromNib()
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
        let textScale = Settings.current.textScale
        nameLabel.font = UIFont.systemFont(ofSize: 15 * textScale, forTextStyle: .subheadline, weight: .thin)
        nameLabel.adjustsFontForContentSizeCategory = true
        valueText.font = UIFont.monospaceFont(ofSize: 17 * textScale, forTextStyle: .body)
        valueText.adjustsFontForContentSizeCategory = true
        
        nameLabel.text = field?.visibleName
        valueText.text = getUserVisibleValue()
        accessibilityHint = LString.hintDoubleTapToCopyToClipboard
    }

    func getUserVisibleValue() -> String? {
        return field?.decoratedValue
    }
    
    @objc func didTapValueTextView(_ sender: UITextView) {
        if let selRange = valueText.selectedTextRange,
            !selRange.isEmpty
        {
            valueText.selectedTextRange = nil
        } else {
            delegate?.didTapCellValue(self)
        }
    }
}


class OpenURLAccessoryButton: UIButton {
    required init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 80))
        setImage(UIImage(asset: .openURLCellAccessory), for: .normal)
        contentMode = .scaleAspectFit

        accessibilityLabel = LString.actionOpenURL
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
}

class URLFieldCell: ViewableFieldCell {
    override class var storyboardID: String { "URLFieldCell" }

    private var url: URL?
    
    override func setupCell() {
        super.setupCell()
        
        let urlString = field?.value ?? ""
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
        accessoryView = openURLButton
        
        let openURLAction = UIAccessibilityCustomAction(
            name: LString.actionOpenURL,
            target: self,
            selector: #selector(didPressOpenURLButton))
        let shareAction = UIAccessibilityCustomAction(
            name: LString.actionShare,
            target: self,
            selector: #selector(didPressShare(_:)))
        accessibilityCustomActions = [openURLAction, shareAction]
        valueText.accessibilityTraits = .link
    }
    
    @objc
    private func handleLongPressURLButton(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began else { return }
        didPressShare(gestureRecognizer)
    }
    
    @objc
    private func didPressShare(_ sender: Any) {
        delegate?.didLongTapAccessoryButton(self)
    }
    
    @objc
    private func didPressOpenURLButton(_ sender: UIButton) {
        guard let url = url else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}


class ToggleVisibilityAccessoryButton: UIButton {
    required init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 80))
        setImage(UIImage(asset: .unhideListitem), for: .normal)
        setImage(UIImage(asset: .hideListitem), for: .selected)
        setImage(UIImage(asset: .hideListitem), for: .highlighted)
        contentMode = .scaleAspectFit
        
        accessibilityLabel = LString.actionShowInPlainText
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
}

class ProtectedFieldCell: ViewableFieldCell {
    override class var storyboardID: String { "ProtectedFieldCell" }
    private let hiddenValueMask = "* * * *"
    private var toggleButton: ToggleVisibilityAccessoryButton? 

    override func setupCell() {
        super.setupCell()
        
        let theButton = ToggleVisibilityAccessoryButton()
        theButton.addTarget(self, action: #selector(toggleValueHidden), for: .touchUpInside)
        theButton.isSelected = !(field?.isValueHidden ?? true)
        valueText.isSelectable = theButton.isSelected
        accessoryView = theButton
        toggleButton = theButton
        
        refreshTextView()
    }
    
    override func getUserVisibleValue() -> String? {
        guard let field = field else { return nil }
        return field.isValueHidden ? hiddenValueMask : field.decoratedValue
    }
    
    private func refreshTextView() {
        let value = getUserVisibleValue()
        if field?.isValueHidden ?? true {
            valueText.attributedText = nil
            valueText.text = value
            valueText.textColor = .primaryText
        } else {
            valueText.attributedText = PasswordStringHelper.decorate(
                value ?? "",
                font: valueText.font)
        }
    }
    
    @objc func toggleValueHidden() {
        guard let toggleButton = toggleButton, let field = field else { return }
        
        toggleButton.isSelected = !toggleButton.isSelected
        field.isValueHidden = !toggleButton.isSelected
        valueText.isSelectable = !field.isValueHidden
        UIView.animate(
            withDuration: 0.1,
            delay: 0.0,
            options: UIView.AnimationOptions.curveLinear,
            animations: { [weak self] in
                self?.valueText.alpha = 0.0
            },
            completion: { [weak self] _ in
                guard let self = self else { return }
                self.refreshTextView()
                self.delegate?.cellHeightDidChange(self)
                UIView.animate(
                    withDuration: 0.2,
                    delay: 0.0,
                    options: UIView.AnimationOptions.curveLinear,
                    animations: { [weak self] in
                        self?.valueText.alpha = 1.0
                    },
                    completion: nil
                )
            }
        )
    }
}


class ExpandableFieldCell: ViewableFieldCell {
    override class var storyboardID: String { "ExpandableFieldCell" }
    
    @IBOutlet weak var showMoreButton: UIButton!
    @IBOutlet weak var showMoreContainer: UIView!
    
    let heightLimit: CGFloat = 150.0

    private var heightConstraint: NSLayoutConstraint! 
    var canBeTruncated: Bool {
        let textHeight = valueScrollView.contentSize.height
        return textHeight > heightLimit
    }
    
    override func setupCell() {
        super.setupCell()
        
        if heightConstraint == nil {
            heightConstraint = valueScrollView.heightAnchor.constraint(lessThanOrEqualToConstant: heightLimit)
            heightConstraint.priority = .defaultHigh
        }
        heightConstraint.isActive = field?.isHeightConstrained ?? false

        DispatchQueue.main.async { [weak self] in
            self?.setupExpandButton()
        }
    }
    
    private func setupExpandButton() {
        guard let field = field,
            field.isMultiline else { return }
        
        let canViewMore = canBeTruncated && field.isHeightConstrained
        heightConstraint.isActive = canViewMore

        if canBeTruncated {
            showMoreContainer.isHidden = false
            showMoreButton.accessibilityLabel = LString.actionShowMore
            setButtonState(isViewMore: canViewMore)
        } else {
            showMoreContainer.isHidden = true
        }
    }
    
    private func setButtonState(isViewMore: Bool) {
        showMoreButton.isSelected = !isViewMore
        let scaleY: CGFloat = isViewMore ? 1.0 : -1.0
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.showMoreButton.imageView?.transform =
                CGAffineTransform(scaleX: 1.0, y: scaleY)
        }
    }
    
    @IBAction func didPressShowMore(_ button: UIButton) {
        assert(canBeTruncated)
        guard let field = field else { return }

        let isToBeConstrained = !field.isHeightConstrained
        heightConstraint.isActive = isToBeConstrained
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.layoutIfNeeded()
        }
        field.isHeightConstrained = isToBeConstrained
        setButtonState(isViewMore: isToBeConstrained)
        delegate?.cellHeightDidChange(self)
        if !isToBeConstrained {
            delegate?.cellDidExpand(self)
        }
    }
}


class TOTPFieldCell: ViewableFieldCell {
    override class var storyboardID: String { "TOTPFieldCell" }
    private let refreshInterval = 1.0
    
    @IBOutlet weak var progressView: UIProgressView!
    
    override func getUserVisibleValue() -> String? {
        guard var value = field?.value else { return nil }
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
    
    override func setupCell() {
        super.setupCell()
        accessoryView = nil
        accessoryType = .none
        progressView.isHidden = false
        refreshProgress()
        scheduleRefresh()
    }
    
    private func scheduleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + refreshInterval) {
            [weak self] in
            guard let self = self else { return }
            self.valueText.text = self.getUserVisibleValue()
            self.refreshProgress()
            self.scheduleRefresh()
        }
    }
    
    private func refreshProgress() {
        guard let totpViewableField = field as? TOTPViewableField else {
            assertionFailure()
            return
        }
        let progress = 1 - (totpViewableField.elapsedTimeFraction ?? 0.0)
        progressView.setProgress(progress, animated: true)
    }
}
