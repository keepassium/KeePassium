//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol FirstSetupDelegate: AnyObject {
    func didPressCancel(in firstSetup: FirstSetupVC)
    func didPressAddDatabase(in firstSetup: FirstSetupVC, at popoverAnchor: PopoverAnchor)
    func didPressSkip(in firstSetup: FirstSetupVC)
}

class FirstSetupVC: UIViewController {
    @IBOutlet weak var footerTextView: UITextView!

    private weak var delegate: FirstSetupDelegate?

    static func make(delegate: FirstSetupDelegate? = nil) -> FirstSetupVC {
        let vc = FirstSetupVC.instantiateFromStoryboard()
        vc.delegate = delegate
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setToolbarHidden(true, animated: true)
        footerTextView.text = LString.autoFillSetupFooterMessage
    }

    @IBAction private func didPressCancelButton(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }

    @IBAction private func didPressAddDatabase(_ sender: UIButton) {
        let popoverAnchor = PopoverAnchor(sourceView: sender, sourceRect: sender.bounds)
        delegate?.didPressAddDatabase(in: self, at: popoverAnchor)
    }

    @IBAction private func didPressSkip(_ sender: UIButton) {
        delegate?.didPressSkip(in: self)
    }
}


extension LString {
    // swiftlint:disable line_length
    public static let autoFillSetupFooterMessage = NSLocalizedString(
        "[AutoFill/Setup/footer]",
        value: "The AutoFill cannot automatically access the files you already have in the main KeePassium app.\n\nWhy? Behind the scenes, the system treats AutoFill as a separate app, independent from the main KeePassium process. For security reasons, an app cannot simply access any external files – unless you explicitly link these files to that app. Thus the system guarantees that the app can only access the few files you allowed it to.\n\nAs a result, both AutoFill and the main KeePassium app need to be given their own permissions for each external file. Luckily, this is a one-time procedure.",
        comment: ""
    )
    // swiftlint:enable line_length
}
