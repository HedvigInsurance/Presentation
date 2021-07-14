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

public struct OptionalJourney<RealJourney: JourneyPresentation> {
    let journey: RealJourney?
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
    
    public static func buildBlock<P: JourneyPresentation>(_ optionalJourney: OptionalJourney<P>) -> OptionalJourney<P> {
        return optionalJourney
    }
    
    public static func buildOptional<P: JourneyPresentation>(_ p: P?) -> OptionalJourney<P> {
        OptionalJourney(journey: p)
    }
}

extension FiniteSignal: JourneyResult {
    public var continueOrEndSignal: FiniteSignal<Value> {
        FiniteSignal { callback in
            return self.onValue { value in
                callback(.value(value))
            }
        }
    }
}

extension Future: JourneyResult {
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

public protocol JourneyResult: class {
    associatedtype Value
    var continueOrEndSignal: FiniteSignal<Value> { get }
}

extension UIViewController {
    public func present<J: JourneyPresentation>(_ presentation: J) -> J.P.Result where J.P.Matter: UIViewController {
        let (vc, result) = presentation.presentable.materialize()

        present(vc, style: presentation.style, options: presentation.options) { vc, bag -> () in
            presentation.configure(vc, bag)
        }.onResult { presentation.onDismiss($0.error) }
         .onCancel { presentation.onDismiss(PresentError.dismissed) }

        return result
    }

    public func present<J: JourneyPresentation>(_ presentation: J) -> Future<Void> where J.P.Matter: UIViewController, J.P.Result: JourneyResult {
        let (vc, result) = presentation.presentable.materialize()

        let presenter = present(vc, style: presentation.style, options: presentation.options) { vc, bag -> () in
            presentation.configure(vc, bag)
        }.onResult { presentation.onDismiss($0.error) }
        .onCancel { presentation.onDismiss(PresentError.dismissed) }

        return result.continueOrEndSignal.future.onError({ _ in
            presenter.cancel()
        }).onValue({ _ in
            presenter.cancel()
        }).toVoid()
    }
    
    public func present<TrueP: JourneyPresentation, FalseP: JourneyPresentation>(
        _ presentation: ConditionalJourneyPresentation<TrueP, FalseP>
    ) -> Either<AnyJourneyPresentation<TrueP.P.Matter, TrueP.P.Result>, AnyJourneyPresentation<FalseP.P.Matter, FalseP.P.Result>> where TrueP.P.Matter: UIViewController, TrueP.P.Result: JourneyResult, FalseP.P.Matter: UIViewController, FalseP.P.Result: JourneyResult {
        switch presentation.storage {
        case let .first(presentation):
            return .left(
                AnyJourneyPresentation(presentable: AnyPresentable(materialize: {
                    let ((matter, result), _) = presentation.presentable.materialize()
                    
                    return (matter, result)
                }), style: presentation.style, options: presentation.options, configure: presentation.configure, onDismiss: presentation.onDismiss)
            )
        case let .second(presentation):
            return .right(
                AnyJourneyPresentation(presentable: AnyPresentable(materialize: {
                    let (_, (matter, result)) = presentation.presentable.materialize()
                    return (matter, result)
                }), style: presentation.style, options: presentation.options, configure: presentation.configure, onDismiss: presentation.onDismiss)
            )
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
    public func materialize() -> (UIViewController, Future<Void>) {
        fatalError("Does nothing")
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

    public var configure: (UIViewController, DisposeBag) -> () = { _, _  in }

    public var onDismiss: (Error?) -> () = { _ in }

    public init() {}
}

public struct PoperPresentable: Presentable {
    public func materialize() -> (UIViewController, Future<Void>) {
        fatalError("Does nothing")
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

    public var configure: (UIViewController, DisposeBag) -> () = { _, _  in }

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
        AnyJourneyPresentation<UIViewController, Future<Void>>(
            presentable: AnyPresentable {
                let (matter, result) = self.presentable.materialize()

                return (matter, Future { completion in
                    let bag = DisposeBag()

                    bag += result.continueOrEndSignal.onValue({ value in
                        
                        matter.present(content(value))
                        
//                        switch content(value).content {
//                        case let .first(presentation):
//                            if presentation.presentable as? DismisserPresentable != nil {
//                                completion(.failure(PresentError.dismissed))
//                            } else if presentation.presentable as? PoperPresentable != nil {
//                                completion(.success)
//                            }  else {
//                                matter.present(presentation).onError { error in
//                                    completion(.failure(error))
//                                }
//                            }
//
//                        case let .second(presentation):
//                            if presentation.presentable as? DismisserPresentable != nil {
//                                completion(.failure(PresentError.dismissed))
//                            } else if presentation.presentable as? PoperPresentable != nil {
//                                completion(.success)
//                            } else {
//                                matter.present(presentation).onError { error in
//                                    completion(.failure(error))
//                                }
//                            }
//                        }
                    })
                    
                    return bag
                })
            },
            style: style,
            options: options,
            configure: { _, _ in },
            onDismiss: onDismiss
        )
    }
    
    public func journey<RealJourney: JourneyPresentation, JR: JourneyResult>(
        @JourneyBuilder _ content: @escaping (_ value: P.Result.Value) -> OptionalJourney<RealJourney>
    ) -> some JourneyPresentation
    where P.Matter: UIViewController, P.Result == JR {
        AnyJourneyPresentation<UIViewController, Future<Void>>(
            presentable: AnyPresentable {
                let (matter, result) = self.presentable.materialize()

                return (matter, Future { completion in
                    let bag = DisposeBag()

                    bag += result.continueOrEndSignal.onValue({ value in
                        guard let presentation = content(value).journey else {
                            return
                        }
                        
                        if presentation.presentable as? DismisserPresentable != nil {
                            completion(.failure(PresentError.dismissed))
                        } else if presentation.presentable as? PoperPresentable != nil {
                            completion(.success)
                        } else {
//                            matter.present(presentation).onError { error in
//                                completion(.failure(error))
//                            }
                        }
                    })
                    
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
        AnyJourneyPresentation<UIViewController, Future<Void>>(
            presentable: AnyPresentable {
                let (matter, result) = self.presentable.materialize()

                return (matter, Future { completion in
                    let bag = DisposeBag()

                    bag += result.continueOrEndSignal.onValue({ value in
                        let presentation = content(value)
                        
                        if presentation.presentable as? DismisserPresentable != nil {
                            completion(.failure(PresentError.dismissed))
                        } else if presentation.presentable as? PoperPresentable != nil {
                            completion(.success)
                        } else {
                            matter.present(presentation).onError { error in
                                completion(.failure(error))
                            }
                        }
                    })
                    
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
