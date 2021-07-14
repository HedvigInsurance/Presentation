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

public struct ConditionalJourneyPresentation<TrueP: JourneyPresentation, FalseP: JourneyPresentation>: JourneyPresentation
{
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
    
    func materializeNested() -> (UIViewController, Any, (TrueP.P.Matter?, FalseP.P.Matter?)) {
        let (matter, result) = presentable.materialize()
        return (tupleUnnest(matter) as! UIViewController, tupleUnnest(transform(result)), matter)
    }
    
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
    
    public var configure: ((TrueP.P.Matter?, FalseP.P.Matter?), DisposeBag) -> () {
        get {
            switch storage {
            case let .first(presentation):
                return { (matter, bag) in
                    presentation.configure(matter.0!, bag)
                }
            case let .second(presentation):
                return { (matter, bag) in
                    presentation.configure(matter.1!, bag)
                }
            }
        }
        set {
            fatalError()
        }
    }
    
    public var onDismiss: (Error?) -> () {
        get {
            switch storage {
            case let .first(presentation):
                return presentation.onDismiss
            case let .second(presentation):
                return presentation.onDismiss
            }
        }
        set {
            fatalError()
        }
    }
    
    public var transform: ((TrueP.P.Result?, FalseP.P.Result?)) -> (TrueP.P.Result?, FalseP.P.Result?) {
        get {
            switch storage {
            case let .first(presentation):
                return {
                    return (presentation.transform($0.0!), $0.1)
                }
            case let .second(presentation):
                return {
                    return ($0.0, presentation.transform($0.1!))
                }
            }
        }
        set {
            fatalError()
        }
    }
    
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
  
  init(first : TrueP)  { storage = .first(first)   }
  init(second : FalseP) { storage = .second(second) }
}

@resultBuilder public struct JourneyBuilder {
    public static func buildEither<TrueP: JourneyPresentation, FalseP: JourneyPresentation>(first p: TrueP) -> ConditionalJourneyPresentation<TrueP, FalseP> {
        return ConditionalJourneyPresentation(first: p)
    }
    
    public static func buildEither<TrueP: JourneyPresentation, FalseP: JourneyPresentation>(second p: FalseP) -> ConditionalJourneyPresentation<TrueP, FalseP> {
        return ConditionalJourneyPresentation(second: p)
    }
    
    public static func buildBlock<TrueP: JourneyPresentation, FalseP: JourneyPresentation>(_ conditionalJourneyPresentation: ConditionalJourneyPresentation<TrueP, FalseP>) -> ConditionalJourneyPresentation<TrueP, FalseP> {
        return conditionalJourneyPresentation
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

extension FiniteSignal: JourneyResult, AnyJourneyResult {
    public var continueOrEndAnySignal: FiniteSignal<Any> {
        continueOrEndSignal.map { $0 as Any }
    }
    
    public var continueOrEndSignal: FiniteSignal<Value> {
        FiniteSignal { callback in
            return (self as! CoreSignal<Finite, Value>).onEvent { event in
                callback(event)
            }
        }
    }
}

extension Future: JourneyResult, AnyJourneyResult {
    public var continueOrEndAnySignal: FiniteSignal<Any> {
        continueOrEndSignal.map { $0 as Any }
    }
    
    public var continueOrEndSignal: FiniteSignal<Value> {
        FiniteSignal { callback in
            self.onValue { value in
                callback(.value(value))
            }.onError { error in
                callback(.end(error))
            }
            
            return NilDisposer()
        }
    }
}

public protocol JourneyResult: AnyObject {
    associatedtype Value
    var continueOrEndSignal: FiniteSignal<Value> { get }
}

public protocol AnyJourneyResult: AnyObject {
    var continueOrEndAnySignal: FiniteSignal<Any> { get }
}

extension UIViewController {
    @discardableResult public func present<J: JourneyPresentation>(_ presentation: J) -> AnyJourneyResult {
        let (matter, result) = presentation.presentable.materialize()
        
        let vc = matter as! UIViewController
        
        let transformedResult = presentation.transform(result) as! AnyJourneyResult
        
        if vc as? DismisserPresentable.DismisserViewController != nil {
            return Future<Void>(error: PresentError.dismissed).continueOrEndSignal
        } else if vc as? PoperPresentable.PoperViewController != nil {
            return Future<Void>(error: PresentError.poped).continueOrEndSignal
        } else if vc as? ContinuerPresentable.ContinuerViewController != nil {
            return Future<Void>().continueOrEndSignal
        }

        let bag = DisposeBag()
        
        let presenter = present(vc, style: presentation.style, options: presentation.options) { vc, bag -> () in
            presentation.configure(matter, bag)
        }.onResult {
            bag.dispose()
            presentation.onDismiss($0.error) }
        .onCancel {
            bag.dispose()
            presentation.onDismiss(PresentError.dismissed)
        }
                
        return Future<Void> { completion in
            bag += transformedResult.continueOrEndAnySignal.atError({ _ in
                presenter.cancel()
                completion(.success)
            }).onEnd {
                presenter.cancel()
                completion(.success)
            }
            
            return bag
        }
    }
    
    public func present<TrueJourney: JourneyPresentation, FalseJourney: JourneyPresentation>(_ presentation: ConditionalJourneyPresentation<TrueJourney, FalseJourney>) -> AnyJourneyResult {
        let (vc, result, matter) = presentation.materializeNested()
        
        if vc as? DismisserPresentable.DismisserViewController != nil {
            return Future<Void>(error: PresentError.dismissed)
        } else if vc as? PoperPresentable.PoperViewController != nil {
            return Future<Void>(error: PresentError.poped)
        } else if vc as? ContinuerPresentable.ContinuerViewController != nil {
            return Future<Void> { _ in
                return NilDisposer()
            }
        }
        
        let presenter = present(vc, style: presentation.style, options: presentation.options) { vc, bag -> () in
            presentation.configure(matter, bag)
        }.onResult { presentation.onDismiss($0.error) }
        .onCancel { presentation.onDismiss(PresentError.dismissed) }
                
        return (result as! AnyJourneyResult).continueOrEndAnySignal.atError({ _ in
            presenter.cancel()
        }).atEnd {
            presenter.cancel()
        }
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

public struct AnyJourneyPresentation<Matter, Result>: JourneyPresentation where Matter: UIViewController, Result: JourneyResult {
    public var presentable: AnyPresentable<Matter, Result>
    public var style: PresentationStyle
    public var options: PresentationOptions
    public var configure: (Matter, DisposeBag) -> ()
    public var onDismiss: (Error?) -> ()
    public var transform: (Result) -> Result
}

extension Presentation {
    public func journey<TrueJourney: JourneyPresentation, FalseJourney: JourneyPresentation, JR: JourneyResult>(
        @JourneyBuilder _ content: @escaping (_ value: P.Result.Value) -> ConditionalJourneyPresentation<TrueJourney, FalseJourney>
    ) -> some JourneyPresentation
    where P.Result == JR {
        AnyJourneyPresentation<UIViewController, FiniteSignal<Void>>(
            presentable: AnyPresentable {
                let (matter, result) = self.presentable.materialize()
                let transformedResult = transform(result)
                
                return (matter, FiniteSignal { callback in
                    let bag = DisposeBag()
                    self.configure(matter, bag)
                    
                    bag += transformedResult.continueOrEndSignal.onValueDisposePrevious { value in
                        matter.present(content(value)).continueOrEndAnySignal.onError { error in
                            if (error as? PresentError) == PresentError.poped {
                                callback(.end)
                            } else {
                                callback(.end(error))
                            }
                        }
                    }
                    
                    return bag
                })
            },
            style: style,
            options: options,
            configure: { _, _ in },
            onDismiss: onDismiss,
            transform: { $0 }
        )
    }

    public func journey<InnerJourney: JourneyPresentation, JR: JourneyResult>(
        @JourneyBuilder _ content: @escaping (_ value: P.Result.Value) -> InnerJourney
    ) -> some JourneyPresentation
    where P.Result == JR {
        AnyJourneyPresentation<UIViewController, FiniteSignal<Void>>(
            presentable: AnyPresentable {
                let (matter, result) = self.presentable.materialize()
                let transformedResult = transform(result)
                
                return (matter, FiniteSignal { callback in
                    let bag = DisposeBag()
                    self.configure(matter, bag)
                    
                    bag += transformedResult.continueOrEndSignal.onValueDisposePrevious { value in
                        matter.present(content(value)).continueOrEndAnySignal.onError { error in
                            if (error as? PresentError) == PresentError.poped {
                                callback(.end)
                            } else {
                                callback(.end(error))
                            }
                        }
                    }
                    
                    return bag
                })
            },
            style: style,
            options: options,
            configure: { _, _ in },
            onDismiss: onDismiss,
            transform: { $0 }
        )
    }
    
    public func journey() -> some JourneyPresentation {
        AnyJourneyPresentation<UIViewController, FiniteSignal<Void>>(
            presentable: AnyPresentable {
                let (matter, result) = self.presentable.materialize()
                let transformedResult = transform(result)
                
                return (matter, FiniteSignal { callback in
                    let bag = DisposeBag()
                    self.configure(matter, bag)
                    
                    if let disposable = transformedResult as? Disposable {
                        bag.add(disposable)
                    } else {
                        bag.hold(transformedResult as AnyObject)
                    }
                                        
                    return bag
                })
            },
            style: style,
            options: options,
            configure: { _, _ in },
            onDismiss: onDismiss,
            transform: { $0 }
        )
    }
}

public extension JourneyPresentation {
    /// Returns a new presentation where the result will be transformed using `transform`.
    func map(_ transform: @escaping (P.Result) -> P.Result) -> some JourneyPresentation {
        let presentationTransform = self.transform
        var new = self
        new.transform = { result in transform(presentationTransform(result)) }
        new.onDismiss = onDismiss

        return new
    }

    /// Returns a new presentation where the result will be transformed using `transform`.
    func map<Result: JourneyResult>(_ transform: @escaping (P.Result) -> Result) -> some JourneyPresentation where P.Matter: UIViewController {
        let presentationTransform = self.transform
        let anyPresentable = AnyPresentable(presentable, transform: { result in transform(presentationTransform(result)) })
        var new = AnyJourneyPresentation<P.Matter, Result>(presentable: anyPresentable, style: style, options: options, configure: configure, onDismiss: onDismiss, transform: { $0 })
        let onDismiss = self.onDismiss
        new.onDismiss = { onDismiss($0) }
        return new
    }

    /// Returns a new presentation where `callback` will be called when `self` is being presented.
    func onPresent(_ callback: @escaping () -> ()) -> some JourneyPresentation {
        return map {
            callback()
            return $0
        }
    }

    /// Returns a new presentation where `callback` will be called when `self` is being dismissed.
    func onDismiss(_ callback: @escaping () -> ()) -> some JourneyPresentation {
        let onDismiss = self.onDismiss
        var new = self

        new.onDismiss = {
            onDismiss($0)
            callback()
        }

        return new
    }

    /// Returns a new presentation where `callback` will be called with the value of a successful dismiss of `self`.
    func onValue<Value>(_ callback: @escaping (Value) -> ()) -> some JourneyPresentation where P.Result == Future<Value> {
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
    func onValue<Kind, Value>(_ callback: @escaping (Value) -> ()) -> some JourneyPresentation where P.Result == CoreSignal<Kind, Value> {
        return map { $0.atValue(callback) }
    }

    /// Returns a new presentation where `callback` will be called if `self` was dismiss with an error.
    func onError(_ callback: @escaping (Error) -> ()) -> some JourneyPresentation {
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

    /// Returns a new presentation where `configure` will be called at presentation.
    /// - Note: `self`'s `configure` will still be called before the provided `configure`.
    func addConfiguration(_ configure: @escaping (Self.P.Matter, DisposeBag) -> ()) -> some JourneyPresentation {
        var new = self
        let oldConfigure = new.configure
        new.configure = { vc, bag in
            oldConfigure(vc, bag)
            configure(vc, bag)
        }
        return new
    }
}
