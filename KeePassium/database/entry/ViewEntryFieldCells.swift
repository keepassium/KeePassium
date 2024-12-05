//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

class ViewableFieldCellFactory {
    public static func dequeueAndConfigureCell(
        from tableView: UITableView,
        for indexPath: IndexPath,
        field: ViewableField
    ) -> ViewableFieldCell {

        let isPasswordField = field.internalName == EntryField.password
        let isOpenableURL = field.resolvedValue?.isOpenableURL ?? false

        let cell: ViewableFieldCell
        if field is TOTPViewableField {
            cell = tableView.dequeueReusableCell(
                withIdentifier: TOTPFieldCell.storyboardID,
                for: indexPath)
                as! TOTPFieldCell
        } else if field is PasskeyViewableField {
            cell = tableView.dequeueReusableCell(
                withIdentifier: PasskeyFieldCell.storyboardID,
                for: indexPath)
                as! PasskeyFieldCell
        } else if field.isProtected || isPasswordField {
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
        } else if field.internalName == EntryField.tags {
            cell = tableView.dequeueReusableCell(
                withIdentifier: TagsCell.storyboardID,
                for: indexPath)
                as! TagsCell
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


protocol ViewableFieldCellDelegate: AnyObject {
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


protocol ViewableFieldCellBase: AnyObject {
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

    func setupCell() {
        let textScale = Settings.current.textScale
        nameLabel.font = UIFont
            .preferredFont(forTextStyle: .subheadline)
            .withRelativeSize(textScale)
        nameLabel.adjustsFontForContentSizeCategory = true

        setupValueScroll(valueText: valueText, scrollView: valueScrollView)

        nameLabel.text = field?.visibleName
        valueText.text = getUserVisibleValue()
        accessibilityHint = LString.hintDoubleTapToCopyToClipboard
    }

    func setupValueScroll(valueText: UITextView?, scrollView: UIScrollView?) {
        guard let valueText, let scrollView else { return }
        let textScale = Settings.current.textScale
        valueText.font = UIFont.entryTextFont().withRelativeSize(textScale)
        valueText.adjustsFontForContentSizeCategory = true

        let textTapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(didTapValueTextView))
        textTapGestureRecognizer.numberOfTapsRequired = 1
        valueText.addGestureRecognizer(textTapGestureRecognizer)

        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        if ProcessInfo.isCatalystApp {
            scrollView.isScrollEnabled = false
            scrollView.showsVerticalScrollIndicator = false
        }
    }

    func getUserVisibleValue() -> String? {
        return field?.decoratedResolvedValue
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
        super.init(frame: .zero)
        setImage(.symbol(.externalLink), for: .normal)
        contentMode = .scaleAspectFit
        sizeToFit()

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

        let urlString = field?.resolvedValue ?? ""
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
        super.init(frame: .zero)
        setImage(.symbol(.eye), for: .normal)
        setImage(.symbol(.eyeFill), for: .selected)
        setImage(.symbol(.eyeFill), for: .highlighted)
        contentMode = .scaleAspectFit
        sizeToFit()

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
        toggleButton = theButton

        guard let field,
              field.internalName == EntryField.password,
              field.isAuditable else {
            accessoryView = theButton
            refreshTextView()
            return
        }

        let indicatorView = PasswordQualityIndicatorIconView()
        indicatorView.quality = .init(password: field.resolvedValue)
        indicatorView.onTap = { [weak self] indicator in
            guard let toastHost = self?.contentView,
                  let quality = indicator.quality
            else {
                return
            }
            let description = String.localizedStringWithFormat(
                LString.titlePasswordQualityTemplate,
                quality.title)
            let toastStyle = ToastStyle()
            let toastView = toastHost.toastViewForMessage(
                description,
                title: nil,
                image: .symbol(quality.symbolName, tint: quality.iconColor),
                style: toastStyle)
            toastHost.hideToast()
            toastHost.showToast(toastView, duration: 1.0, position: .center, action: nil)
        }

        guard !indicatorView.isHidden else {
            accessoryView = theButton
            refreshTextView()
            return
        }

        let wrapperiew = UIView()
        wrapperiew.addSubview(theButton)
        wrapperiew.addSubview(indicatorView)
        wrapperiew.frame = .init(x: 0, y: 0, width: 44 + 24, height: 24)
        indicatorView.frame = .init(x: 0, y: 0, width: 44, height: 24)
        theButton.frame = .init(x: 44, y: 0, width: 24, height: 24)

        accessoryView = wrapperiew

        refreshTextView()
    }

    override func getUserVisibleValue() -> String? {
        guard let field = field else { return nil }
        return field.isValueHidden ? hiddenValueMask : field.decoratedResolvedValue
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

final class TagsCell: ViewableFieldCell {
    override class var storyboardID: String { "TagsCell" }

    override func setupCell() {
        super.setupCell()

        valueText.attributedText = TagFormatter.format(field?.value)
        valueText.accessibilityLabel = field?.value
    }
}

final class PasskeyFieldCell: ViewableFieldCell {
    override class var storyboardID: String { "PasskeyFieldCell" }

    @IBOutlet private weak var valueScrollView2: UIScrollView!
    @IBOutlet private weak var valueText2: UITextView!

    override func getUserVisibleValue() -> String? {
        return field?.value
    }

    override func setupCell() {
        super.setupCell()
        guard let field = field as? PasskeyViewableField else {
            assertionFailure()
            return
        }
        setupValueScroll(valueText: valueText2, scrollView: valueScrollView2)

        valueText.text = field.relyingParty
        valueText2.text = field.username
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
        showMoreContainer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)

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

    @IBAction private func didPressShowMore(_ button: UIButton) {
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


protocol DynamicFieldCell: ViewableFieldCell, Refreshable {
    func startRefreshing()
    func stopRefreshing()

}


class TOTPFieldCell: ViewableFieldCell, DynamicFieldCell {
    override class var storyboardID: String { "TOTPFieldCell" }
    private let refreshInterval = 1.0

    @IBOutlet weak var progressView: UIProgressView!

    private var refreshTimer: Timer?

    deinit {
        stopRefreshing()
    }

    func startRefreshing() {
        assert(refreshTimer == nil, "Already refreshing")
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

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
        refresh()
    }

    func refresh() {
        guard let totpViewableField = field as? TOTPViewableField else {
            assertionFailure()
            return
        }
        let progress = 1 - (totpViewableField.elapsedTimeFraction ?? 0.0)
        progressView.setProgress(Float(progress), animated: true)

        valueText.text = getUserVisibleValue()
    }
}
