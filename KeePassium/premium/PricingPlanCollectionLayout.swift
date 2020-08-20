//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class PricingPlanCollectionLayout: UICollectionViewFlowLayout {
    private var previousOffset: CGFloat = 0
    private var currentPage: Int = 0
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        scrollDirection = .horizontal
    }
    
    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint)
        -> CGPoint
    {
        guard let collectionView = collectionView else {
            return super.targetContentOffset(
                forProposedContentOffset: proposedContentOffset,
                withScrollingVelocity: velocity)
        }
        
        let bounds = collectionView.bounds
        let targetRect = CGRect(
            x: proposedContentOffset.x,
            y: 0,
            width: bounds.width,
            height: bounds.height)
        let horizontalCenter = proposedContentOffset.x + (bounds.width / 2.0)
        
        var offsetAdjustment = CGFloat.greatestFiniteMagnitude
        super.layoutAttributesForElements(in: targetRect)?.forEach { layoutAtributes in
            let itemHorizontalCenter = layoutAtributes.center.x;
            if (abs(itemHorizontalCenter - horizontalCenter) < abs(offsetAdjustment)) {
                offsetAdjustment = itemHorizontalCenter - horizontalCenter
            }
        }
        return CGPoint(x: proposedContentOffset.x + offsetAdjustment, y: proposedContentOffset.y);
    }
}

