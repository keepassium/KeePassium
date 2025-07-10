//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import CoreImage.CIFilterBuiltins
import Foundation
import KeePassiumLib
import UIKit

final class QRCodeVC: UIViewController {
    private let image: UIImage
    private let maxSize: CGSize

    init?(text: String, maxSize: CGSize) {
        let generator = CIFilter.qrCodeGenerator()
        generator.message = text.data(using: String.Encoding.utf8)!
        generator.correctionLevel = "L"
        guard let qrImage = generator.outputImage else {
            Diag.error("Failed to generate QRCode image")
            return nil
        }

        let scaleTransform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledQRImage = qrImage.transformed(by: scaleTransform)
        image = UIImage(ciImage: scaledQRImage)
        self.maxSize = maxSize

        super.init(nibName: nil, bundle: nil)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)

        viewRespectsSystemMinimumLayoutMargins = false
        view.layoutMargins = .init(top: 8, left: 8, bottom: 8, right: 8)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
        ])

        computePreferredSize()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        computePreferredSize()
    }

    private func computePreferredSize() {
        let fittingSize = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let side = min(
            maxSize.width * 0.8,
            maxSize.height * 0.8,
            view.bounds.width,
            view.bounds.height,
            fittingSize.width,
            fittingSize.height
        )
        preferredContentSize = CGSize(width: side, height: side)
    }

    @objc private func onTap(_ gesture: UIGestureRecognizer) {
        if gesture.state == .ended {
            dismiss(animated: true)
        }
    }
}

extension QRCodeVC: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(
        for controller: UIPresentationController
    ) -> UIModalPresentationStyle {
        return .none
    }

    func popoverPresentationControllerShouldDismissPopover(
        _ popoverPresentationController: UIPopoverPresentationController
    ) -> Bool {
        return true
    }
}
