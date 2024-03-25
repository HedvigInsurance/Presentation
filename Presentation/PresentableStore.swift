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

public protocol StateProtocol: Codable & EmptyInitable & Equatable {}
public protocol ActionProtocol: Codable & Equatable {}

public struct EffectSignal<Action>: SignalProvider, Hashable {
    public static func == (lhs: EffectSignal<Action>, rhs: EffectSignal<Action>) -> Bool {
        lhs.id == rhs.id
    }
    
    public var action: Action
    public var id = UUID()
    var signal: FiniteSignal<Action>
    
    public var providedSignal: CoreSignal<Finite, Action> {
        signal
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public init(_ action: Action, _ signal: FiniteSignal<Action>) {
        self.action = action
        self.signal = signal
    }
}

open class StateStore<State: StateProtocol, Action: ActionProtocol>: Store {
    let stateWriteSignal: CoreSignal<ReadWrite, State>
    let actionCallbacker = Callbacker<Action>()
    
    public var logger: (_ message: String) -> Void = { _ in }
    
    public var state: State {
        stateWriteSignal.value
    }
    
    public var stateSignal: CoreSignal<Read, State> {
        stateWriteSignal.readOnly().distinct()
    }
    
    public var actionSignal: CoreSignal<Plain, Action> {
        actionCallbacker.providedSignal
    }
    
    open func effects(_ getState: @escaping () -> State, _ action: Action) async  {
        fatalError("Must be overrided by subclass")
    }
    
    open func reduce(_ state: State, _ action: Action) -> State {
        fatalError("Must be overrided by subclass")
    }
    
    public func setState(_ state: State) {
        self.stateWriteSignal.value = state
    }
    
    /// Sends an action to the store, which is then reduced to produce a new state
    public func send(_ action: Action) {
        logger("🦄 \(String(describing: Self.self)): sending \(action)")
        
        let previousState = stateSignal.value
        
        stateWriteSignal.value = reduce(stateSignal.value, action)
        actionCallbacker.callAll(with: action)
        
        DispatchQueue.global(qos: .background).async {
            Self.persist(self.stateSignal.value)
        }
                
        let newState = stateSignal.value
        
        if newState != previousState {
            logger("🦄 \(String(describing: Self.self)): new state \n \(newState)")
        }
        Task {
            await effects({
                self.stateSignal.value
            }, action)
        }
    }
    
    public func sendAsync(_ action: Action) async {
        logger("🦄 \(String(describing: Self.self)): sending \(action)")
        
        let previousState = stateSignal.value
        
        stateWriteSignal.value = reduce(stateSignal.value, action)
        actionCallbacker.callAll(with: action)
        
        DispatchQueue.global(qos: .background).async {
            Self.persist(self.stateSignal.value)
        }
                
        let newState = stateSignal.value
        
        if newState != previousState {
            logger("🦄 \(String(describing: Self.self)): new state \n \(newState)")
        }
        await effects({
            self.stateSignal.value
        }, action)
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
    associatedtype State: StateProtocol
    associatedtype Action: ActionProtocol
    
    static func getKey() -> UnsafeMutablePointer<Int>
    
    var logger: (_ message: String) -> Void { get set }
    var stateSignal: CoreSignal<Read, State> { get }
    var actionSignal: CoreSignal<Plain, Action> { get }
    
    /// WARNING: Use this to set the state to the provided state BUT only for mocking purposes
    func setState(_ state: State)
    
    func reduce(_ state: State, _ action: Action) -> State
    func effects(_ getState: @escaping () -> State, _ action: Action) async
    func send(_ action: Action)
    func send(_ action: Action) async

    init()
}

var pointers: [String: UnsafeMutablePointer<Int>] = [:]

var storePersistenceDirectory: URL {
    let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory.appendingPathComponent("PresentableStore")
}

extension Store {
    public static func getKey() -> UnsafeMutablePointer<Int> {
        let key = String(describing: Self.self)
        
        if pointers[key] == nil {
            pointers[key] = UnsafeMutablePointer<Int>.allocate(capacity: 2)
        }
        
        return pointers[key]!
    }
    
    static var persistenceURL: URL {
        let docURL = storePersistenceDirectory
        try? FileManager.default.createDirectory(at: docURL, withIntermediateDirectories: true, attributes: nil)
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
    
    /// Calls onAction whenever an action equal to action happens
    public func onAction(_ action: Action, _ onAction: @escaping () -> Void) -> Disposable {
        actionSignal.filter(predicate: { action == $0 }).onValue { action in
            onAction()
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
        
        var store = S.init()
        store.logger = logger
        initialize(store)
        
        return store
    }
    
    public func initialize<S: Store>(_ store: S) {
       setAssociatedValue(store, forKey: S.getKey())
       debugger?.registerStore(store)
    }
    
    public override init() {
        super.init()
    }
    
    public func deletePersistanceContainer() {
        try? FileManager.default.removeItem(at: storePersistenceDirectory)
    }
    
    public var debugger: Debugger? = nil
    public var logger: (_ message: String) -> Void = { message in
        print(message)
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

public protocol LoadingProtocol: Codable & Equatable & Hashable {}


public enum LoadingState<T>: Codable & Equatable & Hashable where T: Codable & Equatable & Hashable {
    case loading
    case error(error: T)
}


public protocol StoreLoading {
    associatedtype Loading: LoadingProtocol
    
    var loadingSignal: CoreSignal<Read, [Loading: LoadingState<String>]> { get }
    func removeLoading(for action: Loading)
    
    func setLoading(for action: Loading)
    
    func setError(_ error: String, for action: Loading)
    
    func reset()
    
    init()
}


open class LoadingStateStore<State: StateProtocol, Action: ActionProtocol, Loading: LoadingProtocol>: StateStore<State, Action>, StoreLoading  {
    private var loadingStates: [Loading: LoadingState<String>] = [:] {
        didSet{
            loadingWriteSignal.value = loadingStates
        }
    }
    private let loadingWriteSignal: CoreSignal<ReadWrite, [Loading: LoadingState<String>]> = ReadWriteSignal([:])

    public var loadingSignal: CoreSignal<Read, [Loading: LoadingState<String>]> {
        loadingWriteSignal.readOnly().distinct()
    }
    
    public func removeLoading(for action: Loading) {
        DispatchQueue.main.async {[weak self] in guard let self = self else { return }
            self.loadingStates.removeValue(forKey: action)
            self.loadingWriteSignal.value = self.loadingStates
        }
    }
    
    public func setLoading(for action: Loading) {
        DispatchQueue.main.async {[weak self] in guard let self = self else { return }
            self.loadingStates[action] = .loading
        }
    }
    
    public func setError(_ error: String, for action: Loading){
        DispatchQueue.main.async {[weak self] in guard let self = self else { return }
            self.loadingStates[action] = .error(error: error)
        }
    }
    
    public func reset() {
        DispatchQueue.main.async {[weak self] in guard let self = self else { return }
            loadingStates.removeAll()
        }
    }
    
    public required init() {
        super.init()
    }
}

enum PresentableStoreError: Error {
    case notImplemented
}
