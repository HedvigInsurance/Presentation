//
//  Presentable+ViewModifiers.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-17.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow

extension Presentable where Matter: UIView {
    public func onValue<Kind, Value>(_ callback: @escaping (Value) -> Void) -> AnyPresentable<UIView, DisposeBag> where Result == CoreSignal<Kind, Value> {
        AnyPresentable {
            let (matter, result) = self.materialize()
            let bag = DisposeBag()
            
            bag += result.onValue(callback)
            
            return (matter, bag)
        }
    }
    
    public func configure(_ callback: @escaping (Matter) -> Disposable) -> AnyPresentable<UIView, DisposeBag> where Result: Disposable {
        AnyPresentable {
            let (matter, result) = self.materialize()
            
            let bag = DisposeBag()
            bag += result
            bag += callback(matter)
            
            return (matter, bag)
        }
    }
    
    public func configure(_ callback: @escaping (Matter) -> Void) -> AnyPresentable<UIView, DisposeBag> where Result: Disposable {
        AnyPresentable {
            let (matter, result) = self.materialize()
            
            let bag = DisposeBag()
            bag += result
            callback(matter)
            
            return (matter, bag)
        }
    }
}


protocol ViewLifecycle {
    associatedtype View: UIView
    func didLayout(_ callback: @escaping () -> Void) -> ViewAndDisposable<View>
    func didMoveToSuperview(_ callback: @escaping () -> Void) -> ViewAndDisposable<View>
}

public struct ViewAndDisposable<View: UIView>: ViewLifecycle {
    let view: View
    let disposable: Disposable
    
    public func didLayout(_ callback: @escaping () -> Void) -> ViewAndDisposable<View> {
        let bag = DisposeBag()
        bag += view.didLayoutSignal.onValue(callback)
        return ViewAndDisposable(view: view, disposable: bag)
    }
    
    public func didMoveToSuperview(_ callback: @escaping () -> Void) -> ViewAndDisposable<View> {
        let bag = DisposeBag()
        bag += view.didMoveToWindowSignal.onValue(callback)
        return ViewAndDisposable(view: view, disposable: bag)
    }
    
    public func hold(_ bag: DisposeBag) -> Disposable {
        bag += disposable
        return bag
    }
}

extension UIView: ViewLifecycle {
    public func didLayout(_ callback: @escaping () -> Void) -> ViewAndDisposable<UIView> {
        ViewAndDisposable(view: self, disposable: self.didLayoutSignal.onValue(callback))
    }
    
    public func didMoveToSuperview(_ callback: @escaping () -> Void) -> ViewAndDisposable<UIView> {
        ViewAndDisposable(view: self, disposable: self.didMoveToWindowSignal.onValue(callback))
    }
}
