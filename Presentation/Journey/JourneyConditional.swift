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

public struct ConditionalJourneyPresentable<TrueP: Presentable, FalseP: Presentable>: Presentable {
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
            
    public var configure: (JourneyPresenter<P>) -> ()
    public var onDismiss: (Error?) -> ()
    
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
        self.transform = { [unowned self] result in
            switch self.storage {
            case let .first(presentation):
                return (presentation.transform(result.0!), nil)
            case let .second(presentation):
                return (nil, presentation.transform(result.1!))
            }
        }
        
        self.configure = { [unowned self] journeyPresenter in
            switch self.storage {
            case let .first(presentation):
                let presenter = JourneyPresenter<TrueP.P>(
                    viewController: journeyPresenter.viewController,
                    matter: journeyPresenter.matter.0!,
                    bag: journeyPresenter.bag,
                    dismisser: journeyPresenter.dismisser
                )
                presentation.configure(presenter)
            case let .second(presentation):
                let presenter = JourneyPresenter<FalseP.P>(
                    viewController: journeyPresenter.viewController,
                    matter: journeyPresenter.matter.1!,
                    bag: journeyPresenter.bag,
                    dismisser: journeyPresenter.dismisser
                )
                presentation.configure(presenter)
            }
        }
        
        self.onDismiss = { [unowned self] error in
            switch self.storage {
            case let .first(presentation):
                presentation.onDismiss(error)
            case let .second(presentation):
                presentation.onDismiss(error)
            }
        }
    }
  
    init(first: TrueP)  {
        storage = .first(first)
        self.transform = { $0 }
        self.configure = { _ in }
        self.onDismiss = { _ in }
        setupDefaults()
    }

    init(second: FalseP) {
        storage = .second(second)
        self.transform = { $0 }
        self.configure = { _ in }
        self.onDismiss = { _ in }
        setupDefaults()
    }
}
