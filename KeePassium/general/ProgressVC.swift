//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class ProgressVC: UIViewController {
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var percentLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    
    override public var title: String? {
        didSet { statusLabel?.text = title }
    }
    
    public var isCancellable = true {
        didSet { cancelButton?.isEnabled = isCancellable }
    }

    private weak var progress: ProgressEx?

    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        progressView.progress = 0.0
        statusLabel.text = title
        percentLabel.text = nil
        cancelButton.setTitle(LString.actionCancel, for: .normal)
        cancelButton.isEnabled = isCancellable
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    }
    
    public func update(with progress: ProgressEx) {
        percentLabel.text = String(format: "%.0f%%", 100.0 * progress.fractionCompleted)
        progressView.setProgress(Float(progress.fractionCompleted), animated: true)
        
        cancelButton.isEnabled = cancelButton.isEnabled &&
            progress.isCancellable &&
            !progress.isCancelled
        self.progress = progress
    }
    
    @IBAction func didPressCancel(_ sender: UIButton) {
        progress?.cancel()
    }
}
