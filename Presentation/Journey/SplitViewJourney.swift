//
//  SplitViewJourney.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-17.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

public class SplitViewJourney: JourneyPresentation {
    public var onDismiss: (Error?) -> ()
    
    public var style: PresentationStyle
    
    public var options: PresentationOptions
    
    public var transform: (Disposable) -> Disposable

    public var configure: (JourneyPresenter<P>) -> ()
    
    public let presentable: AnyPresentable<UISplitViewController, Disposable>
    
    public init<Primary: JourneyPresentation>(
        @JourneyBuilder _ primary: @escaping () -> Primary
    ) {
        let primaryPresentation = primary()
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let splitViewController = UISplitViewController()
            
            let (primaryViewController, primaryBag) = splitViewController.makeStandalone(primaryPresentation, dismisser: { dismisser($0) })
            
            let bag = DisposeBag()
            
            bag += primaryBag
            
            splitViewController.viewControllers = [primaryViewController]
            
            return (splitViewController, bag)
        })

        self.options = [.autoPop]
        self.onDismiss = { _ in }
        self.style = .default
        self.configure = { presenter in
            dismisser = { error in
                presenter.dismisser(error)
            }
        }
        self.transform = { $0 }
    }
}
