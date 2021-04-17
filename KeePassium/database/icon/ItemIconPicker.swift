//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol ItemIconPickerDelegate {
    func didPressCancel(in viewController: ItemIconPicker)
    func didSelect(standardIcon iconID: IconID, in viewController: ItemIconPicker)
    func didSelect(customIcon uuid: UUID, in viewController: ItemIconPicker)
    func didPressImportIcon(in viewController: ItemIconPicker, at popoverAnchor: PopoverAnchor)
    func didDelete(customIcon uuid: UUID, in viewController: ItemIconPicker)
}

final class ItemIconPickerSectionHeader: UICollectionReusableView {
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var titleLabel: UILabel!
}

final class ItemIconPickerCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    
    override var isSelected: Bool {
        get { return super.isSelected }
        set {
            super.isSelected = newValue
            refresh()
        }
    }
    
    override var isHighlighted: Bool {
        get { return super.isHighlighted }
        set {
            super.isHighlighted = newValue
            refresh()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    private func refresh() {
        let layer = contentView.layer
        if isHighlighted {
            layer.borderWidth = 1.0
            layer.borderColor = UIColor.actionTint.cgColor
            layer.backgroundColor = UIColor.actionTint.cgColor
            imageView.tintColor = UIColor.actionText
        } else {
            layer.borderWidth = 0.0
            layer.borderColor = UIColor.clear.cgColor
            layer.backgroundColor = UIColor.clear.cgColor
            imageView.tintColor = UIColor.iconTint
        }
        setNeedsDisplay()
    }
}

final class ItemIconPicker: CollectionViewControllerWithContextActions, Refreshable {
    private let cellID = "IconCell"
    private let headerCellID = "SectionHeader"

    private enum SectionID: Int {
        static let all: [SectionID] = [.standard, .custom]
        
        case standard = 0
        case custom = 1
    }
    
    var delegate: ItemIconPickerDelegate?
    var customIcons = [CustomIcon2]()
    
    var isImportAllowed = true

    private let standardIconSet: DatabaseIconSet = Settings.current.databaseIconSet
    private var selectedPath: IndexPath?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = false
        collectionView.allowsSelection = true

        if isImportAllowed {
            let importIconButton = UIBarButtonItem(
                image: UIImage(asset: .createItemToolbar),
                style: .plain,
                target: self,
                action: #selector(didPressImportIcon))
            importIconButton.accessibilityLabel = LString.actionAddCustomIcon
            navigationItem.setRightBarButton(importIconButton, animated: false)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let selectedPath = selectedPath else {
            return
        }

        collectionView.selectItem(
            at: selectedPath, animated: true,
            scrollPosition: .centeredVertically)
    }
    
    func refresh() {
        collectionView.reloadData()
    }
    
    
    @IBAction private func didPressCancel(_ sender: UIBarButtonItem) {
        delegate?.didPressCancel(in: self)
    }
    

    @objc private func didPressImportIcon(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressImportIcon(in: self, at: popoverAnchor)
    }
    
    override func getContextActionsForItem(at indexPath: IndexPath) -> [ContextualAction] {
        guard SectionID(rawValue: indexPath.section) == .some(.custom) else {
            return []
        }
        let iconIndex = indexPath.item
        guard iconIndex >= 0 && iconIndex < customIcons.count else {
            return []
        }
        
        let deleteAction = ContextualAction(
            title: LString.actionDelete,
            imageName: .trash,
            style: .destructive,
            color: .destructiveTint,
            handler: { [weak self] in
                guard let self = self else { return }
                let targetIcon = self.customIcons[iconIndex]
                self.delegate?.didDelete(customIcon: targetIcon.uuid, in: self)
            }
        )
        return [deleteAction]
    }

    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        if customIcons.count > 0 {
            return SectionID.all.count
        }
        return 1
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int) -> Int
    {
        switch SectionID(rawValue: section) {
        case .standard:
            return IconID.all.count
        case .custom:
            return customIcons.count
        default:
            assertionFailure()
            return 0
        }
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: cellID,
            for: indexPath)
            as! ItemIconPickerCell
        DispatchQueue.global(qos: .userInitiated).async {
            [standardIconSet, customIcons] in
            let kpIcon: UIImage?
            switch SectionID(rawValue: indexPath.section) {
            case .standard:
                kpIcon = standardIconSet.getIcon(IconID.all[indexPath.row])
            case .custom:
                let iconBytes = customIcons[indexPath.row].data
                kpIcon = UIImage(data: iconBytes.asData)?.withGradientUnderlay()
            default:
                assertionFailure()
                kpIcon = nil
            }

            DispatchQueue.main.async {
                let viewSize = cell.imageView.bounds
                if let iconSize = kpIcon?.size,
                   (iconSize.width > viewSize.width || iconSize.height > viewSize.height)
                {
                    cell.imageView.contentMode = .scaleAspectFit
                } else {
                    cell.imageView.contentMode = .center
                }
                cell.imageView.image = kpIcon
            }
        }
        
        if let selectedPath = selectedPath, selectedPath == indexPath {
            cell.isHighlighted = true
        } else {
            cell.isHighlighted = false
        }
        return cell
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath)
    {
        switch SectionID(rawValue: indexPath.section) {
        case .standard:
            guard indexPath.row < IconID.all.count else {
                return
            }
            let selectedIconID = IconID.all[indexPath.row]
            delegate?.didSelect(standardIcon: selectedIconID, in: self)
        case .custom:
            guard indexPath.row < customIcons.count else {
                return
            }
            let selectedIcon = customIcons[indexPath.row]
            delegate?.didSelect(customIcon: selectedIcon.uuid, in: self)
        default:
            assertionFailure()
        }
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let sectionHeader = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: headerCellID,
            for: indexPath)
            as! ItemIconPickerSectionHeader

        switch SectionID(rawValue: indexPath.section) {
        case .standard:
            sectionHeader.titleLabel.text = LString.itemIconPickerStandardIcons
        case .custom:
            sectionHeader.titleLabel.text = LString.itemIconPickerCustomIcons
        default:
            assertionFailure()
        }
        sectionHeader.separator.isHidden = (indexPath.section == 0)
        return sectionHeader
    }
    
    func selectIcon(for item: DatabaseItem?) {
        guard let item = item else {
            selectedPath = nil
            refresh()
            return
        }

        if let iconID = (item as? Group)?.iconID ?? (item as? Entry)?.iconID {
            selectedPath = IndexPath(
                row: Int(iconID.rawValue),
                section: SectionID.standard.rawValue
            )
        }

        let customIconUUID = (item as? Group2)?.customIconUUID ?? (item as? Entry2)?.customIconUUID
        if let uuid = customIconUUID,
           let iconIndex = customIcons.firstIndex(where: { $0.uuid == uuid })
        {
            selectedPath = IndexPath(
                row: iconIndex,
                section: SectionID.custom.rawValue
            )
        }
        refresh()
    }
}

extension ItemIconPicker: UICollectionViewDelegateFlowLayout {
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        let header = self.collectionView(
            collectionView,
            viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionHeader,
            at: IndexPath(row: 0, section: section))
            as! ItemIconPickerSectionHeader
        
        let horizontalMargins = collectionView.layoutMargins.left + collectionView.layoutMargins.right
        let targetWidth = collectionView.bounds.width - horizontalMargins
        var requiredLabelSize = header.titleLabel.sizeThatFits(
            CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        )
        let verticalMargins = CGFloat(8 + 8)
        requiredLabelSize.height += verticalMargins
        return requiredLabelSize
    }
}
