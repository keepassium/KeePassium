//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol IconChooserDelegate {
    func iconChooser(didChooseIcon iconID: IconID?)
}
fileprivate let selectedColor = UIColor.actionTint

public class IconChooserCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    public override var isSelected: Bool {
        get { return super.isSelected }
        set {
            super.isSelected = newValue
            setNeedsDisplay()
        }
    }
    public override var isHighlighted: Bool {
        get { return super.isHighlighted }
        set {
            super.isHighlighted = newValue
            setNeedsDisplay()
        }
    }
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let layer = self.contentView.layer
        layer.cornerRadius = 4.0
        if isHighlighted || isSelected {
            layer.borderWidth = isSelected ? 1.0 : 1.0
            layer.borderColor = selectedColor.cgColor
        } else { 
            layer.borderColor = UIColor.clear.cgColor
        }
    }
}

class ChooseIconVC: UICollectionViewController {
    private let cellID = "IconCell"

    public var delegate: IconChooserDelegate?
    public var selectedIconID: IconID?
    
    public static func make(
        selectedIconID: IconID?,
        delegate: IconChooserDelegate?) -> UIViewController
    {
        let vc = ChooseIconVC.instantiateFromStoryboard()
        vc.selectedIconID = selectedIconID
        vc.delegate = delegate
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = false
        collectionView.allowsSelection = true
        
        if let selectedIconID = selectedIconID {
            let selIndexPath = IndexPath(row: Int(selectedIconID.rawValue), section: 0)
            collectionView.selectItem(
                at: selIndexPath, animated: true,
                scrollPosition: .centeredVertically)
            collectionView.cellForItem(at: selIndexPath)?.isHighlighted = true
        }
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
            as! IconChooserCell
        DispatchQueue.global(qos: .userInitiated).async {
            if let kpIcon = UIImage.kpIcon(forID: IconID.all[indexPath.row]) {
                DispatchQueue.main.async {
                    cell.imageView.image = kpIcon
                }
            }
        }
        return cell
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath)
    {
        if indexPath.row < IconID.all.count {
            delegate?.iconChooser(didChooseIcon: IconID.all[indexPath.row])
            navigationController?.popViewController(animated: true)
        }
    }
}
