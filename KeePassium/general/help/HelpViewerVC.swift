//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol HelpViewerDelegate: class {
    func didPressShare(at popoverAnchor: PopoverAnchor, in viewController: HelpViewerVC)
}

class HelpViewerVC: UIViewController {
    @IBOutlet weak var bodyTextView: UITextView!
    weak var delegate: HelpViewerDelegate?
    
    var content: HelpArticle? {
        didSet {
            refresh()
        }
    }
    private var contentSizeObservation: NSKeyValueObservation?
    
    
    public static func create() -> HelpViewerVC {
        return HelpViewerVC.instantiateFromStoryboard()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = LString.titleHelpViewer

        let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(didPressShareButton(_:)))
        navigationItem.rightBarButtonItem = shareButton
        
        bodyTextView.textContainerInset.top = 16
        bodyTextView.textContainerInset.left = 8
        bodyTextView.textContainerInset.right = 8
        
        bodyTextView.linkTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.actionTint
        ]
        
        contentSizeObservation = bodyTextView.observe(\.contentSize, options: [.new]) {
            [weak self] (textView, change) in
            self?.preferredContentSize = textView.contentSize
        }
        refresh()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bodyTextView.setContentOffset(.zero, animated: false)
    }
    
    func refresh() {
        guard isViewLoaded else { return }
        guard let content = content else {
            bodyTextView.attributedText = nil
            bodyTextView.text = nil
            return
        }
        bodyTextView.attributedText = content.rendered()
    }
    
    @objc func didPressShareButton(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressShare(at: popoverAnchor, in: self)
    }

}
