//
//  RestorableJourneyPoint.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-17.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

public protocol RestorableJourneyPointIdentifier: RawRepresentable where RawValue: StringProtocol {}

var activityIdentifier: String {
    "journeyPoint"
}

extension NSUserActivity {
    public func journeyPoint<Identifier: RestorableJourneyPointIdentifier>() -> Identifier? {
        if let userInfo = userInfo, let journeyPoint = userInfo[activityIdentifier] as? Identifier.RawValue {
            return Identifier(rawValue: journeyPoint)
        }
    
        return nil
    }
}

public struct RestorableJourneyPoint<InnerJourney: JourneyPresentation>: JourneyPresentation {
    public var onDismiss: (Error?) -> ()
    
    public var style: PresentationStyle
    
    public var options: PresentationOptions
    
    public var transform: (InnerJourney.P.Result) -> InnerJourney.P.Result
    
    public var configure: (JourneyPresenter<P>) -> ()
    
    public let presentable: InnerJourney.P
    
    public init<RJ: RestorableJourneyPointIdentifier>(
        identifier: RJ,
        @JourneyBuilder _ content: @escaping () -> InnerJourney
    ) {
        var viewController: UIViewController? = nil
        var previousJourneyPoint: RJ? = nil
        
        @available(iOS 13, *)
        func getUserActivity() -> NSUserActivity? {
            return viewController?.view.window?.windowScene?.userActivity
        }
        
        @available(iOS 13, *)
        func setIdentifier(to: RJ) {
            let currentUserActivity = getUserActivity()
            previousJourneyPoint = currentUserActivity?.journeyPoint()
            currentUserActivity?.addUserInfoEntries(from: [activityIdentifier: identifier.rawValue])
            viewController?.view.window?.windowScene?.userActivity = currentUserActivity
        }
        
        func handleDismiss() {
            if #available(iOS 13, *) {
                if let journeyPoint: RJ = getUserActivity()?.journeyPoint(), journeyPoint == identifier, let previousJourneyPoint = previousJourneyPoint {
                    setIdentifier(to: previousJourneyPoint)
                }
            }
            
            previousJourneyPoint = nil
            viewController = nil
        }
        
        let presentation = content().addConfiguration { presenter in
            viewController = (presenter.viewController as? UINavigationController)?.viewControllers.first ?? presenter.viewController
            
            if #available(iOS 13, *) {
                presenter.bag += viewController?.view.didMoveToWindowSignal.onFirstValue({ _ in
                    setIdentifier(to: identifier)
                })
            }
        }.onError { _ in
            handleDismiss()
        }.onDismiss {
            handleDismiss()
        }
        
        self.presentable = presentation.presentable
        self.style = presentation.style
        self.options = presentation.options
        self.transform = presentation.transform
        self.configure = presentation.configure
        self.onDismiss = presentation.onDismiss
    }
}
