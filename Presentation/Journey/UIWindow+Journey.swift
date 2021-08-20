//
//  UIWindow+Journey.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-16.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

extension UIWindow {
    public func present<J: JourneyPresentation>(_ presentation: J) -> Disposable {
        let (matter, result) = presentation.presentable.materialize()
        
        let vc = unsafeCastToUIViewController(tupleUnnest(matter))
        vc.updatePresentationTitle(for: presentation.presentable)
        
        let transformedResult = presentation.transform(result)
                
        let presentationEvent = PresentationEvent.willPresent(
            .init(vc.presentationDescription),
            from: .init(rootViewController?.presentationDescription ?? ""),
            styleName: "default"
        )

        presentablePresentationEventHandler(presentationEvent, #file, #function, #line)

        rootViewController = vc.embededInNavigationController(presentation.options)

        viewControllerWasPresented(vc)
        
        let bag = DisposeBag()
        
        presentation.configure(JourneyPresenter(viewController: rootViewController!, matter: matter, bag: bag, dismisser: { _ in
            bag.dispose()
        }))
        
        if let transformedResult = transformedResult as? FiniteJourneyResult {
            bag += transformedResult.plainJourneySignal.onValue { _ in }
        } else if let transformedResult = transformedResult as? FutureJourneyResult {
            bag += transformedResult.futureJourneyResult.onValue { _ in }
        }
        
        bag.hold(transformedResult as AnyObject)
        bag.hold(self)
        
        makeKeyAndVisible()
        
        return bag
    }
}
