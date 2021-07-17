//
//  PresentableStore.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-16.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow

public protocol Store: SignalProvider {
    associatedtype State
    associatedtype Action
    
    static func getKey() -> UnsafeMutablePointer<Int>
    
    var providedSignal: ReadWriteSignal<State> { get }
    var onAction: Callbacker<Action> { get }
    
    func reduce(_ state: State, _ action: Action) -> State
    func effects(_ state: State, _ action: Action) -> Future<Action>?
    func send(_ action: Action)
    
    init()
}

var pointers: [String: UnsafeMutablePointer<Int>] = [:]

extension Store {
    public static func getKey() -> UnsafeMutablePointer<Int> {
        let key = String(describing: Self.self)
        
        if pointers[key] == nil {
            pointers[key] = UnsafeMutablePointer<Int>.allocate(capacity: 2)
        }
        
        return pointers[key]!
    }
    
    public func send(_ action: Action) {
        #if DEBUG
        
        print("🦄 \(String(describing: Self.self)): sending \(action)")
        
        #endif
        
        providedSignal.value = reduce(providedSignal.value, action)
        onAction.callAll(with: action)
        
        #if DEBUG
        
        print("🦄 \(String(describing: Self.self)): new state")
        dump(providedSignal.value)
        
        #endif
        
        if let effectActionFuture = effects(providedSignal.value, action) {
            effectActionFuture.onValue { action in
                self.send(action)
            }
        }
    }
}

public class PresentableStoreContainer: NSObject {
    public func get<S: Store>() -> S {
        if let store: S = associatedValue(forKey: S.getKey()) {
            return store
        }
        
        let store = S.init()
        initialize(store)
        
        return store
    }

    public func initialize<S: Store>(_ store: S) {
       setAssociatedValue(store, forKey: S.getKey())
    }
}

/// Set this to automatically populate all presentables with your global PresentableStoreContainer
public var globalPresentableStoreContainer = PresentableStoreContainer()

extension Presentable {
    public var storeContainer: PresentableStoreContainer {
        globalPresentableStoreContainer
    }

    public func get<S: Store>() -> S {
        return storeContainer.get()
    }
}
