//
//  Conditional.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-15.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

public struct ConditionalJourneyPresentable<TrueP: Presentable, FalseP: Presentable>: Presentable, PresentableIdentifierExpressible {
    public var presentableIdentifier: PresentableIdentifier {
        switch self.storage {
        case let .first(presentable):
            return (presentable as? PresentableIdentifierExpressible)?.presentableIdentifier ?? PresentableIdentifier("\(type(of: presentable))")
        case let .second(presentable):
            return (presentable as? PresentableIdentifierExpressible)?.presentableIdentifier ?? PresentableIdentifier("\(type(of: presentable))")
        }
    }
    
    enum Storage {
      case first(TrueP)
      case second(FalseP)
    }
      
    let storage: Storage
    
    init(first: TrueP)  { storage = .first(first) }
    init(second: FalseP) { storage = .second(second) }
    
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

public struct ConditionalJourneyPresentation<TrueP: JourneyPresentation, FalseP: JourneyPresentation>: JourneyPresentation
{
    public var style: PresentationStyle
    public var options: PresentationOptions
    public var configure: (JourneyPresenter<P>) -> ()
    public var onDismiss: (Error?) -> ()
    public var transform: ((TrueP.P.Result?, FalseP.P.Result?)) -> (TrueP.P.Result?, FalseP.P.Result?)
    public var presentable: ConditionalJourneyPresentable<TrueP.P, FalseP.P>
    
    init(first: TrueP)  {
        self.transform = { result in (first.transform(result.0!), nil) }
        self.configure = { journeyPresenter in
            let presenter = JourneyPresenter<TrueP.P>(
                viewController: journeyPresenter.viewController,
                matter: journeyPresenter.matter.0!,
                bag: journeyPresenter.bag,
                dismisser: journeyPresenter.dismisser
            )
            first.configure(presenter)
        }
        self.onDismiss = { error in
            first.onDismiss(error)
        }
        
        self.presentable = ConditionalJourneyPresentable(first: first.presentable)
        self.options = first.options
        self.style = first.style
    }

    init(second: FalseP) {
        self.transform = { result in (nil, second.transform(result.1!)) }
        self.configure = { journeyPresenter in
            let presenter = JourneyPresenter<FalseP.P>(
                viewController: journeyPresenter.viewController,
                matter: journeyPresenter.matter.1!,
                bag: journeyPresenter.bag,
                dismisser: journeyPresenter.dismisser
            )
            second.configure(presenter)
        }
        self.onDismiss = { error in
            second.onDismiss(error)
        }
        
        self.presentable = ConditionalJourneyPresentable(second: second.presentable)
        self.options = second.options
        self.style = second.style
    }
}
