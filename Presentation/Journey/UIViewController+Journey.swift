//
//  UIViewController+Journey.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-15.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

protocol FiniteJourneyResult: AnyObject {
    var plainJourneySignal: CoreSignal<Finite, Any> { get }
}

extension CoreSignal: FiniteJourneyResult {
    var plainJourneySignal: CoreSignal<Finite, Any> {
        map { $0 as Any }
    }
}

protocol FutureJourneyResult: AnyObject {
    var futureJourneyResult: Future<Any> { get }
}

extension Future: FutureJourneyResult {
    var futureJourneyResult: Future<Any> {
        map { $0 as Any }
    }
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
    
    public func present<J: JourneyPresentation>(_ presentation: J) -> JourneyPresentResult<J> {
        let (matter, result) = presentation.presentable.materialize()
        
        let vc = unsafeCastToUIViewController(tupleUnnest(matter))
        vc.updatePresentationTitle(for: presentation.presentable)
        
        let transformedResult = presentation.transform(result)
                
        if vc as? DismisserPresentable.DismisserViewController != nil {
            return .shouldDismiss
        } else if vc as? PopperPresentable.PopperViewController != nil {
            return .shouldPop
        } else if vc as? ContinuerPresentable.ContinuerViewController != nil {
            return .shouldContinue
        }
        
        let notifyDismissCallbacker = Callbacker<Error?>()
                                
        let presenter = present(vc, style: presentation.style, options: presentation.options) { viewController, bag -> () in
            presentation.configure(JourneyPresenter(viewController: viewController, matter: matter, bag: bag, dismisser: { error in
                bag.dispose()
                notifyDismissCallbacker.callAll(with: error)
            }))
            
            if let transformedResult = transformedResult as? FiniteJourneyResult {
                bag += transformedResult.plainJourneySignal.onValue { _ in }
            } else if let transformedResult = transformedResult as? FutureJourneyResult {
                bag += transformedResult.futureJourneyResult.onValue { _ in }
            }
        }.onResult {
            notifyDismissCallbacker.callAll(with: $0.error)
        }
        .onCancel {
            notifyDismissCallbacker.callAll(with: JourneyError.cancelled)
        }
        
        notifyDismissCallbacker.future.onValue { error in
            presentation.onDismiss(error)
            presenter.cancel()
        }
        
        return .presented(transformedResult)
    }
}
