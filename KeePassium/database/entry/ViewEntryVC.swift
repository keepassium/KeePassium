//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class ViewEntryVC: UIViewController, Refreshable {
    @IBOutlet weak var pageSelector: UISegmentedControl!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var titleImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    var pagesViewController: UIPageViewController! 
    
    private weak var entry: Entry?
    private var isHistoryMode = false
    private var entryChangeNotifications: EntryChangeNotifications!
    private var settingsNotifications: SettingsNotifications!
    
    private var progressOverlay: ProgressOverlay?
    private var pages = [UIViewController]()
    private var currentPageIndex = 0 {
        didSet {
            Settings.current.entryViewerPage = currentPageIndex
        }
    }

    static func make(with entry: Entry, historyMode: Bool = false) -> UIViewController {
        let viewEntryVC = ViewEntryVC.instantiateFromStoryboard()
        viewEntryVC.entry = entry
        viewEntryVC.isHistoryMode = historyMode
        viewEntryVC.refresh()
        entry.touch(.accessed)
        if !historyMode {
            let navVC = UINavigationController(rootViewController: viewEntryVC)
            return navVC
        } else {
            return viewEntryVC
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let entry = entry else { return }
        
        pages.append(ViewEntryFieldsVC.make(with: entry, historyMode: isHistoryMode))
        pages.append(ViewEntryFilesVC.make(
            with: entry,
            historyMode: isHistoryMode,
            progressViewHost: self))
        pages.append(ViewEntryHistoryVC.make(with: entry, historyMode: isHistoryMode))
        
        pagesViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil)
        pagesViewController.delegate = self
        pagesViewController.dataSource = self

        addChild(pagesViewController)
        pagesViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pagesViewController.view.frame = containerView.bounds
        containerView.addSubview(pagesViewController.view)
        pagesViewController.didMove(toParent: self)

        settingsNotifications = SettingsNotifications(observer: self)
        entryChangeNotifications = EntryChangeNotifications(observer: self)
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refresh()

        switchTo(page: Settings.current.entryViewerPage)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        entryChangeNotifications.startObserving()
        settingsNotifications.startObserving()

        navigationItem.rightBarButtonItem =
            pagesViewController.viewControllers?.first?.navigationItem.rightBarButtonItem
    }

    override func viewDidDisappear(_ animated: Bool) {
        settingsNotifications.stopObserving()
        entryChangeNotifications.stopObserving()
        super.viewDidDisappear(animated)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refresh()
    }
    
    private func switchTo(page index: Int) {
        let direction: UIPageViewController.NavigationDirection
        if index >= currentPageIndex {
            direction = .forward
        } else {
            direction = .reverse
        }

        let targetPageVC = pages[index]
        let previousPageVC = pagesViewController.viewControllers?.first
        previousPageVC?.willMove(toParent: nil)
        targetPageVC.willMove(toParent: pagesViewController)
        pagesViewController.setViewControllers(
            [targetPageVC],
            direction: direction,
            animated: true,
            completion: { [weak self] (finished) in
                guard let self = self else { return }
                previousPageVC?.didMove(toParent: nil)
                targetPageVC.didMove(toParent: self.pagesViewController)
                self.pageSelector.selectedSegmentIndex = index
                self.currentPageIndex = index
                self.navigationItem.rightBarButtonItem =
                    targetPageVC.navigationItem.rightBarButtonItem
            }
        )
        
    }
    
    @IBAction func didChangePage(_ sender: Any) {
        switchTo(page: pageSelector.selectedSegmentIndex)
    }

    func refresh() {
        guard let entry = entry,
              isViewLoaded else { return }
        titleLabel.setText(entry.resolvedTitle, strikethrough: entry.isExpired)
        titleImageView?.image = UIImage.kpIcon(forEntry: entry)
        if isHistoryMode {
            if traitCollection.horizontalSizeClass == .compact {
                subtitleLabel?.text = DateFormatter.localizedString(
                    from: entry.lastModificationTime,
                    dateStyle: .medium,
                    timeStyle: .short)
            } else {
                subtitleLabel?.text = DateFormatter.localizedString(
                    from: entry.lastModificationTime,
                    dateStyle: .full,
                    timeStyle: .medium)
            }
            subtitleLabel?.isHidden = false
        } else {
            subtitleLabel?.isHidden = true
        }
        
        let currentPage = pagesViewController.viewControllers?.first
        (currentPage as? Refreshable)?.refresh()
    }
}

extension ViewEntryVC: EntryChangeObserver {
    func entryDidChange(entry: Entry) {
        refresh()
    }
}

extension ViewEntryVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else {
            return
        }
        refresh()
    }
}


extension ViewEntryVC: ProgressViewHost {
    func showProgressView(title: String, allowCancelling: Bool) {
        if progressOverlay != nil {
            progressOverlay?.title = title
            progressOverlay?.isCancellable = allowCancelling
            return
        }
        
        navigationItem.hidesBackButton = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        let fullScreenView = splitViewController?.view 
        progressOverlay = ProgressOverlay.addTo(
            fullScreenView ?? self.view,
            title: title,
            animated: true)
        progressOverlay?.isCancellable = allowCancelling
    }
    
    func updateProgressView(with progress: ProgressEx) {
        progressOverlay?.update(with: progress)
    }
    
    func hideProgressView() {
        guard progressOverlay != nil else { return }
        navigationItem.hidesBackButton = false
        navigationItem.rightBarButtonItem?.isEnabled = true
        progressOverlay?.dismiss(animated: true) {
            [weak self] (finished) in
            guard let _self = self else { return }
            _self.progressOverlay?.removeFromSuperview()
            _self.progressOverlay = nil
        }
    }
}


extension ViewEntryVC: UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool)
    {
        if finished && completed {
            guard let selectedVC = pageViewController.viewControllers?.first,
                let selectedIndex = pages.firstIndex(of: selectedVC) else { return }
            previousViewControllers.first?.didMove(toParent: nil)
            selectedVC.didMove(toParent: pagesViewController)
            currentPageIndex = selectedIndex
            pageSelector.selectedSegmentIndex = selectedIndex
            navigationItem.rightBarButtonItem = selectedVC.navigationItem.rightBarButtonItem
        }
    }
}


extension ViewEntryVC: UIPageViewControllerDataSource {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
        ) -> UIViewController?
    {
        guard let vcIndex = pages.firstIndex(of: viewController) else { return nil }
        if vcIndex > 0 {
            return pages[vcIndex - 1]
        } else {
            return nil
        }
    }
    
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
        ) -> UIViewController?
    {
        guard let vcIndex = pages.firstIndex(of: viewController) else { return nil }
        if vcIndex < pages.count - 1 {
            return pages[vcIndex + 1]
        } else {
            return nil
        }
    }
}
