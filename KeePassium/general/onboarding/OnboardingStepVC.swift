//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import UIKit

final class OnboardingStepVC: UIViewController {
    var step: OnboardingStep!

    @IBOutlet private weak var illustrationImageView: UIImageView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var contentScrollView: UIScrollView!
    @IBOutlet private weak var buttonsStackView: UIStackView!
    @IBOutlet private weak var buttonsBorderView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = ImageAsset.backgroundPattern.asColor()

        step.actions
            .filter { !$0.attributes.contains(.hidden) }
            .forEach {
                buttonsStackView.addArrangedSubview(createButton(forAction: $0, primary: true))
            }
        if step.canSkip,
           let skipAction = step.skipAction
        {
            buttonsStackView.addArrangedSubview(createButton(forAction: skipAction, primary: false))
        }

        messageLabel.attributedText = makeAttributedText(title: step.title, text: step.text)
        messageLabel.accessibilityLabel = [step.title, step.text]
            .compactMap { $0 }
            .joined(separator: ". ")
        illustrationImageView.image = step.illustration
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: messageLabel)
    }

    private func createButton(forAction action: UIAction, primary: Bool) -> UIButton {
        var buttonConfig: UIButton.Configuration = primary ? .filled() : .borderless()
        buttonConfig.cornerStyle = .large
        buttonConfig.buttonSize = .large
        buttonConfig.title = action.title
        buttonConfig.titleAlignment = .center
        buttonConfig.titleLineBreakMode = .byWordWrapping
        let button = UIButton(configuration: buttonConfig, primaryAction: action)
        return button
    }

    private func makeAttributedText(title: String?, text: String?) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if let title {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.lineBreakStrategy = .pushOut
            paragraphStyle.paragraphSpacingBefore = 12.0
            paragraphStyle.paragraphSpacing = 12.0

            let attributedTitle = NSAttributedString(
                string: title + "\n",
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .title1),
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: UIColor.label,
                ]
            )
            result.append(attributedTitle)
        }

        if let text {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.lineBreakStrategy = .pushOut
            paragraphStyle.lineHeightMultiple = 1.2
            paragraphStyle.paragraphSpacing = 12.0
            paragraphStyle.paragraphSpacingBefore = 0.0

            let attributedBody = NSMutableAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .body),
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: UIColor.label,
                ]
            )
            result.append(attributedBody)
        }
        return result
    }
}

extension OnboardingStepVC {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.async {
            self.refreshButtonsBackground()
        }
    }
    private func refreshButtonsBackground() {
        let isScrollable = contentScrollView.contentSize.height >= contentScrollView.bounds.height
        buttonsBorderView.isHidden = !isScrollable
    }
}
