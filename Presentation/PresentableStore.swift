//
//  PresentableStore.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-16.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow

public protocol Store {
    associatedtype State
    associatedtype Action
    
    static func getKey() -> UnsafeMutablePointer<Int>
    
    var state: ReadWriteSignal<State> { get }
    
    func reduce(_ state: State, _ action: Action) -> State
    func send(_ action: Action)
    
    init()
}

public class PresentableStoreContainer: NSObject {
    public func get<S: Store>() -> S? {
        return associatedValue(forKey: S.getKey())
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

    public func getStore<S: Store>() -> S {
        if let store: S = globalPresentableStoreContainer.get() {
            return store
        }
        
        let store = S.init()
        globalPresentableStoreContainer.initialize(store)
        
        return store
    }
}
