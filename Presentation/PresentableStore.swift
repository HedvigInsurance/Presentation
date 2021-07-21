//
//  PresentableStore.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-16.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow

public protocol EmptyInitable {
    init()
}

open class StateStore<State: Codable & EmptyInitable, Action: Codable>: Store {
    let stateWriteSignal: CoreSignal<ReadWrite, State>
    let actionCallbacker = Callbacker<Action>()
    
    public var state: State {
        stateWriteSignal.value
    }
    
    public var stateSignal: CoreSignal<Read, State> {
        stateWriteSignal.readOnly()
    }
    
    public var actionSignal: CoreSignal<Plain, Action> {
        actionCallbacker.providedSignal
    }
    
    open func effects(_ getState: () -> State, _ action: Action) -> Future<Action>? {
        fatalError("Must be overrided by subclass")
    }
    
    open func reduce(_ state: State, _ action: Action) -> State {
        fatalError("Must be overrided by subclass")
    }
    
    /// Sends an action to the store, which is then reduced to produce a new state
    public func send(_ action: Action) {
        #if DEBUG

        print("🦄 \(String(describing: Self.self)): sending \(action)")
        
        #endif
        
        stateWriteSignal.value = reduce(stateSignal.value, action)
        actionCallbacker.callAll(with: action)
        
        DispatchQueue.global(qos: .background).async {
            Self.persist(self.stateSignal.value)
        }
        
        #if DEBUG
        
        print("🦄 \(String(describing: Self.self)): new state")
        dump(stateSignal.value)
        
        #endif
        
        if let effectActionFuture = effects({
            stateSignal.value
        }, action) {
            effectActionFuture.onValue { action in
                self.send(action)
            }
        }
    }
    
    public required init() {
        if let stored = Self.restore() {
            self.stateWriteSignal = ReadWriteSignal(stored)
        } else {
            self.stateWriteSignal = ReadWriteSignal(State())
        }
    }
}

public protocol Store {
    associatedtype State: Codable
    associatedtype Action: Codable
    
    static func getKey() -> UnsafeMutablePointer<Int>
    
    var stateSignal: CoreSignal<Read, State> { get }
    var actionSignal: CoreSignal<Plain, Action> { get }
            
    func reduce(_ state: State, _ action: Action) -> State
    func effects(_ getState: () -> State, _ action: Action) -> Future<Action>?
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
    
    static var documentsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    static var persistenceURL: URL {
        let docURL = documentsDirectory
        return docURL.appendingPathComponent(String(describing: Self.self))
    }

    public static func persist(_ value: State) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(value) {
            do {
                try encoded.write(to: persistenceURL)
            } catch {
                print("Couldn't write to save file: " + error.localizedDescription)
            }
        }
    }
    
    public static func restore() -> State? {
        guard let codedData = try? Data(contentsOf: persistenceURL) else {
            return nil
        }

        let decoder = JSONDecoder()

        if let decoded = try? decoder.decode(State.self, from: codedData) {
            return decoded
        }
        
        return nil
    }
    
    /// Deletes all persisted instances of the Store
    public static func destroy() {
        try? FileManager.default.removeItem(at: persistenceURL)
    }
    
    /// Reduce to an action in another store, useful to sync between two stores
    public func reduce<S: Store>(to store: S, reducer: @escaping (_ action: Action, _ state: State) -> S.Action) -> Disposable {
        actionSignal.onValue { action in
            store.send(reducer(action, stateSignal.value))
        }
    }
}

public protocol Debugger {
    func startServer()
    func registerStore<S: Store>(_ store: S)
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
        Self.debugger?.registerStore(store)
    }
    
    public override init() {
        super.init()
        Self.debugger?.startServer()
    }
    
    static var debugger: Debugger? = nil
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
