//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

public protocol NavigationRouterDismissAttemptDelegate: AnyObject {
    func didAttemptToDismiss(navigationRouter: NavigationRouter)
}

final public class RouterNavigationController: UINavigationController {
    fileprivate weak var router: NavigationRouter?

    public override var keyCommands: [UIKeyCommand]? {
        let escapeCommand = UIKeyCommand(
            input: UIKeyCommand.inputEscape,
            modifierFlags: [],
            action: #selector(didPressEscapeKey)
        )
        return [escapeCommand] + (super.keyCommands ?? [])
    }

    public init() {
        super.init(navigationBarClass: nil, toolbarClass: nil)
        setupBarAppearance()
    }

    public override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        setupBarAppearance()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupBarAppearance()
    }

    public override func awakeFromNib() {
        super.awakeFromNib()
        setupBarAppearance()
    }

    private func setupBarAppearance() {
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.backgroundColor = .systemBackground
        navigationBar.standardAppearance = navBarAppearance
        navigationBar.scrollEdgeAppearance = navBarAppearance

        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithDefaultBackground()
        toolbarAppearance.backgroundColor = .systemBackground
        toolbar.standardAppearance = toolbarAppearance
        toolbar.scrollEdgeAppearance = toolbarAppearance
    }

    @objc
    private func didPressEscapeKey() {
        if let router = router, router.canPopTopViewControllerFromKeyboard() {
            router.pop(animated: true)
        }
    }

    override public func viewDidDisappear(_ animated: Bool) {
        if isBeingDismissed {
            router?.popAll()
        }
        super.viewDidDisappear(animated)
    }
}

final public class NavigationRouter: NSObject {
    public typealias PopHandler = (() -> Void)
    public typealias CollapsedDetailDismissalHandler = ((UIViewController) -> Void)

    public private(set) var navigationController: RouterNavigationController
    private var popHandlers = [(ObjectIdentifier, PopHandler, String)]()
    private weak var oldDelegate: UINavigationControllerDelegate?

    public var collapsedDetailDismissalHandler: CollapsedDetailDismissalHandler?

    weak var dismissAttemptDelegate: NavigationRouterDismissAttemptDelegate?

    private var progressOverlay: ProgressOverlay?
    private var wasModalInPresentation = false
    private var wasNavigationBarUserInteractionEnabled = true
    private var oldNavigationBarAlpha = CGFloat(1.0)

    public var isModalInPresentation: Bool {
        get {
            return navigationController.isModalInPresentation
        }
        set {
            navigationController.isModalInPresentation = newValue
        }
    }

    public var isHorizontallyCompact: Bool {
        return navigationController.traitCollection.horizontalSizeClass == .compact
    }

    static func createModal(
        style: UIModalPresentationStyle,
        at popoverAnchor: PopoverAnchor? = nil
    ) -> NavigationRouter {
        let navVC = RouterNavigationController()
        let router = NavigationRouter(navVC)
        navVC.modalPresentationStyle = style
        navVC.presentationController?.delegate = router
        if let popover = navVC.popoverPresentationController {
            popoverAnchor?.apply(to: popover)
            popover.delegate = router
        }
        return router
    }

    init(_ navigationController: RouterNavigationController) {
        self.navigationController = navigationController
        oldDelegate = navigationController.delegate
        super.init()

        navigationController.router = self
        if oldDelegate !== self {
            navigationController.delegate = self
        }
    }

    deinit {
        popAll() 
        navigationController.delegate = oldDelegate
    }

    public func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        #if !AUTOFILL_EXT
        assert(navigationController.presentingViewController != nil)
        #endif
        navigationController.dismiss(animated: animated, completion: {
            // swiftlint:disable:next closure_parameter_position
            [self] in 
            self.popAll(completion: completion)
        })
    }

    public func dismissModals(animated: Bool, completion: (() -> Void)?) {
        guard let presentedVC = navigationController.presentedViewController else {
            completion?()
            return
        }
        presentedVC.dismiss(animated: animated, completion: completion)
    }

    public func present(_ router: NavigationRouter, animated: Bool, completion: (() -> Void)?) {
        navigationController.present(router, animated: animated, completion: completion)
    }

    public func present(
        _ viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        navigationController.present(viewController, animated: animated, completion: completion)
    }

    public func prepareCustomTransition(
        duration: CFTimeInterval = 0.5,
        type: CATransitionType = .fade,
        timingFunction: CAMediaTimingFunctionName = .linear
    ) {
        let transition = CATransition()
        transition.duration = duration
        transition.timingFunction = CAMediaTimingFunction(name: timingFunction)
        transition.type = type
        transition.isRemovedOnCompletion = true
        navigationController.view.layer.add(transition, forKey: kCATransition)
    }

    public func push(
        _ viewController: UIViewController,
        animated: Bool,
        replaceTopViewController: Bool = false,
        onPop popHandler: PopHandler?
    ) {
        let nonNilPopHandler = popHandler ?? {
            /* an empty handler, required to maintain a continuous handler stack */
        }
        let id = ObjectIdentifier(viewController)
        popHandlers.append((id, nonNilPopHandler, viewController.debugDescription))

        if replaceTopViewController,
           let topVC = navigationController.topViewController
        {
            var viewControllers = navigationController.viewControllers
            viewControllers[viewControllers.count - 1] = viewController
            navigationController.setViewControllers(viewControllers, animated: animated)
            firePopHandler(for: topVC)
        } else {
            navigationController.pushViewController(viewController, animated: animated)
        }
    }

    public func pop(animated: Bool, completion: (() -> Void)? = nil) {
        let isLastVC = (navigationController.viewControllers.count == 1)
        guard isLastVC else {
            let topVC = navigationController.topViewController!
            navigationController.popViewController(animated: animated, completion: {
                self.firePopHandler(for: topVC)
                completion?()
            })
            return
        }

        navigationController.dismiss(animated: animated, completion: { [self, completion] in
            self.firePopHandler(for: navigationController.topViewController!) 
            if let collapsedSplitNavVC = navigationController.parent as? UINavigationController,
               isCollapsedSplitVC(collapsedSplitNavVC)
            {
                collapsedSplitNavVC.popViewController(animated: animated, completion: completion)
            } else {
                completion?()
            }
        })
    }

    public func popTo(viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
        guard let upperVC = navigationController.topViewController else {
            assertionFailure("Tried to pop a view controller, but there are none in the stack.")
            completion?()
            return
        }
        let lowerVC = viewController
        navigationController.popToViewController(viewController, animated: animated, completion: {
            self.firePopHandlersBetween(upperVC, lowerVC, ignoreUpper: false)
            completion?()
        })
    }

    public func pop(
        viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        let viewControllers = navigationController.viewControllers
        guard let index = viewControllers.firstIndex(of: viewController) else {
            return
        }

        if index == 0 {
            dismiss(animated: animated, completion: completion)
        } else {
            let previousVC = viewControllers[index - 1]
            popTo(viewController: previousVC, animated: animated, completion: completion)
        }
    }

    public func popToRoot(animated: Bool) {
        navigationController.popToRootViewController(animated: animated)
    }

    public func popAll(completion: (() -> Void)? = nil) {
        fireAllPopHandlers()
        navigationController.setViewControllers([UIViewController()], animated: false)
        completion?()
    }

    fileprivate func canPopTopViewControllerFromKeyboard() -> Bool {
        return navigationController.topViewController?.canDismissFromKeyboard ?? false
    }

    private func fireAllPopHandlers() {
        while let (_, popHandler, _) = popHandlers.popLast() {
            popHandler()
        }
    }

    private func firePopHandler(for viewController: UIViewController) {
        let id = ObjectIdentifier(viewController)
        guard let index = popHandlers.lastIndex(where: { $0.0 == id }) else {
            return
        }
        let popHandler = popHandlers[index].1
        popHandler()
        popHandlers.remove(at: index)
    }

    private func firePopHandlersBetween(
        _ upper: UIViewController,
        _ lower: UIViewController,
        ignoreUpper: Bool
    ) {
        let upperID = ObjectIdentifier(upper)
        let lowerID = ObjectIdentifier(lower)
        guard (popHandlers.last?.0 == upperID) || ignoreUpper else {
            return
        }
        guard let index = popHandlers.lastIndex(where: { $0.0 == lowerID }) else {
            assertionFailure()
            return
        }
        let handlersToPop = popHandlers.suffix(from: index + 1).reversed()
        handlersToPop.forEach { _id, _popHandler, _description in
            _popHandler()
        }
        popHandlers.removeLast(handlersToPop.count)
    }
}

extension NavigationRouter: UINavigationControllerDelegate {
    private func isCollapsedSplitVC(_ viewController: UINavigationController) -> Bool {
        let parentVC = viewController.parent
        guard let splitVC = parentVC as? UISplitViewController else {
            return false
        }
        let isCollapsed = splitVC.isCollapsed
        return isCollapsed
    }

    public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        guard let fromVC = navigationController.transitionCoordinator?.viewController(forKey: .from),
              !navigationController.viewControllers.contains(fromVC),
              !(fromVC is UISplitViewController) 
        else {
            oldDelegate?.navigationController?(
                navigationController,
                didShow: viewController,
                animated: animated)
            return
        }

        let didDismissCollapsedDetailView =
            isCollapsedSplitVC(navigationController) && (fromVC is UINavigationController)
        if didDismissCollapsedDetailView {
            collapsedDetailDismissalHandler?(fromVC)
        }

        firePopHandlersBetween(fromVC, viewController, ignoreUpper: didDismissCollapsedDetailView)
        oldDelegate?.navigationController?(
            navigationController,
            didShow: viewController,
            animated: animated)
    }

    public func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        let shouldShowToolbar = viewController.toolbarItems != nil
        navigationController.setToolbarHidden(!shouldShowToolbar, animated: animated)
    }
}

extension NavigationRouter: UIPopoverPresentationControllerDelegate {
    public func presentationController(
        _ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle
    ) -> UIViewController? {
        return nil // "keep existing"
    }
}

extension NavigationRouter: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidAttemptToDismiss(
        _ presentationController: UIPresentationController
    ) {
        dismissAttemptDelegate?.didAttemptToDismiss(navigationRouter: self)
    }

    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        popAll()
    }
}


extension NavigationRouter: ProgressViewHost {
    public func showProgressView(title: String, allowCancelling: Bool) {
        showProgressView(title: title, allowCancelling: allowCancelling, animated: true)
    }
    public func showProgressView(title: String, allowCancelling: Bool, animated: Bool) {
        if progressOverlay != nil {
            progressOverlay?.title = title
            progressOverlay?.isCancellable = allowCancelling
            return
        }
        progressOverlay = ProgressOverlay.addTo(
            navigationController.view,
            title: title,
            animated: animated)
        progressOverlay?.isCancellable = allowCancelling

        wasModalInPresentation = navigationController.isModalInPresentation
        navigationController.isModalInPresentation = true

        let navigationBar = navigationController.navigationBar
        oldNavigationBarAlpha = navigationBar.alpha
        wasNavigationBarUserInteractionEnabled = navigationBar.isUserInteractionEnabled
        navigationBar.isUserInteractionEnabled = false
        if animated {
            UIView.animate(withDuration: 0.3) {
                navigationBar.alpha = 0.1
            }
        } else {
            navigationBar.alpha = 0.1
        }
    }

    public func updateProgressView(with progress: ProgressEx) {
        progressOverlay?.update(with: progress)
    }

    public func hideProgressView() {
        hideProgressView(animated: true)
    }

    public func hideProgressView(animated: Bool) {
        guard progressOverlay != nil else { return }
        let navigationBar = navigationController.navigationBar
        if animated {
            UIView.animate(withDuration: 0.3) { [oldNavigationBarAlpha] in
                navigationBar.alpha = oldNavigationBarAlpha
            }
        } else {
            navigationBar.alpha = oldNavigationBarAlpha
        }
        navigationBar.isUserInteractionEnabled = wasNavigationBarUserInteractionEnabled

        navigationController.isModalInPresentation = wasModalInPresentation

        progressOverlay?.dismiss(animated: animated) { [weak self] _ in
            guard let self = self else { return }
            self.progressOverlay?.removeFromSuperview()
            self.progressOverlay = nil
        }
    }
}

extension UIViewController {
    func present(_ router: NavigationRouter, animated: Bool, completion: (() -> Void)?) {
        present(router.navigationController, animated: animated, completion: completion)
    }
}

fileprivate extension UINavigationController {
    func popViewController(animated: Bool, completion: (() -> Void)?) {
        popViewController(animated: animated)
        if animated, let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in
                completion?()
            }
        } else {
            completion?()
        }
    }

    func popToViewController(
        _ viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        popToViewController(viewController, animated: animated)
        if animated, let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in
                completion?()
            }
        } else {
            completion?()
        }
    }
}
