//
//  JourneyPresentation.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-15.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

public struct JourneyPresenter<P: Presentable> {
    public init(viewController: UIViewController, matter: P.Matter, bag: DisposeBag, dismisser: @escaping (Error?) -> Void) {
        self.viewController = viewController
        self.matter = matter
        self.bag = bag
        self.dismisser = dismisser
    }
    
    public let viewController: UIViewController
    public let matter: P.Matter
    public let bag: DisposeBag
    public let dismisser: (Error?) -> Void
}

public protocol JourneyPresentation {
    associatedtype P: Presentable

    /// The presentable wrapped by `self`.
    var presentable: P { get }

    /// The presentation style to use when presenting `self`.
    var style: PresentationStyle { get }

    /// The presentation options to use when presenting `self`.
    var options: PresentationOptions { get }
    
    /// A transformation to apply on the `materialized()` result.
    var transform: (P.Result) -> P.Result { get set }

    /// The configuration to apply just before presenting `self`.
    var configure: (JourneyPresenter<P>) -> () { get set }

    /// A callback that will be called once presentaion is done, either with `nil` if normally dismissed, or with an error if not.
    var onDismiss: (Error?) -> () { get set }
}

public extension JourneyPresentation {
    /// Returns a new JourneyPresentation where the result will be transformed using `transform`.
    func map(_ transform: @escaping (P.Result) -> P.Result) -> Self {
        let presentationTransform = self.transform
        var new = self
        new.transform = { result in transform(presentationTransform(result)) }
        new.onDismiss = onDismiss

        return new
    }

    /// Returns a new JourneyPresentation where `callback` will be called when `self` is being presented.
    func onPresent(_ callback: @escaping () -> ()) -> Self {
        return map {
            callback()
            return $0
        }
    }

    /// Returns a new JourneyPresentation where `callback` will be called when `self` is being dismissed.
    func onDismiss(_ callback: @escaping () -> ()) -> Self {
        let onDismiss = self.onDismiss
        var new = self

        new.onDismiss = {
            onDismiss($0)
            callback()
        }

        return new
    }
    
    /// Returns a new presentation where `callback` will be called with the value of a successful dismiss of `self`.
    func onValue<Value>(_ callback: @escaping (Value) -> ()) -> Self where P.Result == Future<Value> {
        let onDismiss = self.onDismiss
        var value: Value?
        var new = map { $0.onValue { value = $0 } }

        new.onDismiss = { error in
            onDismiss(error)
            if let value = value, error == nil {
                callback(value)
            }
        }

        return new
    }

    /// Returns a new presentation where `callback` will be called for every signaled value.
    func onValue<Kind, Value>(_ callback: @escaping (Value) -> ()) -> Self where P.Result == CoreSignal<Kind, Value> {
        return map {
            $0.atValue(callback)
        }
    }

    /// Returns a new JourneyPresentation where `callback` will be called if `self` was dismiss with an error.
    func onError(_ callback: @escaping (Error) -> ()) -> Self {
        let onDismiss = self.onDismiss
        var new = self
        new.onDismiss = {
            onDismiss($0)
            if let error = $0 {
                callback(error)
            }
        }
        return new
    }

    /// Returns a new JourneyPresentation where `configure` will be called at presentation.
    /// - Note: `self`'s `configure` will still be called before the provided `configure`.
    func addConfiguration(_ configure: @escaping (JourneyPresenter<P>) -> ()) -> Self {
        var new = self
        let oldConfigure = new.configure
        new.configure = { presenter in
            oldConfigure(presenter)
            configure(presenter)
        }
        return new
    }
    
    /// Returns a new JourneyPresentation where the JourneyBuilder closure gets called every time a store emits an action
    /// which results in that journey being presented
    func onAction<S: Store, InnerJourney: JourneyPresentation>(
        _ storeType: S.Type,
        @JourneyBuilder _ onAction: @escaping (_ action: S.Action) -> InnerJourney
    ) -> Self {
        addConfiguration { presenter in
            let store: S = self.presentable.get()
            
            presenter.bag += store.actionSignal.onValue { action in
                let result: JourneyPresentResult<InnerJourney> = presenter.viewController.present(onAction(action))
                
                switch result {
                case let .presented(result):
                    presenter.bag.hold(result as AnyObject)
                case .shouldDismiss:
                    presenter.dismisser(JourneyError.dismissed)
                case .shouldPop:
                    presenter.dismisser(JourneyError.cancelled)
                case .shouldContinue:
                    break
                }
            }
        }
    }
    
    /// Returns a new JourneyPresentation where the JourneyBuilder closure gets called every time a store results a new state
    /// which results in that journey being presented
    func onState<S: Store, InnerJourney: JourneyPresentation>(
        _ storeType: S.Type,
        @JourneyBuilder _ onState: @escaping (_ state: S.State) -> InnerJourney
    ) -> Self {
        addConfiguration { presenter in
            let store: S = self.presentable.get()
            
            presenter.bag += store.stateSignal.onValue { state in
                let result: JourneyPresentResult<InnerJourney> = presenter.viewController.present(onState(state))
                
                switch result {
                case let .presented(result):
                    presenter.bag.hold(result as AnyObject)
                case .shouldDismiss:
                    presenter.dismisser(JourneyError.dismissed)
                case .shouldPop:
                    presenter.dismisser(JourneyError.cancelled)
                case .shouldContinue:
                    break
                }
            }
        }
    }
    
    /// Returns a new JourneyPresentation where the closure gets called each time the state changes
    func onStateChange<S: Store>(
        _ storeType: S.Type,
        _ onState: @escaping (_ state: S.State, _ presenter: JourneyPresenter<Self.P>) -> Void
    ) -> Self {
        addConfiguration { presenter in
            let store: S = self.presentable.get()
            
            presenter.bag += store.stateSignal.onValue { state in
                onState(state, presenter)
            }
        }
    }
    
    var cancelJourneyDismiss: Self {
        var new = self
        let oldConfigure = new.configure
        new.configure = { presenter in
            let newPresenter = JourneyPresenter<P>(viewController: presenter.viewController, matter: presenter.matter, bag: presenter.bag) { error in
                let error = error as? JourneyError
                
                guard error != JourneyError.dismissed else {
                    return
                }
                
                presenter.dismisser(error)
            }
            
            oldConfigure(newPresenter)
        }
        
        return new
    }
}
