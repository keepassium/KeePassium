//
//  Toast.swift
//  Toast-Swift
//
//  Copyright (c) 2015-2019 Charles Scalesse.
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  Modified by Andrei Popleteev for KeePassium in 2021, file license remains the same.

import UIKit
import ObjectiveC

/**
 Toast is a Swift extension that adds toast notifications to the `UIView` object class.
 It is intended to be simple, lightweight, and easy to use. Most toast notifications 
 can be triggered with a single line of code.
 
 The `makeToast` methods create a new view and then display it as toast.
 
 The `showToast` methods display any view as toast.
 
 */
public extension UIView {
    
    /**
     Keys used for associated objects.
     */
    private struct ToastKeys {
        static var timer        = "com.toast-swift.timer"
        static var duration     = "com.toast-swift.duration"
        static var point        = "com.toast-swift.point"
        static var action       = "com.toast-swift.action"
        static var completion   = "com.toast-swift.completion"
        static var activeToasts = "com.toast-swift.activeToasts"
        static var activityView = "com.toast-swift.activityView"
        static var queue        = "com.toast-swift.queue"
    }
    
    /**
     Swift closures can't be directly associated with objects via the
     Objective-C runtime, so the (ugly) solution is to wrap them in a
     class that can be used with associated objects.
     */
    private class ToastCompletionWrapper {
        let completion: ((Bool) -> Void)?
        
        init(_ completion: ((Bool) -> Void)?) {
            self.completion = completion
        }
    }
    
    private class ToastActionHandlerWrapper {
        let handler: (() -> Void)?
        
        init(_ handler: (() -> Void)?) {
            self.handler = handler
        }
    }

    private enum ToastError: Error {
        case missingParameters
    }
    
    private var activeToasts: NSMutableArray {
        get {
            if let activeToasts = objc_getAssociatedObject(self, &ToastKeys.activeToasts) as? NSMutableArray {
                return activeToasts
            } else {
                let activeToasts = NSMutableArray()
                objc_setAssociatedObject(
                    self,
                    &ToastKeys.activeToasts,
                    activeToasts,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                return activeToasts
            }
        }
    }
    
    private var queue: NSMutableArray {
        get {
            if let queue = objc_getAssociatedObject(self, &ToastKeys.queue) as? NSMutableArray {
                return queue
            } else {
                let queue = NSMutableArray()
                objc_setAssociatedObject(
                    self,
                    &ToastKeys.queue,
                    queue,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                return queue
            }
        }
    }
    
    
    /**
     Creates and presents a new toast view.
     
     @param message The message to be displayed
     @param duration The toast duration
     @param position The toast's position
     @param title The title
     @param image The image
     @param style The style. The shared style will be used when nil
     @param completion The completion closure, executed after the toast view disappears.
            didTap will be `true` if the toast view was dismissed from a tap.
     */
    func makeToast(
        _ message: String,
        duration: TimeInterval = ToastManager.shared.duration,
        position: ToastPosition = ToastManager.shared.position,
        title: String? = nil,
        image: UIImage? = nil,
        action: ToastAction? = nil,
        style: ToastStyle = ToastManager.shared.style,
        completion: ((_ didTap: Bool) -> Void)? = nil
    ) {
        let toast = toastViewForMessage(message, title: title, image: image, action: action, style: style)
        showToast(toast, duration: duration, position: position, action: action, completion: completion)
    }
    
    /**
     Creates a new toast view and presents it at a given center point.
     
     @param message The message to be displayed
     @param duration The toast duration
     @param point The toast's center point
     @param title The title
     @param image The image
     @param action The action associated with toast's button
     @param style The style. The shared style will be used when nil
     @param completion The completion closure, executed after the toast view disappears.
            didTap will be `true` if the toast view was dismissed from a tap.
     */
    func makeToast(
        _ message: String,
        duration: TimeInterval = ToastManager.shared.duration,
        point: CGPoint,
        title: String?,
        image: UIImage?,
        action: ToastAction?,
        style: ToastStyle = ToastManager.shared.style,
        completion: ((_ didTap: Bool) -> Void)?
    ) {
        let toast = toastViewForMessage(message, title: title, image: image, action: action, style: style)
        showToast(toast, duration: duration, point: point, action: action, completion: completion)
    }
    
    
    /**
     Displays any view as toast at a provided position and duration. The completion closure
     executes when the toast view completes. `didTap` will be `true` if the toast view was
     dismissed from a tap.
     
     @param toast The view to be displayed as toast
     @param duration The notification duration
     @param position The toast's position
     @param completion The completion block, executed after the toast view disappears.
     didTap will be `true` if the toast view was dismissed from a tap.
     */
    func showToast(
        _ toast: UIView,
        duration: TimeInterval = ToastManager.shared.duration,
        position: ToastPosition = ToastManager.shared.position,
        action: ToastAction?,
        completion: ((_ didTap: Bool) -> Void)? = nil
    ) {
        let point = position.centerPoint(forToast: toast, inSuperview: self)
        showToast(toast, duration: duration, point: point, action: action, completion: completion)
    }
    
    /**
     Displays any view as toast at a provided center point and duration. The completion closure
     executes when the toast view completes. `didTap` will be `true` if the toast view was
     dismissed from a tap.
     
     @param toast The view to be displayed as toast
     @param duration The notification duration
     @param point The toast's center point
     @param completion The completion block, executed after the toast view disappears.
     didTap will be `true` if the toast view was dismissed from a tap.
     */
    func showToast(
        _ toast: UIView,
        duration: TimeInterval = ToastManager.shared.duration,
        point: CGPoint,
        action: ToastAction? = nil,
        completion: ((_ didTap: Bool) -> Void)? = nil
    ) {
        objc_setAssociatedObject(
            toast,
            &ToastKeys.action,
            ToastActionHandlerWrapper(action?.handler),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(
            toast,
            &ToastKeys.completion,
            ToastCompletionWrapper(completion),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        if ToastManager.shared.isQueueEnabled, activeToasts.count > 0 {
            objc_setAssociatedObject(
                toast,
                &ToastKeys.duration,
                NSNumber(value: duration),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(
                toast,
                &ToastKeys.point,
                NSValue(cgPoint: point),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            queue.add(toast)
        } else {
            showToast(toast, duration: duration, point: point)
        }
    }
    
    
    /**
     Hides the active toast. If there are multiple toasts active in a view, this method
     hides the oldest toast (the first of the toasts to have been presented).
     
     @see `hideAllToasts()` to remove all active toasts from a view.
     
     @warning This method has no effect on activity toasts. Use `hideToastActivity` to
     hide activity toasts.
     
    */
    func hideToast() {
        guard let activeToast = activeToasts.firstObject as? UIView else { return }
        hideToast(activeToast)
    }
    
    /**
     Hides an active toast.
     
     @param toast The active toast view to dismiss. Any toast that is currently being displayed
     on the screen is considered active.
     
     @warning this does not clear a toast view that is currently waiting in the queue.
     */
    func hideToast(_ toast: UIView) {
        guard activeToasts.contains(toast) else { return }
        hideToast(toast, fromTap: false)
    }
    
    /**
     Hides all toast views.
     
     @param includeActivity If `true`, toast activity will also be hidden. Default is `false`.
     @param clearQueue If `true`, removes all toast views from the queue. Default is `true`.
    */
    func hideAllToasts(includeActivity: Bool = false, clearQueue: Bool = true) {
        if clearQueue {
            clearToastQueue()
        }
        
        activeToasts
            .compactMap { $0 as? UIView }
            .forEach { hideToast($0) }
        
        if includeActivity {
            hideToastActivity()
        }
    }
    
    /**
     Removes all toast views from the queue. This has no effect on toast views that are
     active. Use `hideAllToasts(clearQueue:)` to hide the active toasts views and clear
     the queue.
     */
    func clearToastQueue() {
        queue.removeAllObjects()
    }
    
    
    /**
     Creates and displays a new toast activity indicator view at a specified position.
    
     @warning Only one toast activity indicator view can be presented per superview. Subsequent
     calls to `makeToastActivity(position:)` will be ignored until `hideToastActivity()` is called.
    
     @warning `makeToastActivity(position:)` works independently of the `showToast` methods. Toast
     activity views can be presented and dismissed while toast views are being displayed.
     `makeToastActivity(position:)` has no effect on the queueing behavior of the `showToast` methods.
    
     @param position The toast's position
     */
    func makeToastActivity(_ position: ToastPosition) {
        guard objc_getAssociatedObject(self, &ToastKeys.activityView) as? UIView == nil else {
            return
        }
        
        let toast = createToastActivityView()
        let point = position.centerPoint(forToast: toast, inSuperview: self)
        makeToastActivity(toast, point: point)
    }
    
    /**
     Creates and displays a new toast activity indicator view at a specified position.
     
     @warning Only one toast activity indicator view can be presented per superview. Subsequent
     calls to `makeToastActivity(position:)` will be ignored until `hideToastActivity()` is called.
     
     @warning `makeToastActivity(position:)` works independently of the `showToast` methods. Toast
     activity views can be presented and dismissed while toast views are being displayed.
     `makeToastActivity(position:)` has no effect on the queueing behavior of the `showToast` methods.
     
     @param point The toast's center point
     */
    func makeToastActivity(_ point: CGPoint) {
        guard objc_getAssociatedObject(self, &ToastKeys.activityView) as? UIView == nil else {
            return
        }
        
        let toast = createToastActivityView()
        makeToastActivity(toast, point: point)
    }
    
    /**
     Dismisses the active toast activity indicator view.
     */
    func hideToastActivity() {
        guard let toast = objc_getAssociatedObject(self, &ToastKeys.activityView) as? UIView else {
            return
        }
        UIView.animate(
            withDuration: ToastManager.shared.style.fadeDuration,
            delay: 0.0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                toast.alpha = 0.0
            },
            completion: { _ in
                toast.removeFromSuperview()
                objc_setAssociatedObject(
                    self,
                    &ToastKeys.activityView,
                    nil,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        )
    }
    
    
    private func makeToastActivity(_ toast: UIView, point: CGPoint) {
        toast.alpha = 0.0
        toast.center = point
        
        objc_setAssociatedObject(
            self,
            &ToastKeys.activityView,
            toast,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        self.addSubview(toast)
        
        UIView.animate(
            withDuration: ToastManager.shared.style.fadeDuration,
            delay: 0.0,
            options: .curveEaseOut,
            animations: {
                toast.alpha = 1.0
            }
        )
    }
    
    private func createToastActivityView() -> UIView {
        let style = ToastManager.shared.style
        
        let activityView = UIView(
            frame: CGRect(
                x: 0.0,
                y: 0.0,
                width: style.activitySize.width,
                height: style.activitySize.height
            )
        )
        activityView.backgroundColor = style.activityBackgroundColor
        activityView.autoresizingMask =
            [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        activityView.layer.cornerRadius = style.cornerRadius
        
        if style.displayShadow {
            activityView.layer.shadowColor = style.shadowColor.cgColor
            activityView.layer.shadowOpacity = style.shadowOpacity
            activityView.layer.shadowRadius = style.shadowRadius
            activityView.layer.shadowOffset = style.shadowOffset
        }
        
        let activityIndicatorView = UIActivityIndicatorView(style: .large)
        activityIndicatorView.center = CGPoint(
            x: activityView.bounds.size.width / 2.0,
            y: activityView.bounds.size.height / 2.0
        )
        activityView.addSubview(activityIndicatorView)
        activityIndicatorView.color = style.activityIndicatorColor
        activityIndicatorView.startAnimating()
        
        return activityView
    }
    
    
    private func showToast(_ toast: UIView, duration: TimeInterval, point: CGPoint) {
        toast.center = point
        toast.alpha = 0.0
        
        if ToastManager.shared.isTapToDismissEnabled {
            let recognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(UIView.handleToastTapped(_:))
            )
            toast.addGestureRecognizer(recognizer)
            toast.isUserInteractionEnabled = true
            toast.isExclusiveTouch = true
        }
        
        activeToasts.add(toast)
        self.addSubview(toast)

        var adjustedDuration = duration
        if UIAccessibility.isVoiceOverRunning {
            adjustedDuration = max(duration, 15)
        }
        
        UIView.animate(
            withDuration: ToastManager.shared.style.fadeDuration,
            delay: 0.0,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                toast.alpha = 1.0
            },
            completion: { _ in
                UIAccessibility.post(notification: .screenChanged, argument: toast)
                let timer = Timer(
                    timeInterval: adjustedDuration,
                    target: self,
                    selector: #selector(UIView.toastTimerDidFinish(_:)),
                    userInfo: toast,
                    repeats: false)
                RunLoop.main.add(timer, forMode: .common)
                objc_setAssociatedObject(toast, &ToastKeys.timer, timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        )
    }
    
    private func hideToast(_ toast: UIView, fromTap: Bool) {
        if let timer = objc_getAssociatedObject(toast, &ToastKeys.timer) as? Timer {
            timer.invalidate()
        }
        
        UIView.animate(
            withDuration: ToastManager.shared.style.fadeDuration,
            delay: 0.0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                toast.alpha = 0.0
            },
            completion: { _ in
                toast.removeFromSuperview()
                self.activeToasts.remove(toast)
                UIAccessibility.post(notification: .screenChanged, argument: toast.superview)
                
                if let completionWrapper = objc_getAssociatedObject(toast, &ToastKeys.completion)
                    as? ToastCompletionWrapper
                {
                    completionWrapper.completion?(fromTap)
                }
                
                if let nextToast = self.queue.firstObject as? UIView,
                   let duration = objc_getAssociatedObject(nextToast, &ToastKeys.duration) as? NSNumber,
                   let point = objc_getAssociatedObject(nextToast, &ToastKeys.point) as? NSValue
                {
                    self.queue.removeObject(at: 0)
                    self.showToast(nextToast, duration: duration.doubleValue, point: point.cgPointValue)
                }
            }
        )
    }
    

    @objc
    private func handleToastActionTapped(_ button: UIButton) {
        guard let toast = button.superview else { return }
        if let actionHandlerWrapper = objc_getAssociatedObject(toast, &ToastKeys.action)
            as? ToastActionHandlerWrapper
        {
            actionHandlerWrapper.handler?()
        }
    }
    
    @objc
    private func handleToastTapped(_ recognizer: UITapGestureRecognizer) {
        guard let toast = recognizer.view else { return }
        hideToast(toast, fromTap: true)
    }
    
    @objc
    private func toastTimerDidFinish(_ timer: Timer) {
        guard let toast = timer.userInfo as? UIView else { return }
        hideToast(toast)
    }
    
    
    /**
     Creates a new toast view with any combination of message, title, and image.
     The look and feel is configured via the style. Unlike the `makeToast` methods,
     this method does not present the toast view automatically. One of the `showToast`
     methods must be used to present the resulting view.
    
     @warning if message, title, and image are all nil, this method will throw
     `ToastError.missingParameters`
    
     @param message The message to be displayed
     @param title The title
     @param image The image
     @param style The style. The shared style will be used when nil
     @return The newly created toast view
    */
    func toastViewForMessage(
        _ message: String,
        title: String?,
        image: UIImage?,
        action: ToastAction? = nil,
        style: ToastStyle
    ) -> UIView {
        var messageLabel: UILabel
        var titleLabel: UILabel?
        var imageView: UIImageView?
        var actionButton: UIButton?
        
        let wrapperView = UIView()
        wrapperView.backgroundColor = style.backgroundColor
        wrapperView.autoresizingMask =
            [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        wrapperView.layer.cornerRadius = style.cornerRadius
        
        if style.displayShadow {
            wrapperView.layer.shadowColor = style.shadowColor.cgColor
            wrapperView.layer.shadowOpacity = style.shadowOpacity
            wrapperView.layer.shadowRadius = style.shadowRadius
            wrapperView.layer.shadowOffset = style.shadowOffset
            wrapperView.layer.borderColor = style.shadowColor.cgColor
            wrapperView.layer.borderWidth = 1.0
        }
        
        if let image = image {
            imageView = UIImageView(image: image)
            imageView?.tintColor = style.titleColor
            imageView?.contentMode = .scaleAspectFit
            imageView?.frame = CGRect(
                x: style.horizontalPadding,
                y: style.verticalPadding,
                width: style.imageSize.width,
                height: style.imageSize.height
            )
        }
        
        var imageRect = CGRect.zero
        
        if let imageView = imageView {
            imageRect.origin.x = style.horizontalPadding
            imageRect.origin.y = style.verticalPadding
            imageRect.size.width = imageView.bounds.width
            imageRect.size.height = imageView.bounds.height
        }

        if let title = title {
            titleLabel = UILabel()
            titleLabel?.numberOfLines = style.titleNumberOfLines
            titleLabel?.font = style.titleFont
            titleLabel?.textAlignment = style.titleAlignment
            titleLabel?.lineBreakMode = .byTruncatingTail
            titleLabel?.textColor = style.titleColor
            titleLabel?.backgroundColor = UIColor.clear
            titleLabel?.text = title
            
            let maxTitleSize = CGSize(
                width: (self.bounds.width * style.maxWidthPercentage) - imageRect.size.width,
                height: self.bounds.height * style.maxHeightPercentage)
            let titleSize = titleLabel?.sizeThatFits(maxTitleSize)
            if let titleSize = titleSize {
                titleLabel?.frame = CGRect(origin: CGPoint.zero, size: titleSize)
            }
        }
        
        messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.numberOfLines = style.messageNumberOfLines
        messageLabel.font = style.messageFont
        messageLabel.textAlignment = style.messageAlignment
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.textColor = style.messageColor
        messageLabel.backgroundColor = UIColor.clear
        
        let maxMessageSize = CGSize(
            width: (self.bounds.width * style.maxWidthPercentage) - imageRect.size.width,
            height: self.bounds.height * style.maxHeightPercentage
        )
        let messageSize = messageLabel.sizeThatFits(maxMessageSize)
        let actualWidth = min(messageSize.width, maxMessageSize.width)
        let actualHeight = min(messageSize.height, maxMessageSize.height)
        messageLabel.frame = CGRect(x: 0.0, y: 0.0, width: actualWidth, height: actualHeight)
  
        if let toastAction = action {
            let button = UIButton()
            button.setTitleColor(style.buttonColor, for: .normal)
            button.setTitle(toastAction.title, for: .normal)
            button.contentHorizontalAlignment = .trailing
            let titleInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
            button.titleEdgeInsets = titleInsets
            button.titleLabel?.font = style.buttonFont
            button.titleLabel?.numberOfLines = style.buttonNumberOfLines
            button.titleLabel?.lineBreakMode = .byWordWrapping
            if toastAction.isLink {
                button.accessibilityTraits.remove(.button)
                button.accessibilityTraits.insert(.link)
            }

            var buttonImageWidth = CGFloat.zero
            if let buttonImage = toastAction.icon {
                button.setImage(buttonImage, for: .normal)
                button.imageEdgeInsets.right = 4
                button.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
                button.titleLabel?.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
                button.imageView?.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
                buttonImageWidth =
                    buttonImage.size.width +
                    button.imageEdgeInsets.left +
                    button.imageEdgeInsets.right
            }
            
            let maxButtonLabelSize = CGSize(
                width: self.bounds.width * style.maxWidthPercentage -
                    imageRect.width - titleInsets.left - titleInsets.right - buttonImageWidth,
                height: self.bounds.height * style.maxHeightPercentage -
                    titleInsets.top - titleInsets.bottom
            )
            if let buttonSize = button.titleLabel?.sizeThatFits(maxButtonLabelSize) {
                button.frame = CGRect(
                    x: 0.0,
                    y: 0.0,
                    width: buttonSize.width + titleInsets.left + titleInsets.right + buttonImageWidth,
                    height: buttonSize.height + titleInsets.top + titleInsets.bottom
                )
            }
            button.addTarget(
                wrapperView,
                action: #selector(handleToastActionTapped(_:)),
                for: .touchUpInside
            )
            actionButton = button
        }
        
        var titleRect = CGRect.zero
        titleRect.origin.x = imageRect.origin.x + imageRect.width + style.horizontalPadding
        titleRect.origin.y = style.verticalPadding
        if let titleLabel = titleLabel {
            titleRect.size.width = titleLabel.bounds.width
            titleRect.size.height = titleLabel.bounds.height
        }
        
        var messageRect = CGRect.zero
        messageRect.origin.x = imageRect.origin.x + imageRect.width + style.horizontalPadding
        messageRect.origin.y = titleRect.origin.y + titleRect.height
        if titleLabel != nil {
            messageRect.origin.y += style.messageFont.xHeight
        }
        messageRect.size.width = messageLabel.bounds.width
        messageRect.size.height = messageLabel.bounds.height
        
        var buttonRect = CGRect.zero
        if let button = actionButton {
            buttonRect.origin.x = imageRect.origin.x + imageRect.width + style.horizontalPadding
            buttonRect.origin.y = messageRect.origin.y + messageRect.height
            buttonRect.size.width = button.bounds.width
            buttonRect.size.height = button.bounds.height
        }
        
        let longerWidth = max(
            titleRect.width,
            messageRect.width,
            buttonRect.width
        )
        let longerX = max(
            titleRect.origin.x,
            messageRect.origin.x,
            buttonRect.origin.x
        )
        let wrapperWidth = max(
            imageRect.width + (style.horizontalPadding * 2.0),
            longerX + longerWidth + style.horizontalPadding
        )
        
        var contentHeight = messageRect.origin.y + messageRect.height + style.verticalPadding
        if actionButton != nil {
            contentHeight = buttonRect.origin.y + buttonRect.height
        }
        let wrapperHeight = max(
            contentHeight,
            imageRect.size.height + (style.verticalPadding * 2.0)
        )
        
        wrapperView.frame = CGRect(x: 0.0, y: 0.0, width: wrapperWidth, height: wrapperHeight)
        
        if let titleLabel = titleLabel {
            titleRect.size.width = longerWidth
            titleLabel.frame = titleRect
            wrapperView.addSubview(titleLabel)
        }
        
        if titleLabel == nil && actionButton == nil {
            messageRect.origin.y = (wrapperHeight - messageRect.height) / 2
        }
        messageRect.size.width = longerWidth
        messageLabel.frame = messageRect
        wrapperView.addSubview(messageLabel)
        
        if let button = actionButton {
            buttonRect.origin.x = wrapperWidth - style.horizontalPadding - buttonRect.width
            button.frame = buttonRect
            wrapperView.addSubview(button)
        }
        
        if let imageView = imageView {
            imageRect.origin.y = (wrapperHeight - imageRect.height) / 2
            imageView.frame = imageRect
            wrapperView.addSubview(imageView)
        }
        
        wrapperView.accessibilityElements = [titleLabel, messageLabel, actionButton].compactMap { $0 }
        wrapperView.isAccessibilityElement = false
        return wrapperView
    }
}


/**
 `ToastStyle` instances define the look and feel for toast views created via the
 `makeToast` methods as well for toast views created directly with
 `toastViewForMessage(message:title:image:style:)`.

 @warning `ToastStyle` offers relatively simple styling options for the default
 toast view. If you require a toast view with more complex UI, it probably makes more
 sense to create your own custom UIView subclass and present it with the `showToast`
 methods.
*/
public struct ToastStyle {

    public init() {}
    
    /**
     The background color. Default is `.secondarySystemBackground`
    */
    public var backgroundColor: UIColor = .secondarySystemBackground
    
    /**
     The title color. Default is `.label`.
    */
    public var titleColor: UIColor = .label
    
    /**
     The message color. Default is `.label`.
    */
    public var messageColor: UIColor = .label
    
    public var buttonColor: UIColor = .systemBlue
    
    /**
     A percentage value from 0.0 to 1.0, representing the maximum width of the toast
     view relative to it's superview. Default is 0.8 (80% of the superview's width).
    */
    public var maxWidthPercentage: CGFloat = 0.8 {
        didSet {
            maxWidthPercentage = max(min(maxWidthPercentage, 1.0), 0.0)
        }
    }
    
    /**
     A percentage value from 0.0 to 1.0, representing the maximum height of the toast
     view relative to it's superview. Default is 0.8 (80% of the superview's height).
    */
    public var maxHeightPercentage: CGFloat = 0.8 {
        didSet {
            maxHeightPercentage = max(min(maxHeightPercentage, 1.0), 0.0)
        }
    }
    
    /**
     The spacing from the horizontal edge of the toast view to the content. When an image
     is present, this is also used as the padding between the image and the text.
     Default is 10.0.
     
    */
    public var horizontalPadding: CGFloat = 10.0
    
    /**
     The spacing from the vertical edge of the toast view to the content.
     Default is 10.0. On iOS11+, this value is added added to the `safeAreaInset.top`
     and `safeAreaInsets.bottom`.
    */
    public var verticalPadding: CGFloat = 10.0
    
    /**
     The corner radius. Default is 10.0.
    */
    public var cornerRadius: CGFloat = 10.0
    
    public var titleFont: UIFont = .preferredFont(forTextStyle: .headline)
    
    public var messageFont: UIFont = .preferredFont(forTextStyle: .callout)
    
    public var buttonFont: UIFont = .preferredFont(forTextStyle: .callout)
    
    /**
     The title text alignment. Default is `NSTextAlignment.Left`.
    */
    public var titleAlignment: NSTextAlignment = .left
    
    /**
     The message text alignment. Default is `NSTextAlignment.Left`.
    */
    public var messageAlignment: NSTextAlignment = .left
    
    /**
     The maximum number of lines for the title. The default is 0 (no limit).
    */
    public var titleNumberOfLines = 0
    
    /**
     The maximum number of lines for the message. The default is 0 (no limit).
    */
    public var messageNumberOfLines = 0
    
    public var buttonNumberOfLines = 0
    
    /**
     Enable or disable a shadow on the toast view. Default is `true`.
    */
    public var displayShadow = true
    
    /**
     The shadow color. Default is `.secondaryLabel`.
     */
    public var shadowColor: UIColor = .secondaryLabel
    
    /**
     A value from 0.0 to 1.0, representing the opacity of the shadow.
     Default is 0.8 (80% opacity).
    */
    public var shadowOpacity: Float = 0.8 {
        didSet {
            shadowOpacity = max(min(shadowOpacity, 1.0), 0.0)
        }
    }

    /**
     The shadow radius. Default is 6.0.
    */
    public var shadowRadius: CGFloat = 6.0
    
    /**
     The shadow offset. The default is zero.
    */
    public var shadowOffset = CGSize.zero
    
    /**
     The image size. The default is 32 x 32.
    */
    public var imageSize = CGSize(width: 32.0, height: 32.0)
    
    /**
     The size of the toast activity view when `makeToastActivity(position:)` is called.
     Default is 100 x 100.
    */
    public var activitySize = CGSize(width: 100.0, height: 100.0)
    
    /**
     The fade in/out animation duration. Default is 0.2.
     */
    public var fadeDuration: TimeInterval = 0.2
    
    /**
     Activity indicator color. Default is `.white`.
     */
    public var activityIndicatorColor: UIColor = .white
    
    /**
     Activity background color. Default is `.black` at 80% opacity.
     */
    public var activityBackgroundColor: UIColor = UIColor.black.withAlphaComponent(0.8)
    
}


/**
 `ToastManager` provides general configuration options for all toast
 notifications. Backed by a singleton instance.
*/
public class ToastManager {
    
    /**
     The `ToastManager` singleton instance.
     
     */
    public static let shared = ToastManager()
    
    /**
     The shared style. Used whenever toastViewForMessage(message:title:image:style:) is called
     with with a nil style.
     
     */
    public var style = ToastStyle()
    
    /**
     Enables or disables tap to dismiss on toast views. Default is `true`.
     
     */
    public var isTapToDismissEnabled = true
    
    /**
     Enables or disables queueing behavior for toast views. When `true`,
     toast views will appear one after the other. When `false`, multiple toast
     views will appear at the same time (potentially overlapping depending
     on their positions). This has no effect on the toast activity view,
     which operates independently of normal toast views. Default is `false`.
     
     */
    public var isQueueEnabled = false
    
    /**
     The default duration. Used for the `makeToast` and
     `showToast` methods that don't require an explicit duration.
     Default is 3.0.
     
     */
    public var duration: TimeInterval = 3.0
    
    /**
     Sets the default position. Used for the `makeToast` and
     `showToast` methods that don't require an explicit position.
     Default is `ToastPosition.Bottom`.
     
     */
    public var position: ToastPosition = .bottom
    
}


public enum ToastPosition {
    case top
    case center
    case bottom
    
    fileprivate func centerPoint(forToast toast: UIView, inSuperview superview: UIView) -> CGPoint {
        let topPadding: CGFloat = ToastManager.shared.style.verticalPadding + superview.csSafeAreaInsets.top
        let bottomPadding: CGFloat = ToastManager.shared.style.verticalPadding + superview.csSafeAreaInsets.bottom
        
        switch self {
        case .top:
            return CGPoint(
                x: superview.bounds.size.width / 2.0,
                y: (toast.frame.size.height / 2.0) + topPadding
            )
        case .center:
            return CGPoint(
                x: superview.bounds.size.width / 2.0,
                y: superview.bounds.size.height / 2.0
            )
        case .bottom:
            return CGPoint(
                x: superview.bounds.size.width / 2.0,
                y: (superview.bounds.size.height - (toast.frame.size.height / 2.0)) - bottomPadding
            )
        }
    }
}


public struct ToastAction {
    public typealias Handler = (() -> Void)
    var title: String
    var isLink: Bool
    var handler: Handler
    var icon: UIImage?
    
    public init(
        title: String,
        icon: UIImage? = nil,
        isLink: Bool = false,
        handler: @escaping Handler
    ) {
        self.title = title
        self.icon = icon
        self.isLink = isLink
        self.handler = handler
    }
}


private extension UIView {
    var csSafeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return self.safeAreaInsets
        } else {
            return .zero
        }
    }
}
