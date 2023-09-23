//  KeePassium Password Manager
//  Copyright © 2018-2023 Andrei Popleteev <info@keepassium.com>
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
    var faviconDownloadingProgressHost: ProgressViewHost { get }

    func downloadFavicon(
        for url: URL,
        in viewController: UIViewController,
        onSuccess: @escaping (UIImage) -> Void)
    func downloadFavicons(
        for entries: [Entry],
        in viewController: UIViewController,
        onSuccess: @escaping ([FaviconDownloader.DownloadedFavicon]) -> Void)
}

extension FaviconDownloading {
    func downloadFavicon(
        for url: URL,
        in viewController: UIViewController,
        onSuccess: @escaping (UIImage) -> Void
    ) {
        viewController.requestNetworkAccessPermission() { [weak self] in
            guard let self else { return }
            self.faviconDownloadingProgressHost.showProgressView(
                title: LString.statusDownloadingOneFavicon,
                allowCancelling: true,
                animated: true
            )
            let progressHandler = { [weak self] (progress: ProgressEx) -> Void in
                self?.faviconDownloadingProgressHost.updateProgressView(with: progress)
            }
            self.faviconDownloader.downloadFavicon(for: url, progressHandler: progressHandler) {
                [weak self] result in
                switch result {
                case let .success(image):
                    if let image {
                        onSuccess(image)
                    }
                case .failure(.canceled):
                    Diag.info("Favicon download canceled")
                case let .failure(error):
                    Diag.error("Favicon download failed [message: \(error.localizedDescription)]")
                }
                self?.faviconDownloadingProgressHost.hideProgressView(animated: true)
            }
        }
    }

    func downloadFavicons(
        for entries: [Entry],
        in viewController: UIViewController,
        onSuccess: @escaping ([FaviconDownloader.DownloadedFavicon]) -> Void
    ) {
        viewController.requestNetworkAccessPermission() { [weak self] in
            guard let self else { return }
            self.faviconDownloadingProgressHost.showProgressView(
                title: LString.statusDownloadingFavicons,
                allowCancelling: true,
                animated: true
            )

            let progressHandler = { [weak self] (progress: ProgressEx) -> Void in
                self?.faviconDownloadingProgressHost.updateProgressView(with: progress)
            }
            self.faviconDownloader.downloadFavicons(for: entries, progressHandler: progressHandler) {
                [weak self] result in
                switch result {
                case .success(let favicons):
                    onSuccess(favicons)
                case .failure(.canceled):
                    Diag.info("Bulk favicon download canceled")
                case let .failure(error):
                    Diag.error("Bulk favicon download failed [message: \(error.localizedDescription)]")
                }
                self?.faviconDownloadingProgressHost.hideProgressView(animated: true)
            }
        }
    }
}
