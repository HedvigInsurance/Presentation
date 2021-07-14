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

protocol ConditionalFindNestedPresentable {
    var findNestedPresentable: AnyPresentable<UIViewController, Any> { get }
}

public struct ConditionalJourneyPresentation<TrueP: JourneyPresentation, FalseP: JourneyPresentation>: JourneyPresentation, ConditionalFindNestedPresentable
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
    
    var findNestedPresentable: AnyPresentable<UIViewController, Any> {
        switch storage {
        case let .first(presentation):
            return AnyPresentable {
                let (matter, result) = presentation.presentable.materialize()
                return (tupleUnnest(matter) as! UIViewController, tupleUnnest(result))
            }
        case let .second(presentation):
            return AnyPresentable {
                let (matter, result) = presentation.presentable.materialize()
                return (tupleUnnest(matter) as! UIViewController, tupleUnnest(result))
            }
        }
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
    
    public var onDismiss: (Error?) -> () {
        switch storage {
        case let .first(presentation):
            return presentation.onDismiss
        case let .second(presentation):
            return presentation.onDismiss
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
    public func present<J: JourneyPresentation>(_ presentation: J) -> FiniteSignal<Void> where J.P.Matter: UIViewController, J.P.Result: JourneyResult {
        let (vc, result) = presentation.presentable.materialize()
        
        if vc as? DismisserPresentable.DismisserViewController != nil {
            return Future<Void>(error: PresentError.dismissed).continueOrEndSignal
        } else if vc as? PoperPresentable.PoperViewController != nil {
            return Future<Void>(error: PresentError.poped).continueOrEndSignal
        } else if vc as? ContinuerPresentable.ContinuerViewController != nil {
            return Future<Void>().continueOrEndSignal
        }

        let presenter = present(vc, style: presentation.style, options: presentation.options) { vc, bag -> () in
            presentation.configure(vc, bag)
        }.onResult { presentation.onDismiss($0.error) }
        .onCancel { presentation.onDismiss(PresentError.dismissed) }

        return result.continueOrEndSignal.atError({ _ in
            presenter.cancel()
        }).atEnd {
            presenter.cancel()
        }.toVoid()
    }
    
    public func present<TrueJourney: JourneyPresentation, FalseJourney: JourneyPresentation>(_ presentation: ConditionalJourneyPresentation<TrueJourney, FalseJourney>) -> AnyJourneyResult {
        let (vc, result) = presentation.findNestedPresentable.materialize()
        
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
            // cant configure
        }.onResult { presentation.onDismiss($0.error) }
        .onCancel { presentation.onDismiss(PresentError.dismissed) }
        
        let anyJourneyResult = result as! AnyJourneyResult

        return anyJourneyResult.continueOrEndAnySignal.atError({ _ in
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

    /// The configuration to apply just before presenting `self`.
    var configure: (P.Matter, DisposeBag) -> () { get }

    /// A callback that will be called once presentaion is done, either with `nil` if normally dismissed, or with an error if not.
    var onDismiss: (Error?) -> () { get }
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

    public init() {}
}

public struct AnyJourneyPresentation<Matter, Result>: JourneyPresentation, ViewControllerJourneyPresentation where Matter: UIViewController, Result: JourneyResult {
    public var presentable: AnyPresentable<Matter, Result>
    public var style: PresentationStyle
    public var options: PresentationOptions
    public var configure: (Matter, DisposeBag) -> ()
    public var onDismiss: (Error?) -> ()
}

public protocol ViewControllerJourneyPresentation: JourneyPresentation where P.Matter: UIViewController, P.Result: JourneyResult {}

extension Presentation {
    public func journey<TrueJourney: JourneyPresentation, FalseJourney: JourneyPresentation, JR: JourneyResult>(
        @JourneyBuilder _ content: @escaping (_ value: P.Result.Value) -> ConditionalJourneyPresentation<TrueJourney, FalseJourney>
    ) -> some ViewControllerJourneyPresentation
    where P.Matter: UIViewController, P.Result == JR {
        AnyJourneyPresentation<UIViewController, FiniteSignal<Void>>(
            presentable: AnyPresentable {
                let (matter, result) = self.presentable.materialize()
                
                return (matter, FiniteSignal { callback in
                    let bag = DisposeBag()
                    
                    bag += result.continueOrEndSignal.onValueDisposePrevious { value in
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
            onDismiss: onDismiss
        )
    }

    public func journey<InnerJourney: JourneyPresentation, InnerJourneyResult: JourneyResult, JR: JourneyResult>(
        @JourneyBuilder _ content: @escaping (_ value: P.Result.Value) -> InnerJourney
    ) -> some ViewControllerJourneyPresentation
    where P.Matter: UIViewController, P.Result == JR, InnerJourney.P.Matter: UIViewController, InnerJourney.P.Result == InnerJourneyResult {
        AnyJourneyPresentation<UIViewController, FiniteSignal<Void>>(
            presentable: AnyPresentable {
                let (matter, result) = self.presentable.materialize()

                return (matter, FiniteSignal { callback in
                    let bag = DisposeBag()
                    
                    bag += result.continueOrEndSignal.onValueDisposePrevious { value in
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
            onDismiss: onDismiss
        )
    }
}
