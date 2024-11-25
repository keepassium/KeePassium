//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import UIKit

protocol FaviconDownloading: AnyObject {
    var faviconDownloader: FaviconDownloader { get }
    var faviconDownloadingProgressHost: ProgressViewHost? { get }

    func downloadFavicon(
        for url: URL,
        in viewController: UIViewController,
        completion: @escaping (UIImage?) -> Void)
    func downloadFavicons(
        for entries: [Entry],
        in viewController: UIViewController,
        completion: @escaping ([FaviconDownloader.DownloadedFavicon]?) -> Void)
}

extension FaviconDownloading {
    func downloadFavicon(
        for url: URL,
        in viewController: UIViewController,
        completion: @escaping (UIImage?) -> Void
    ) {
        guard ManagedAppConfig.shared.isFaviconDownloadAllowed else {
            viewController.showManagedFeatureBlockedNotification()
            Diag.error("Blocked by organization's policy, cancelling")
            completion(nil)
            return
        }
        viewController.requestingNetworkAccessPermission { [weak self] isNetworkAllowed in
            guard let self else { return }
            guard isNetworkAllowed else {
                completion(nil)
                return
            }
            self.faviconDownloadingProgressHost?.showProgressView(
                title: LString.statusDownloadingOneFavicon,
                allowCancelling: true,
                animated: true
            )
            let progressHandler: (ProgressEx) -> Void = { [weak self] progress in
                self?.faviconDownloadingProgressHost?.updateProgressView(with: progress)
            }
            self.faviconDownloader.downloadFavicon(for: url, progressHandler: progressHandler) { [weak self] result in
                switch result {
                case let .success(image):
                    completion(image)
                case .failure(.canceled):
                    Diag.info("Favicon download canceled")
                    completion(nil)
                case let .failure(error):
                    Diag.error("Favicon download failed [message: \(error.localizedDescription)]")
                    viewController.showNotification(error.localizedDescription)
                    completion(nil)
                }
                self?.faviconDownloadingProgressHost?.hideProgressView(animated: true)
            }
        }
    }

    func downloadFavicons(
        for entries: [Entry],
        in viewController: UIViewController,
        completion: @escaping ([FaviconDownloader.DownloadedFavicon]?) -> Void
    ) {
        guard ManagedAppConfig.shared.isFaviconDownloadAllowed else {
            viewController.showManagedFeatureBlockedNotification()
            Diag.error("Blocked by organization's policy, cancelling")
            completion(nil)
            return
        }

        viewController.requestingNetworkAccessPermission { [weak self] isNetworkAllowed in
            guard let self else { return }
            guard isNetworkAllowed else {
                completion(nil)
                return
            }

            let alert = UIAlertController.make(
                title: LString.actionDownloadFavicons,
                message: [LString.faviconDownloaderIntro, LString.faviconDownloaderWarning].joined(separator: "\n\n"),
                dismissButtonTitle: LString.actionCancel
            )
            alert.addAction(title: LString.actionContinue, style: .default, preferred: true) {
                [weak self] _ in
                guard let self else { return }
                self.faviconDownloadingProgressHost?.showProgressView(
                    title: LString.statusDownloadingFavicons,
                    allowCancelling: true,
                    animated: true
                )

                let progressHandler: (ProgressEx) -> Void = { [weak self] progress in
                    self?.faviconDownloadingProgressHost?.updateProgressView(with: progress)
                }
                self.faviconDownloader.downloadFavicons(for: entries, progressHandler: progressHandler) {
                    [weak self] result in
                    switch result {
                    case .success(let favicons):
                        completion(favicons)
                    case .failure(.canceled):
                        Diag.info("Bulk favicon download canceled")
                        completion(nil)
                    case let .failure(error):
                        Diag.error("Bulk favicon download failed [message: \(error.localizedDescription)]")
                        viewController.showNotification(error.localizedDescription)
                        completion(nil)
                    }
                    self?.faviconDownloadingProgressHost?.hideProgressView(animated: true)
                }
            }
            viewController.present(alert, animated: true)
        }
    }
}

extension LString {
    public static let faviconDownloaderIntro = NSLocalizedString(
        "[Database/DownloadFavicons/intro]",
        value: "KeePassium will contact websites associated with each entry.",
        comment: "Description of favicon downloader feature."
    )
    public static let faviconDownloaderWarning = NSLocalizedString(
        "[Database/DownloadFavicons/warning]",
        value: "Doing this on a public or monitored network can expose the list of websites where you have an account.",
        comment: "Description of favicon downloader feature. 'Doing this' refers to downloading favicons."
    )
}
