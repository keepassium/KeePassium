//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib


class BetaTransitionVC: UITableViewController {
    weak var newsItem: NewsItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0
        
        navigationItem.leftBarButtonItem?.action = #selector(dismissModal)
        navigationItem.leftBarButtonItem?.target = self
    }
    
    @objc private func dismissModal() {
        dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0.1
        } else {
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 2 {
            SupportEmailComposer.show(includeDiagnostics: false)
            return
        }
        guard indexPath.section == 1 else { return }
        
        switch indexPath.row {
        case 0: 
            fallthrough
        case 1: 
            didPressOpenAppStore()
        case 2: 
            didPressBetaPromo()
        case 3: 
            didPressStayOnBeta()
        default:
            assertionFailure()
        }
    }
    
    private func didPressOpenAppStore() {
        AppStoreHelper.openInAppStore()
    }
    
    private func didPressBetaPromo() {
        let alert = UIAlertController(
            title: "Free premium for a year",
            message: "The beta app will now write some license info, unlocking all the premium features until 1 Sep 2020. When you install the App Store version over of the beta one, it will inherit all the settings (including the premium status).\n\nImportant: if you uninstall the app, the license info will also be gone. To restore it, you would need to repeat the full path: install TestFlight beta → apply Beta promo → install the App Store release.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(
            title: "Continue",
            style: .default,
            handler: { [weak self] (action) in
                self?.applyBetaPromo()
            }
        ))
        alert.addAction(UIAlertAction(
            title: LString.actionCancel,
            style: .cancel,
            handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func didPressStayOnBeta() {
        let alert = UIAlertController(
            title: "Stay on Beta",
            message: "Do you want to hide the news about App Store release? \n(Reinstall the app to show hidden notification again.)",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(
            title: "Hide the news",
            style: .default,
            handler: { [weak self] (action) in
                guard let self = self else { return }
                self.newsItem?.isHidden = true
                self.dismissModal()
            }
        ))
        alert.addAction(UIAlertAction(
            title: "Keep the news",
            style: .cancel,
            handler: { [weak self] (action) in
                self?.dismissModal()
            }
        ))
        present(alert, animated: true, completion: nil)
    }
    
    private func applyBetaPromo() {
        let expiryDate = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone.autoupdatingCurrent,
            year: 2020, month: 9, day: 1,
            hour: 0, minute: 0, second: 0).date!

        do {
            try Keychain.shared.setPremiumExpiry(
                for: InAppProduct.yearlySubscription,
                to: expiryDate)
            
            let successAlert = UIAlertController(
                title: "Success",
                message: "License info written. Now, install the App Store release and enjoy.",
                preferredStyle: .alert)
            successAlert.addAction(UIAlertAction(
                title: "Open App Store",
                style: .default,
                handler: { (action) in
                    AppStoreHelper.openInAppStore()
                }
            ))
            self.present(successAlert, animated: true, completion: nil)
        } catch {
            let errorAlert = UIAlertController.make(
                title: LString.titleKeychainError,
                message: error.localizedDescription,
                cancelButtonTitle: LString.actionDismiss)
            present(errorAlert, animated: true, completion: nil)
        }
    }
}
