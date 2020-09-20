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
    func didSelectIcon(iconID: IconID?, in viewController: ItemIconPicker)
}

public class ItemIconPickerCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    
    public override var isSelected: Bool {
        get { return super.isSelected }
        set {
            super.isSelected = newValue
            refresh()
        }
    }
    
    public override var isHighlighted: Bool {
        get { return super.isHighlighted }
        set {
            super.isHighlighted = newValue
            refresh()
        }
    }
    
    public override func awakeFromNib() {
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

class ItemIconPicker: UICollectionViewController {
    private let cellID = "IconCell"

    public var delegate: ItemIconPickerDelegate?
    public var selectedIconID: IconID?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = false
        collectionView.allowsSelection = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIconID = selectedIconID {
            let selIndexPath = IndexPath(row: Int(selectedIconID.rawValue), section: 0)
            collectionView.selectItem(
                at: selIndexPath, animated: true,
                scrollPosition: .centeredVertically)
        }
    }
    
    
    @IBAction func didPressCancel(_ sender: UIBarButtonItem) {
        delegate?.didPressCancel(in: self)
    }
    

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int) -> Int
    {
        return IconID.all.count
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
            if let kpIcon = UIImage.kpIcon(forID: IconID.all[indexPath.row]) {
                DispatchQueue.main.async {
                    cell.imageView.image = kpIcon
                }
            }
        }
        if let selectedRow = selectedIconID?.rawValue, selectedRow == indexPath.row {
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
        if indexPath.row < IconID.all.count {
            let selectedIconID = IconID.all[indexPath.row]
            delegate?.didSelectIcon(iconID: selectedIconID, in: self)
        }
    }
}
