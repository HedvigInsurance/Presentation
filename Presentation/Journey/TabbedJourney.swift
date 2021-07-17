//
//  TabbedJourney.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-17.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Foundation
import Flow
import UIKit

extension UITabBarController {
    func makeTab<J: JourneyPresentation>(_ presentation: J, dismisser: @escaping (Error?) -> Void) -> (UIViewController, DisposeBag) {
        let (matter, result) = presentation.presentable.materialize()
        
        let vc = unsafeCastToUIViewController(tupleUnnest(matter))
        
        let transformedResult = presentation.transform(result)
                
        let presentationEvent = PresentationEvent.willPresent(
            .init("\(type(of: presentation.presentable))"),
            from: .init(""),
            styleName: "default"
        )

        presentablePresentationEventHandler(presentationEvent, #file, #function, #line)

        let embeddedVC = vc.embededInNavigationController(presentation.options)
                
        let bag = DisposeBag()
        
        presentation.configure(JourneyPresenter(viewController: embeddedVC, matter: matter, bag: bag, dismisser: dismisser))
        
        if let transformedResult = transformedResult as? FiniteJourneyResult {
            bag += transformedResult.plainJourneySignal.onValue { _ in }
        } else if let transformedResult = transformedResult as? FutureJourneyResult {
            bag += transformedResult.futureJourneyResult.onValue { _ in }
        }
        
        bag.hold(transformedResult as AnyObject)
        bag.hold(self)
        
        return (embeddedVC, bag)
    }
}

public class TabbedJourney: JourneyPresentation {
    public var onDismiss: (Error?) -> ()
    
    public var style: PresentationStyle
    
    public var options: PresentationOptions
    
    public var transform: (Disposable) -> Disposable

    public var configure: (JourneyPresenter<P>) -> ()
    
    public let presentable: AnyPresentable<UITabBarController, Disposable>
    
    public init<Tab1: JourneyPresentation>(
        @JourneyBuilder _ tab1: @escaping () -> Tab1
    ) {
        let tab1Presentation = tab1()
        
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let tabBarController = UITabBarController()
            
            let (viewController, bag) = tabBarController.makeTab(tab1Presentation, dismisser: { dismisser($0) })
            
            tabBarController.viewControllers = [viewController]
            
            return (tabBarController, bag)
        })

        self.options = [.defaults, .autoPop]
        self.onDismiss = { _ in }
        self.style = .default
        self.configure = { presenter in
            dismisser = { error in
                presenter.dismisser(error)
            }
        }
        self.transform = { $0 }
    }
    
    public init<Tab1: JourneyPresentation, Tab2: JourneyPresentation>(
        @JourneyBuilder _ tab1: @escaping () -> Tab1,
        @JourneyBuilder _ tab2: @escaping () -> Tab2
    ) {
        let tab1Presentation = tab1()
        let tab2Presentation = tab2()
        
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let tabBarController = UITabBarController()
            
            let bag = DisposeBag()

            let (tab1ViewController, tab1Bag) = tabBarController.makeTab(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, tab2Bag) = tabBarController.makeTab(tab2Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController]
            
            viewControllerWasPresented(tab1ViewController)
            viewControllerWasPresented(tab2ViewController)
            
            return (tabBarController, bag)
        })

        self.options = [.defaults, .autoPop]
        self.onDismiss = { _ in }
        self.style = .default
        self.configure = { presenter in
            dismisser = { error in
                presenter.dismisser(error)
            }
        }
        self.transform = { $0 }
    }
    
    public init<Tab1: JourneyPresentation, Tab2: JourneyPresentation, Tab3: JourneyPresentation>(
        @JourneyBuilder _ tab1: @escaping () -> Tab1,
        @JourneyBuilder _ tab2: @escaping () -> Tab2,
        @JourneyBuilder _ tab3: @escaping () -> Tab3
    ) {
        let tab1Presentation = tab1()
        let tab2Presentation = tab2()
        let tab3Presentation = tab3()
        
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let tabBarController = UITabBarController()
            
            let bag = DisposeBag()

            let (tab1ViewController, tab1Bag) = tabBarController.makeTab(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, tab2Bag) = tabBarController.makeTab(tab2Presentation, dismisser: { dismisser($0) })
            let (tab3ViewController, tab3Bag) = tabBarController.makeTab(tab3Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            bag += tab3Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController, tab3ViewController]
            
            viewControllerWasPresented(tab1ViewController)
            viewControllerWasPresented(tab2ViewController)
            viewControllerWasPresented(tab3ViewController)
            
            return (tabBarController, bag)
        })

        self.options = [.defaults, .autoPop]
        self.onDismiss = { _ in }
        self.style = .default
        self.configure = { presenter in
            dismisser = { error in
                presenter.dismisser(error)
            }
        }
        self.transform = { $0 }
    }
    
    public init<Tab1: JourneyPresentation, Tab2: JourneyPresentation, Tab3: JourneyPresentation, Tab4: JourneyPresentation>(
        @JourneyBuilder _ tab1: @escaping () -> Tab1,
        @JourneyBuilder _ tab2: @escaping () -> Tab2,
        @JourneyBuilder _ tab3: @escaping () -> Tab3,
        @JourneyBuilder _ tab4: @escaping () -> Tab4
    ) {
        let tab1Presentation = tab1()
        let tab2Presentation = tab2()
        let tab3Presentation = tab3()
        let tab4Presentation = tab4()
        
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let tabBarController = UITabBarController()
            
            let bag = DisposeBag()

            let (tab1ViewController, tab1Bag) = tabBarController.makeTab(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, tab2Bag) = tabBarController.makeTab(tab2Presentation, dismisser: { dismisser($0) })
            let (tab3ViewController, tab3Bag) = tabBarController.makeTab(tab3Presentation, dismisser: { dismisser($0) })
            let (tab4ViewController, tab4Bag) = tabBarController.makeTab(tab4Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            bag += tab3Bag
            bag += tab4Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController, tab3ViewController, tab4ViewController]
            
            viewControllerWasPresented(tab1ViewController)
            viewControllerWasPresented(tab2ViewController)
            viewControllerWasPresented(tab3ViewController)
            viewControllerWasPresented(tab4ViewController)
            
            return (tabBarController, bag)
        })

        self.options = [.defaults, .autoPop]
        self.onDismiss = { _ in }
        self.style = .default
        self.configure = { presenter in
            dismisser = { error in
                presenter.dismisser(error)
            }
        }
        self.transform = { $0 }
    }
    
    public init<Tab1: JourneyPresentation, Tab2: JourneyPresentation, Tab3: JourneyPresentation, Tab4: JourneyPresentation, Tab5: JourneyPresentation>(
        @JourneyBuilder _ tab1: @escaping () -> Tab1,
        @JourneyBuilder _ tab2: @escaping () -> Tab2,
        @JourneyBuilder _ tab3: @escaping () -> Tab3,
        @JourneyBuilder _ tab4: @escaping () -> Tab4,
        @JourneyBuilder _ tab5: @escaping () -> Tab5
    ) {
        let tab1Presentation = tab1()
        let tab2Presentation = tab2()
        let tab3Presentation = tab3()
        let tab4Presentation = tab4()
        let tab5Presentation = tab5()
        
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let tabBarController = UITabBarController()
            
            let bag = DisposeBag()

            let (tab1ViewController, tab1Bag) = tabBarController.makeTab(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, tab2Bag) = tabBarController.makeTab(tab2Presentation, dismisser: { dismisser($0) })
            let (tab3ViewController, tab3Bag) = tabBarController.makeTab(tab3Presentation, dismisser: { dismisser($0) })
            let (tab4ViewController, tab4Bag) = tabBarController.makeTab(tab4Presentation, dismisser: { dismisser($0) })
            let (tab5ViewController, tab5Bag) = tabBarController.makeTab(tab5Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            bag += tab3Bag
            bag += tab4Bag
            bag += tab5Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController, tab3ViewController, tab4ViewController, tab5ViewController]
            
            viewControllerWasPresented(tab1ViewController)
            viewControllerWasPresented(tab2ViewController)
            viewControllerWasPresented(tab3ViewController)
            viewControllerWasPresented(tab4ViewController)
            viewControllerWasPresented(tab5ViewController)
            
            return (tabBarController, bag)
        })

        self.options = [.defaults, .autoPop]
        self.onDismiss = { _ in }
        self.style = .default
        self.configure = { presenter in
            dismisser = { error in
                presenter.dismisser(error)
            }
        }
        self.transform = { $0 }
    }
    
    public init<Tab1: JourneyPresentation, Tab2: JourneyPresentation, Tab3: JourneyPresentation, Tab4: JourneyPresentation, Tab5: JourneyPresentation, Tab6: JourneyPresentation>(
        @JourneyBuilder _ tab1: @escaping () -> Tab1,
        @JourneyBuilder _ tab2: @escaping () -> Tab2,
        @JourneyBuilder _ tab3: @escaping () -> Tab3,
        @JourneyBuilder _ tab4: @escaping () -> Tab4,
        @JourneyBuilder _ tab5: @escaping () -> Tab5,
        @JourneyBuilder _ tab6: @escaping () -> Tab6
    ) {
        let tab1Presentation = tab1()
        let tab2Presentation = tab2()
        let tab3Presentation = tab3()
        let tab4Presentation = tab4()
        let tab5Presentation = tab5()
        let tab6Presentation = tab6()
        
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let tabBarController = UITabBarController()
            
            let bag = DisposeBag()

            let (tab1ViewController, tab1Bag) = tabBarController.makeTab(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, tab2Bag) = tabBarController.makeTab(tab2Presentation, dismisser: { dismisser($0) })
            let (tab3ViewController, tab3Bag) = tabBarController.makeTab(tab3Presentation, dismisser: { dismisser($0) })
            let (tab4ViewController, tab4Bag) = tabBarController.makeTab(tab4Presentation, dismisser: { dismisser($0) })
            let (tab5ViewController, tab5Bag) = tabBarController.makeTab(tab5Presentation, dismisser: { dismisser($0) })
            let (tab6ViewController, tab6Bag) = tabBarController.makeTab(tab6Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            bag += tab3Bag
            bag += tab4Bag
            bag += tab5Bag
            bag += tab6Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController, tab3ViewController, tab4ViewController, tab5ViewController, tab6ViewController]
            
            viewControllerWasPresented(tab1ViewController)
            viewControllerWasPresented(tab2ViewController)
            viewControllerWasPresented(tab3ViewController)
            viewControllerWasPresented(tab4ViewController)
            viewControllerWasPresented(tab5ViewController)
            viewControllerWasPresented(tab6ViewController)
            
            return (tabBarController, bag)
        })

        self.options = [.defaults, .autoPop]
        self.onDismiss = { _ in }
        self.style = .default
        self.configure = { presenter in
            dismisser = { error in
                presenter.dismisser(error)
            }
        }
        self.transform = { $0 }
    }
    
    public init<Tab1: JourneyPresentation, Tab2: JourneyPresentation, Tab3: JourneyPresentation, Tab4: JourneyPresentation, Tab5: JourneyPresentation, Tab6: JourneyPresentation, Tab7: JourneyPresentation>(
        @JourneyBuilder _ tab1: @escaping () -> Tab1,
        @JourneyBuilder _ tab2: @escaping () -> Tab2,
        @JourneyBuilder _ tab3: @escaping () -> Tab3,
        @JourneyBuilder _ tab4: @escaping () -> Tab4,
        @JourneyBuilder _ tab5: @escaping () -> Tab5,
        @JourneyBuilder _ tab6: @escaping () -> Tab6,
        @JourneyBuilder _ tab7: @escaping () -> Tab7
    ) {
        let tab1Presentation = tab1()
        let tab2Presentation = tab2()
        let tab3Presentation = tab3()
        let tab4Presentation = tab4()
        let tab5Presentation = tab5()
        let tab6Presentation = tab6()
        let tab7Presentation = tab7()
        
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let tabBarController = UITabBarController()
            
            let bag = DisposeBag()

            let (tab1ViewController, tab1Bag) = tabBarController.makeTab(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, tab2Bag) = tabBarController.makeTab(tab2Presentation, dismisser: { dismisser($0) })
            let (tab3ViewController, tab3Bag) = tabBarController.makeTab(tab3Presentation, dismisser: { dismisser($0) })
            let (tab4ViewController, tab4Bag) = tabBarController.makeTab(tab4Presentation, dismisser: { dismisser($0) })
            let (tab5ViewController, tab5Bag) = tabBarController.makeTab(tab5Presentation, dismisser: { dismisser($0) })
            let (tab6ViewController, tab6Bag) = tabBarController.makeTab(tab6Presentation, dismisser: { dismisser($0) })
            let (tab7ViewController, tab7Bag) = tabBarController.makeTab(tab7Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            bag += tab3Bag
            bag += tab4Bag
            bag += tab5Bag
            bag += tab6Bag
            bag += tab7Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController, tab3ViewController, tab4ViewController, tab5ViewController, tab6ViewController, tab7ViewController]
            
            viewControllerWasPresented(tab1ViewController)
            viewControllerWasPresented(tab2ViewController)
            viewControllerWasPresented(tab3ViewController)
            viewControllerWasPresented(tab4ViewController)
            viewControllerWasPresented(tab5ViewController)
            viewControllerWasPresented(tab6ViewController)
            viewControllerWasPresented(tab7ViewController)
            
            return (tabBarController, bag)
        })

        self.options = [.defaults, .autoPop]
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
