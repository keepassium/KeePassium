//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

protocol PremiumContainerNavigationDelegate: UIPageViewControllerDelegate {
    func didPressCancel(in premiumContainerVC: PremiumContainerVC)
}

class PremiumContainerVC: UIPageViewController {

    @IBOutlet var segmentedControl: UISegmentedControl!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    
    weak var navigationDelegate: PremiumContainerNavigationDelegate?
    weak var iapPage: UIViewController?
    weak var proPage: UIViewController?
    
    public static func create() -> PremiumContainerVC {
        let vc = PremiumContainerVC.instantiateFromStoryboard()
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
    }
    
    public func setPurchasing(_ isPurchasing: Bool) {
        cancelButton.isEnabled = !isPurchasing
    }
    
    @IBAction func didPressCancel(_ sender: Any) {
        navigationDelegate?.didPressCancel(in: self)
    }
    
    public func setPage(index: Int, animated: Bool) {
        switch index {
        case 0:
            setViewControllers([iapPage!], direction: .reverse, animated: animated, completion: nil)
        case 1:
            setViewControllers([proPage!], direction: .forward, animated: animated, completion: nil)
        default:
            assertionFailure()
        }
        segmentedControl.selectedSegmentIndex = index
    }
    
    @IBAction func didChangeSelectedPage(_ sender: UISegmentedControl) {
        let newPageIndex = sender.selectedSegmentIndex
        setPage(index: newPageIndex, animated: true)
    }
}

extension PremiumContainerVC: UIPageViewControllerDataSource {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController)
        -> UIViewController?
    {
        if viewController === proPage {
            return iapPage
        } else {
            return nil
        }
    }
    
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController)
        -> UIViewController?
    {
        if viewController === iapPage {
            return proPage
        } else {
            return nil
        }
    }
}

extension PremiumContainerVC: UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool)
    {
        guard finished && completed else { return }
        guard let selectedVC = pageViewController.viewControllers?.first else {
            assertionFailure();
            return
        }
        switch selectedVC {
        case iapPage:
            segmentedControl.selectedSegmentIndex = 0
        case proPage:
            segmentedControl.selectedSegmentIndex = 1
        default:
            assertionFailure()
        }
    }
}
