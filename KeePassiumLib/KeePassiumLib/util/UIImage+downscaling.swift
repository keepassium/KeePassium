//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public extension UIImage {

    func downscalingToSquare(maxSide: CGFloat) -> UIImage? {
        let targetSide: CGFloat
        if size.width > maxSide && size.height > maxSide {
            targetSide = maxSide
        } else {
            targetSide = min(size.width, size.height)
        }

        let targetSize = CGSize(width: targetSide, height: targetSide)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        self.draw(in: CGRect(x: 0, y: 0, width: targetSide, height: targetSide))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized?.withRenderingMode(self.renderingMode)
    }
}
