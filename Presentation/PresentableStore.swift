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
    associatedtype State: Codable
    associatedtype Action: Codable
    
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
    
    private static var documentsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    private static var persistenceURL: URL {
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

    /// Sends an action to the store, which is then reduced to produce a new state
    public func send(_ action: Action) {
        #if DEBUG

        print("🦄 \(String(describing: Self.self)): sending \(action)")
        
        #endif
        
        providedSignal.value = reduce(providedSignal.value, action)
        onAction.callAll(with: action)
        
        DispatchQueue.global(qos: .background).async {
            Self.persist(providedSignal.value)
        }
        
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
    
    /// Reduce to an action in another store, useful to sync between two stores
    public func reduce<S: Store>(to store: S, reducer: @escaping (_ action: Action) -> S.Action) -> Disposable {
        onAction.onValue { action in
            store.send(reducer(action))
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
        debugger.registerStore(store)
    }
    
    public override init() {
        super.init()
        debugger.startServer()
    }
    
    let debugger = PresentableStoreDebugger()
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
