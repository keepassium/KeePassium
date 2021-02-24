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
    private static let freeSupportEmail = "support@keepassium.com"
    private static let betaSupportEmail = "beta@keepassium.com"
    private static let premiumSupportEmail = "premium-support@keepassium.com"
    
    enum Subject: String { 
        case problem = "Problem"
        case supportRequest = "Support Request"
        case proUpgrade = "Pro Upgradе"
    }
    
    typealias CompletionHandler = ((Bool)->Void)
    private let completionHandler: CompletionHandler?
    private weak var parent: UIViewController?
    private var popoverAnchor: PopoverAnchor?
    private var subject = ""
    private var content = ""
    
    private init(
        subject: String,
        content: String,
        parent: UIViewController,
        popoverAnchor: PopoverAnchor?=nil,
        completionHandler: CompletionHandler?
    ) {
        self.subject = subject
        self.content = content
        self.parent = parent
        self.popoverAnchor = popoverAnchor
        self.completionHandler = completionHandler
    }
    
    static func show(
        subject: Subject,
        parent: UIViewController,
        popoverAnchor: PopoverAnchor,
        completion: CompletionHandler?=nil
    ) {
        let subjectText = "\(AppInfo.name) - \(subject.rawValue)" 
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)! 
        
        let includeDiagnostics = (subject == .problem)
        let contentText: String
        if includeDiagnostics {
            contentText = LString.emailTemplateDescribeTheProblemHere +
                "\n\n----- Diagnostic Info -----\n" +
                Diag.toString() +
                "\n\n\(AppInfo.description)"
        } else {
            contentText = "\n\n\(AppInfo.description)"
        }
        
        let instance = SupportEmailComposer(
            subject: subjectText,
            content: contentText,
            parent: parent,
            popoverAnchor: popoverAnchor,
            completionHandler: completion)
        
        instance.openSystemEmailComposer()
    }
    
    internal static func getSupportEmail() -> String {
        if Settings.current.isTestEnvironment {
            return betaSupportEmail
        }
        
        if PremiumManager.shared.isPremiumSupportAvailable() {
            return premiumSupportEmail
        } else {
            return freeSupportEmail
        }
    }
    
    private func showEmailComposer() {
        let emailComposerVC = MFMailComposeViewController()
        emailComposerVC.mailComposeDelegate = self
        emailComposerVC.setToRecipients([SupportEmailComposer.getSupportEmail()])
        emailComposerVC.setSubject(subject)
        emailComposerVC.setMessageBody(content, isHTML: false)
    }
    
    private func openSystemEmailComposer() {
        let body = content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)! 
        let email = SupportEmailComposer.getSupportEmail()
        let mailtoUrl = "mailto:\(email)?subject=\(subject)&body=\(body)"
        guard let url = URL(string: mailtoUrl) else {
            Diag.error("Failed to create mailto URL")
            return
        }
        
        let urlOpener: URLOpener
        #if MAIN_APP
        urlOpener = URLOpener(UIApplication.shared)
        #else
        urlOpener = URLOpener(parent)
        #endif
        
        
        let app = UIApplication.shared
        guard app.canOpenURL(url) else {
            showExportSheet(for: url, completion: self.completionHandler)
            return
        }
        app.open(url, options: [:]) { success in 
            if success {
                self.completionHandler?(success)
            } else {
                self.showExportSheet(for: url, completion: self.completionHandler)
            }
        }
    }
    
    private func showExportSheet(for url: URL, completion: CompletionHandler?) {
        guard let parent = parent else {
            completion?(false)
            return
        }
        
        let exportSheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        popoverAnchor?.apply(to: exportSheet.popoverPresentationController)
        parent.present(exportSheet, animated: true) {
            completion?(true)
        }
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
