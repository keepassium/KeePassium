//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UniformTypeIdentifiers

protocol EntryViewerPagesDataSource: AnyObject {
    func getPageCount(for viewController: EntryViewerPagesVC) -> Int
    func getPage(index: Int, for viewController: EntryViewerPagesVC) -> UIViewController?
    func getPageIndex(of page: UIViewController, for viewController: EntryViewerPagesVC) -> Int?
}

protocol EntryViewerPagesVCDelegate: AnyObject {
    func canDropFiles(_ files: [UIDragItem]) -> Bool
    func didDropFiles(_ files: [TemporaryFileURL])
}

final class EntryViewerPagesVC: UIViewController, Refreshable {

    @IBOutlet private weak var pageSelector: UISegmentedControl!
    @IBOutlet private weak var containerView: UIView!

    public weak var dataSource: EntryViewerPagesDataSource?

    weak var delegate: EntryViewerPagesVCDelegate?

    private var isHistoryEntry = false
    private var canEditEntry = false
    private var entryIcon: UIImage?
    private var resolvedEntryTitle = ""
    private var isEntryExpired = false
    private var hasAttachments = false
    private var entryLastModificationTime = Date.distantPast

    private var titleView = DatabaseItemTitleView()

    private var pagesViewController: UIPageViewController! 
    private var currentPageIndex = 0 {
        didSet {
            if !isHistoryEntry {
                Settings.current.entryViewerPage = currentPageIndex
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = titleView

        pagesViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil)
        pagesViewController.delegate = self
        if !ProcessInfo.isRunningOnMac {
            pagesViewController.dataSource = self
        }

        updateSegments()

        addChild(pagesViewController)
        pagesViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pagesViewController.view.frame = containerView.bounds
        containerView.addSubview(pagesViewController.view)
        pagesViewController.didMove(toParent: self)

        registerForTraitChanges([
            UITraitUserInterfaceStyle.self,
            UITraitVerticalSizeClass.self,
            UITraitHorizontalSizeClass.self,
            UITraitPreferredContentSizeCategory.self
        ]) { (self: Self, _) in
            self.refresh()
        }
        view.addInteraction(UIDropInteraction(delegate: self))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        assert(dataSource != nil, "dataSource must be defined")
        refresh()
        if isHistoryEntry {
            switchTo(page: 0)
        } else {
            switchTo(page: Settings.current.entryViewerPage)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        navigationItem.rightBarButtonItem =
            pagesViewController.viewControllers?.first?.navigationItem.rightBarButtonItem
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if let titleView = navigationItem.titleView {
            navigationItem.titleView = nil
            navigationItem.titleView = titleView
        }
    }

    private func updateSegments() {
        pageSelector.setImage(
            UIImage.symbol(.key, accessibilityLabel: LString.titleEntryTabGeneral),
            forSegmentAt: 0)
        pageSelector.setImage(
            UIImage.symbol(
                hasAttachments ? .paperclipBadgeEllipsis : .paperclip,
                accessibilityLabel: LString.titleEntryTabFiles),
            forSegmentAt: 1)
        pageSelector.setImage(
            UIImage.symbol(.clock, accessibilityLabel: LString.titleEntryTabHistory),
            forSegmentAt: 2)
        pageSelector.setImage(
            UIImage.symbol(.ellipsis, accessibilityLabel: LString.titleEntryTabMore),
            forSegmentAt: 3)
    }

    public func setContents(from entry: Entry, hasAttachments: Bool, isHistoryEntry: Bool, canEditEntry: Bool) {
        entryIcon = UIImage.kpIcon(forEntry: entry)
        resolvedEntryTitle = entry.resolvedTitle
        isEntryExpired = entry.isExpired
        entryLastModificationTime = entry.lastModificationTime
        self.isHistoryEntry = isHistoryEntry
        self.canEditEntry = canEditEntry
        self.hasAttachments = hasAttachments
        refresh()
    }

    public func switchTo(page index: Int) {
        guard let dataSource = dataSource,
              let targetPageVC = dataSource.getPage(index: index, for: self)
        else {
            assertionFailure()
            return
        }

        let direction: UIPageViewController.NavigationDirection
        if index >= currentPageIndex {
            direction = .forward
        } else {
            direction = .reverse
        }

        let previousPageVC = pagesViewController.viewControllers?.first
        previousPageVC?.willMove(toParent: nil)
        targetPageVC.willMove(toParent: pagesViewController)
        pagesViewController.setViewControllers(
            [targetPageVC],
            direction: direction,
            animated: !ProcessInfo.isRunningOnMac,
            completion: { [weak self] _ in
                self?.changeCurrentPage(from: previousPageVC, to: targetPageVC, index: index)
            }
        )
    }

    @IBAction private func didChangePage(_ sender: Any) {
        switchTo(page: pageSelector.selectedSegmentIndex)
    }

    private func changeCurrentPage(
        from previousPageVC: UIViewController?,
        to targetPageVC: UIViewController,
        index: Int
    ) {
        previousPageVC?.didMove(toParent: nil)
        targetPageVC.didMove(toParent: pagesViewController)
        pageSelector.selectedSegmentIndex = index
        currentPageIndex = index
        navigationItem.rightBarButtonItem =
            targetPageVC.navigationItem.rightBarButtonItem

        let toolbarItems = targetPageVC.toolbarItems
        setToolbarItems(toolbarItems, animated: true)
    }

    func refresh() {
        guard isViewLoaded else { return }
        updateSegments()
        titleView.titleLabel.setText(resolvedEntryTitle, strikethrough: isEntryExpired)
        titleView.iconView.image = entryIcon
        if isHistoryEntry {
            if traitCollection.horizontalSizeClass == .compact {
                titleView.subtitleLabel.text = DateFormatter.localizedString(
                    from: entryLastModificationTime,
                    dateStyle: .medium,
                    timeStyle: .short)
            } else {
                titleView.subtitleLabel.text = DateFormatter.localizedString(
                    from: entryLastModificationTime,
                    dateStyle: .full,
                    timeStyle: .medium)
            }
            titleView.subtitleLabel.isHidden = false
        } else {
            titleView.subtitleLabel.isHidden = true
        }

        let currentPage = pagesViewController.viewControllers?.first
        (currentPage as? Refreshable)?.refresh()
    }
}

extension EntryViewerPagesVC: UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard finished && completed else { return }

        guard let dataSource = dataSource,
              let selectedVC = pageViewController.viewControllers?.first,
              let selectedIndex = dataSource.getPageIndex(of: selectedVC, for: self)
        else {
            return
        }
        changeCurrentPage(
            from: previousViewControllers.first,
            to: selectedVC,
            index: selectedIndex)
    }
}

extension EntryViewerPagesVC: UIPageViewControllerDataSource {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let index = dataSource?.getPageIndex(of: viewController, for: self) else {
            return nil
        }
        return dataSource?.getPage(index: index - 1, for: self)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let index = dataSource?.getPageIndex(of: viewController, for: self) else {
            return nil
        }

        return dataSource?.getPage(index: index + 1, for: self)
    }
}

extension EntryViewerPagesVC: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.hasItemsConforming(toTypeIdentifiers: [UTType.item.identifier])
    }

    func dropInteraction(
        _ interaction: UIDropInteraction,
        sessionDidUpdate session: UIDropSession
    ) -> UIDropProposal {
        guard session.localDragSession == nil else {
            return UIDropProposal(operation: .cancel)
        }

        if delegate?.canDropFiles(session.items) ?? false {
            return UIDropProposal(operation: .copy)
        } else {
            return UIDropProposal(operation: .forbidden)
        }
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        var files: [TemporaryFileURL] = []
        let dispatchGroup = DispatchGroup()

        Diag.debug("Processing \(session.items.count) dropped files")
        for dragItem in session.items {
            dispatchGroup.enter()

            dragItem.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) { url, error in
                if let error = error {
                    Diag.error("Failed to load dropped file [error: \(error.localizedDescription)]")
                    dispatchGroup.leave()
                    return
                }

                guard let url = url else {
                    Diag.error("Dropped file URL is invalid")
                    dispatchGroup.leave()
                    return
                }

                do {
                    let file = try TemporaryFileURL(fileName: url.lastPathComponent)
                    try FileManager.default.copyItem(at: url, to: file.url)
                    files.append(file)
                } catch {
                    Diag.error("Copying dropped file to temporary folder failed [error: \(error.localizedDescription)]")
                }

                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }
            guard !files.isEmpty else {
                Diag.debug("No dropped files could be loaded")
                return
            }

            if self.currentPageIndex != 1 {
                self.switchTo(page: 1)
            }

            Diag.debug("Trying to add \(files.count) dropped files to the entry")
            self.delegate?.didDropFiles(files)
        }
    }
}

extension LString {
    public static let titleEntryTabGeneral = NSLocalizedString(
        "[Entry/Tab/General/title]",
        value: "General",
        comment: "Title of entry viewer's tab with the entry's main information")
    public static let titleEntryTabFiles = NSLocalizedString(
        "[Entry/Tab/Files/title]",
        value: "Files",
        comment: "Title of entry viewer's tab with files attached to the entry")
    public static let titleEntryTabHistory = NSLocalizedString(
        "[Entry/Tab/History/title]",
        value: "History",
        comment: "Title of entry viewer's tab with previous revisions of the entry")
    public static let titleEntryTabMore = NSLocalizedString(
        "[Entry/Tab/More/title]",
        value: "More",
        comment: "Title of entry viewer's tab with advanced/secondary properties")
}
