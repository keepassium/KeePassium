//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UITableViewCell {

    public func demoShowEditActions(lastActionColor: UIColor) {
        guard let cellView = contentView.superview else { return }
        let wasClippingToBounds = cellView.clipsToBounds
        cellView.clipsToBounds = false

        let maxShift = cellView.frame.height / 2 

        let fakeActionView = UIView(frame: self.contentView.bounds)
        fakeActionView.backgroundColor = .destructiveTint
        contentView.addSubview(fakeActionView)
        fakeActionView.translatesAutoresizingMaskIntoConstraints = false
        fakeActionView.topAnchor.constraint(equalTo: cellView.topAnchor).isActive = true
        fakeActionView.bottomAnchor.constraint(equalTo: cellView.bottomAnchor).isActive = true
        fakeActionView.leadingAnchor.constraint(equalTo: cellView.trailingAnchor).isActive = true
        fakeActionView.widthAnchor.constraint(equalToConstant: maxShift).isActive = true
        fakeActionView.isOpaque = true
        fakeActionView.layoutIfNeeded()
        
        animateFrameShift(cellView: cellView, by: -maxShift) {
            [weak self] in
            self?.animateFrameShift(cellView: cellView, by: maxShift) {
                [weak self] in
                self?.animateFrameShift(cellView: cellView, by: -0.3 * maxShift) {
                    [weak self] in
                    self?.animateFrameShift(cellView: cellView, by: 0.3 * maxShift) {
                        fakeActionView.removeFromSuperview()
                        cellView.clipsToBounds = wasClippingToBounds
                    }
                }
            }
        }
    }
    
    private func animateFrameShift(
        cellView: UIView,
        by dx: CGFloat,
        completion: @escaping ()->Void)
    {
        
        let shiftedFrame = cellView.frame.offsetBy(dx: dx, dy: 0.0)
        let options: UIView.AnimationOptions = (dx > 0) ? [.curveEaseIn] : [.curveEaseOut]
        UIView.animate(
            withDuration: 0.25,
            delay: 0.0,
            options: options,
            animations: {
                cellView.frame = shiftedFrame
            },
            completion: { (finished) in completion() })
    }
}
