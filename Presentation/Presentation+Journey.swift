//
//  Presentation+Journey.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-13.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

public struct ConditionalJourneyPresentable<TrueP: Presentable, FalseP: Presentable>: Presentable {
    enum Storage {
      case first(TrueP)
      case second(FalseP)
    }
      
    let storage: Storage
    
    init(first : TrueP)  { storage = .first(first)   }
    init(second : FalseP) { storage = .second(second) }
    
    public func materialize() -> ((TrueP.Matter?, FalseP.Matter?), (TrueP.Result?, FalseP.Result?)) {
        switch storage {
        case let .first(presentable):
            let (matter, result) = presentable.materialize()
            return ((matter, nil), (result, nil))
        case let .second(presentable):
            let (matter, result) = presentable.materialize()
            return ((nil, matter), (nil, result))
        }
    }
}

func tupleUnnest(_ tuple: Any) -> Any {
    if let (a, b) = tuple as? (Any?, Any?) {
        if let a = a {
            return tupleUnnest(a)
        } else if let b = b {
            return tupleUnnest(b)
        }
     }
    
    return tuple
}

public class ConditionalJourneyPresentation<TrueP: JourneyPresentation, FalseP: JourneyPresentation>: JourneyPresentation
{
    public var style: PresentationStyle {
        switch storage {
        case let .first(presentation):
            return presentation.style
        case let .second(presentation):
            return presentation.style
        }
    }
    
    public var options: PresentationOptions {
        switch storage {
        case let .first(presentation):
            return presentation.options
        case let .second(presentation):
            return presentation.options
        }
    }
            
    public var configure: ((TrueP.P.Matter?, FalseP.P.Matter?), DisposeBag) -> ()
    public var onDismiss: (Error?) -> () {
        get {
            switch self.storage {
            case let .first(presentation):
                return presentation.onDismiss
            case let .second(presentation):
                return presentation.onDismiss
            }
        }
        set {
            switch self.storage {
            case var .first(presentation):
                presentation.onDismiss = newValue
            case var .second(presentation):
                presentation.onDismiss = newValue
            }
        }
    }
    public var transform: ((TrueP.P.Result?, FalseP.P.Result?)) -> (TrueP.P.Result?, FalseP.P.Result?)
    
    public var presentable: ConditionalJourneyPresentable<TrueP.P, FalseP.P> {
        switch storage {
        case let .first(presentation):
            return ConditionalJourneyPresentable(first: presentation.presentable)
        case let .second(presentation):
            return ConditionalJourneyPresentable(second: presentation.presentable)
        }
    }
    
  enum Storage {
    case first(TrueP)
    case second(FalseP)
  }
    
  let storage: Storage
    
    func setupDefaults() {
        self.transform = { result in
            switch self.storage {
            case let .first(presentation):
                return (presentation.transform(result.0!), nil)
            case let .second(presentation):
                return (nil, presentation.transform(result.1!))
            }
        }
        
        self.configure = { matter, bag in
            switch self.storage {
            case let .first(presentation):
                presentation.configure(matter.0!, bag)
            case let .second(presentation):
                presentation.configure(matter.1!, bag)
            }
        }
    }
  
  init(first : TrueP)  {
    storage = .first(first)
    self.transform = { $0 }
    self.configure = { _, _ in }
    setupDefaults()
  }
    
  init(second : FalseP) {
    storage = .second(second)
    self.transform = { $0 }
    self.configure = { _, _ in }
    setupDefaults()
  }
}

@resultBuilder public struct JourneyBuilder {
    public static func buildEither<TrueP: JourneyPresentation, FalseP: JourneyPresentation>(first p: TrueP) -> ConditionalJourneyPresentation<TrueP, FalseP> {
        return ConditionalJourneyPresentation(first: p)
    }
    
    public static func buildEither<TrueP: JourneyPresentation, FalseP: JourneyPresentation>(second p: FalseP) -> ConditionalJourneyPresentation<TrueP, FalseP> {
        return ConditionalJourneyPresentation(second: p)
    }

    public static func buildBlock<P: JourneyPresentation>(_ p: P) -> P {
        return p
    }
    
    public static func buildOptional<JP: JourneyPresentation>(_ journeyPresentation: JP?) -> ConditionalJourneyPresentation<JP, ContinueJourney> {
        if let journeyPresentation = journeyPresentation {
            return ConditionalJourneyPresentation(first: journeyPresentation)
        }
        
        return ConditionalJourneyPresentation(second: ContinueJourney())
    }
}

func unsafeCastToUIViewController(_ any: Any?) -> UIViewController {
    if let vc = any as? UIViewController {
        return vc
    }
    
    fatalError("Matter of JourneyPresentation must always inherit from UIViewController")
}

public enum JourneyPresentResult<J: JourneyPresentation> {
    case presented(_ result: J.P.Result)
    case shouldDismiss
    case shouldPop
    case shouldContinue
}

extension UIViewController {
    public func present<J: JourneyPresentation>(_ presentation: J) -> Future<Void> {
        Future { completion in
            let bag = DisposeBag()

            let presentResult: JourneyPresentResult<J> = self.present(presentation)
            
            switch presentResult {
            case let .presented(result):
                bag.hold(result as AnyObject)
            default:
                break
            }
            
            return bag
        }
    }
    
    func present<J: JourneyPresentation>(_ presentation: J) -> JourneyPresentResult<J> {
        let (matter, result) = presentation.presentable.materialize()
        
        let vc = unsafeCastToUIViewController(tupleUnnest(matter))
                
        if vc as? DismisserPresentable.DismisserViewController != nil {
            return .shouldDismiss
        } else if vc as? PoperPresentable.PoperViewController != nil {
            return .shouldPop
        } else if vc as? ContinuerPresentable.ContinuerViewController != nil {
            return .shouldContinue
        }
        
        let transformedResult = presentation.transform(result)
        
        present(vc, style: presentation.style, options: presentation.options) { vc, bag -> () in
            presentation.configure(matter, bag)
        }.onResult {
            presentation.onDismiss($0.error)
        }
        .onCancel {
            presentation.onDismiss(JourneyError.cancelled)
        }
        
        return .presented(transformedResult)
    }
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
    var configure: (P.Matter, DisposeBag) -> () { get set }

    /// A callback that will be called once presentaion is done, either with `nil` if normally dismissed, or with an error if not.
    var onDismiss: (Error?) -> () { get set }
}

public struct DismisserPresentable: Presentable {
    public class DismisserViewController: UIViewController {}
    
    public func materialize() -> (DismisserViewController, Future<Void>) {
        return (DismisserViewController(), Future<Void>())
    }
}

public struct DismissJourney: JourneyPresentation {
    public var presentable: DismisserPresentable {
        DismisserPresentable()
    }

    public var style: PresentationStyle {
        .default
    }

    public var options: PresentationOptions {
        []
    }

    public var configure: (DismisserPresentable.DismisserViewController, DisposeBag) -> () = { _, _  in }

    public var onDismiss: (Error?) -> () = { _ in }
    
    public var transform: (Future<Void>) -> Future<Void> = { $0 }

    public init() {}
}

public struct PoperPresentable: Presentable {
    public class PoperViewController: UIViewController {}
    
    public func materialize() -> (PoperViewController, Future<Void>) {
        return (PoperViewController(), Future<Void>())
    }
}

public struct PopJourney: JourneyPresentation {
    public var presentable: PoperPresentable {
        PoperPresentable()
    }

    public var style: PresentationStyle {
        .default
    }

    public var options: PresentationOptions {
        []
    }

    public var configure: (PoperPresentable.PoperViewController, DisposeBag) -> () = { _, _  in }

    public var onDismiss: (Error?) -> () = { _ in }
    
    public var transform: (Future<Void>) -> Future<Void> = { $0 }

    public init() {}
}

public struct ContinuerPresentable: Presentable {
    public class ContinuerViewController: UIViewController {}
    
    public func materialize() -> (ContinuerViewController, Future<Void>) {
        return (ContinuerViewController(), Future<Void>())
    }
}

public struct ContinueJourney: JourneyPresentation {
    public var presentable: ContinuerPresentable {
        ContinuerPresentable()
    }

    public var style: PresentationStyle {
        .default
    }

    public var options: PresentationOptions {
        []
    }

    public var configure: (ContinuerPresentable.ContinuerViewController, DisposeBag) -> () = { _, _  in }

    public var onDismiss: (Error?) -> () = { _ in }
    
    public var transform: (Future<Void>) -> Future<Void> = { $0 }

    public init() {}
}

public enum JourneyError: Error {
    case dismissed
    case cancelled
}

public class Journey<P: Presentable>: JourneyPresentation where P.Matter: UIViewController {
    public var onDismiss: (Error?) -> ()
    
    public var style: PresentationStyle
    
    public var options: PresentationOptions
    
    public var transform: (P.Result) -> P.Result
    
    public var configure: (P.Matter, DisposeBag) -> ()
    
    public let presentable: P
    
    public init<InnerJourney: JourneyPresentation, Value>(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop],
        @JourneyBuilder _ content: @escaping (_ value: P.Result.Value) -> InnerJourney
    ) where P.Result == CoreSignal<Finite, Value> {
        self.presentable = presentable
        self.style = style
        self.options = options
        self.transform = { $0 }
        self.configure = { _, _ in }
        self.onDismiss = { _ in }
        
        var result: P.Result? = nil
        
        self.transform = { signal in
            result = signal
            return signal
        }
        
        configure = { matter, bag in
            bag += result?.onEnd {
                bag.dispose()
            }
            
            bag += result?.onValue { value in
                let presentation = content(value).onError { error in
                    if let error = error as? JourneyError, error == JourneyError.dismissed && options.contains(.autoPop) {
                        self.onDismiss(JourneyError.dismissed)
                        bag.dispose()
                    }
                }
                
                let result: JourneyPresentResult<InnerJourney> = matter.present(presentation)
                
                switch result {
                case .presented:
                    break
                case .shouldDismiss:
                    self.onDismiss(JourneyError.dismissed)
                    bag.dispose()
                case .shouldPop:
                    bag.dispose()
                case .shouldContinue:
                    break
                }
            }
        }
        
        onDismiss = { _ in
            result = nil
        }
    }
    
    public init<InnerJourney: JourneyPresentation, Value>(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop],
        @JourneyBuilder _ content: @escaping (_ value: P.Result.Value) -> InnerJourney
    ) where P.Result == CoreSignal<Plain, Value> {
        self.presentable = presentable
        self.style = style
        self.options = options
        self.transform = { $0 }
        self.configure = { _, _ in }
        
        var result: P.Result? = nil
        
        self.onDismiss = { _ in
            result = nil
        }
        
        self.transform = { signal in
            result = signal
            return signal
        }
        
        self.configure = { matter, bag in
            bag += result?.onValue { value in
                let presentation = content(value).onError { error in
                    if let error = error as? JourneyError, error == JourneyError.dismissed && options.contains(.autoPop) {
                        self.onDismiss(JourneyError.dismissed)
                        bag.dispose()
                    }
                }
                
                let result: JourneyPresentResult<InnerJourney> = matter.present(presentation)
                
                switch result {
                case .presented:
                    break
                case .shouldDismiss:
                    self.onDismiss(JourneyError.dismissed)
                case .shouldPop:
                    bag.dispose()
                case .shouldContinue:
                    break
                }
            }
        }
    }
    
    public init<Value>(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop]
    ) where P.Result == Future<Value> {
        let dismissCallbacker = Callbacker<Void>()
        
        self.transform = { $0 }
        self.onDismiss = { _ in }
        self.configure = { _, bag in
            bag += dismissCallbacker.onValue { _ in
                bag.dispose()
            }
        }
        self.presentable = presentable
        self.style = style
        self.options = options
        
        self.transform = { future in
            Future { completion in
                let bag = DisposeBag()
                
                bag += future.onResult { result in
                    completion(result)
                    bag.dispose()
                }
                
                return bag
            }
        }
    }
    
    public init(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop]
    ) {
        self.transform = { $0 }
        self.onDismiss = { _ in }
        self.configure = { _, _ in }
        self.presentable = presentable
        self.style = style
        self.options = options
    }
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
    func addConfiguration(_ configure: @escaping (UIViewController, DisposeBag) -> ()) -> Self {
        var new = self
        let oldConfigure = new.configure
        new.configure = { vc, bag in
            oldConfigure(vc, bag)
            configure(unsafeCastToUIViewController(tupleUnnest(vc)), bag)
        }
        return new
    }
}
