//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import MessageUI
import KeePassiumLib

class SupportEmailComposer: NSObject {
    private let supportEmail = "support@keepassium.com"
    
    typealias CompletionHandler = ((Bool)->Void)
    private let completionHandler: CompletionHandler?
    private var subject = ""
    private var content = ""
    
    private init(subject: String, content: String, completionHandler: CompletionHandler?) {
        self.completionHandler = completionHandler
        self.subject = subject
        self.content = content
    }
    
    static func show(includeDiagnostics: Bool, completion: CompletionHandler?=nil) {
        guard let infoDict = Bundle.main.infoDictionary else {
            Diag.error("Bundle.main.infoDictionary is nil?!")
            return
        }
        let appName = infoDict["CFBundleDisplayName"] as? String ?? "KeePassium"
        let appVersion = infoDict["CFBundleShortVersionString"] as? String ?? "_0.0"
        let subject, content: String
        if includeDiagnostics {
            subject = "\(appName) v\(appVersion) - Problem"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)! 
            content = LString.emailTemplateDescribeTheProblemHere +
                "\n\n----- Diagnostic Info -----\n" +
                "\(appName) v\(appVersion)\n" +
                Diag.toString()
        } else {
            subject = "\(appName) v\(appVersion) - Support Request"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)! 
            content = ""
        }
        
        let instance = SupportEmailComposer(subject: subject, content: content,
                                            completionHandler: completion)
        
        instance.openSystemEmailComposer()
    }
    
    private func showEmailComposer() {
        let emailComposerVC = MFMailComposeViewController()
        emailComposerVC.mailComposeDelegate = self
        emailComposerVC.setToRecipients([supportEmail])
        emailComposerVC.setSubject(subject)
        emailComposerVC.setMessageBody(content, isHTML: false)
    }
    
    private func openSystemEmailComposer() {
        let body = content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)! 
        let mailtoUrl = "mailto:\(supportEmail)?subject=\(subject)&body=\(body)"
        guard let url = URL(string: mailtoUrl) else {
            Diag.error("Failed to create mailto URL")
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: self.completionHandler)
    }
}

extension SupportEmailComposer: MFMailComposeViewControllerDelegate {
    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?)
    {
        let success = (result == .saved || result == .sent)
        completionHandler?(success)
    }
}
