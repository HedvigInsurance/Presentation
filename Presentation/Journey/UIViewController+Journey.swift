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
        
        let transformedResult = presentation.transform(result)
                
        if vc as? DismisserPresentable.DismisserViewController != nil {
            return .shouldDismiss
        } else if vc as? PoperPresentable.PoperViewController != nil {
            return .shouldPop
        } else if vc as? ContinuerPresentable.ContinuerViewController != nil {
            return .shouldContinue
        }
                
        present(vc, style: presentation.style, options: presentation.options) { _, bag -> () in
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
