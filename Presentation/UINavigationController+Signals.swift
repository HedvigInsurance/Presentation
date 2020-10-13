//
//  UINavigationController+Signals.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2016-02-26.
//  Copyright © 2016 iZettle. All rights reserved.
//

import UIKit
import Flow

public extension UINavigationController {
    /// Returns a signal that signals when a view controller is popped from `self`.
    var popViewControllerSignal: Signal<UIViewController> {
        return delegateSignal(for: { $0.popSignal })
    }

    /// Returns a signal that signals a view controller just before it is popped from `self`.
    var willPopViewControllerSignal: Signal<UIViewController> {
        return delegateSignal(for: { $0.willPopSignal })
    }

    /// Returns a signal that signals a view controller just before it will be shown on `self`
    var willShowViewControllerSignal: Signal<(viewController: UIViewController, animated: Bool)> {
        return delegateSignal(for: { $0.willShowSignal })
    }

    /// Returns a signal that signals when `self` `viewController` is updated.
    var viewControllersSignal: ReadSignal<[UIViewController]> {
        return delegateSignal(for: { $0.viewControllersSignal }).readable(capturing: self.viewControllers)
    }
}

public extension UINavigationItem {
    /// Returns a signal that signals when the view controller using `self` is beeing popped.
    var popSignal: Signal<()> {
        return Signal(callbacker: popCallbacker)
    }
}

private var callbackerKey = false

extension UINavigationController {
    public static var InitPresentationNavigationControllerDelegate:
        (UINavigationControllerDelegate?, UINavigationController) ->
        PresentationNavigationControllerDelegate = { (delegate, navigationController) in
        NavigationControllerDelegate(delegate: delegate, navigationController: navigationController)
    }
}

private extension UINavigationController {
    func delegateSignal<Value>(for signal: @escaping (PresentationNavigationControllerDelegate) -> Signal<Value>) -> Signal<Value> {
        return Signal { callback in
            let bag = DisposeBag()
            let delegate: PresentationNavigationControllerDelegate
            if let navigationDelegate = self.delegate as? PresentationNavigationControllerDelegate {
                delegate = navigationDelegate
            } else {
                delegate = Self.InitPresentationNavigationControllerDelegate(self.delegate, self)
                self.delegate = delegate
            }
            bag.hold(delegate)
            bag += signal(delegate).onValue(callback)
            return bag
        }
    }
}

extension UINavigationItem {
    var popCallbacker: Callbacker<()> {
        return associatedValue(forKey: &callbackerKey, initial: Callbacker())
    }
}

public protocol PresentationNavigationControllerDelegate: UINavigationControllerDelegate {
    var popSignal: Signal<UIViewController> { get }
    var viewControllersSignal: Signal<[UIViewController]> { get }
    var willPopSignal: Signal<UIViewController> { get }
    var willShowSignal: Signal<(viewController: UIViewController, animated: Bool)> { get }
}

private class NavigationControllerDelegate: NSObject, UINavigationControllerDelegate, PresentationNavigationControllerDelegate {
    weak var delegate: UINavigationControllerDelegate?
    weak var navigationController: UINavigationController?

    public init(delegate: UINavigationControllerDelegate?, navigationController: UINavigationController) {
        self.delegate = delegate
        self.navigationController = navigationController
    }

    fileprivate var popControllers = [UIViewController]()

    fileprivate var popCallbacker = Callbacker<UIViewController>()
    var popSignal: Signal<UIViewController> {
        return Signal(callbacker: popCallbacker)
    }

    fileprivate var viewControllersCallbacker = Callbacker<[UIViewController]>()
    var viewControllersSignal: Signal<[UIViewController]> {
        return Signal(callbacker: viewControllersCallbacker)
    }

    fileprivate var willPopCallbacker = Callbacker<UIViewController>()
    var willPopSignal: Signal<UIViewController> {
        return Signal(callbacker: willPopCallbacker)
    }

    fileprivate var willShowCallbacker = Callbacker<(viewController: UIViewController, animated: Bool)>()
    var willShowSignal: Signal<(viewController: UIViewController, animated: Bool)> {
        return Signal(callbacker: willShowCallbacker)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        delegate?.navigationController?(navigationController, animationControllerFor: operation, from: fromVC, to: toVC)
    }
    
    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        delegate?.navigationController?(navigationController, interactionControllerFor: animationController)
    }

    fileprivate func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        willShowCallbacker.callAll(with: (viewController: viewController, animated: animated))

        let removedControllers = popControllers.filter { !navigationController.viewControllers.contains($0) }
        removedControllers.forEach(willPopCallbacker.callAll)

        navigationController.view.endEditing(true) // End editing to help nc in modal to reset it's size
        delegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
    }

    fileprivate func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        viewControllersCallbacker.callAll(with: navigationController.viewControllers)

        let removedControllers = popControllers.filter { !navigationController.viewControllers.contains($0) }
        removedControllers.forEach(popCallbacker.callAll)
        popControllers = navigationController.viewControllers
        delegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
    }

    deinit {
        if let nc = navigationController, nc.delegate as? NavigationControllerDelegate == self {
            nc.delegate = self.delegate
        }
    }
}
