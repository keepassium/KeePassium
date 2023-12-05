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
            let progressHandler = { [weak self] (progress: ProgressEx) -> Void in
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
        viewController.requestingNetworkAccessPermission { [weak self] isNetworkAllowed in
            guard let self else { return }
            guard isNetworkAllowed else {
                completion(nil)
                return
            }
            self.faviconDownloadingProgressHost?.showProgressView(
                title: LString.statusDownloadingFavicons,
                allowCancelling: true,
                animated: true
            )

            let progressHandler = { [weak self] (progress: ProgressEx) -> Void in
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
    }
}
