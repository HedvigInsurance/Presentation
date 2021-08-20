//
//  TabbedJourney.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-17.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

extension UIViewController {
    func makeStandalone<J: JourneyPresentation>(
        _ presentation: J,
        dismisser: @escaping (Error?) -> Void
    ) -> (
        viewController: UIViewController,
        configurer: () -> Void,
        bag: DisposeBag
    ) {
        let (matter, result) = presentation.presentable.materialize()
        
        let vc = unsafeCastToUIViewController(tupleUnnest(matter))
        vc.updatePresentationTitle(for: presentation.presentable)
        
        let transformedResult = presentation.transform(result)

        let embeddedVC = vc.embededInNavigationController(presentation.options)
                
        let bag = DisposeBag()
        
        if let transformedResult = transformedResult as? FiniteJourneyResult {
            bag += transformedResult.plainJourneySignal.onValue { _ in }
        } else if let transformedResult = transformedResult as? FutureJourneyResult {
            bag += transformedResult.futureJourneyResult.onValue { _ in }
        }
        
        bag.hold(transformedResult as AnyObject)
        bag.hold(self)
        
        return (embeddedVC, {
            presentation.configure(JourneyPresenter(viewController: embeddedVC, matter: matter, bag: bag, dismisser: dismisser))
        }, bag)
    }
}

public struct TabbedJourney: JourneyPresentation {
    public var onDismiss: (Error?) -> ()
    
    public var style: PresentationStyle
    
    public var options: PresentationOptions
    
    public var transform: (Disposable) -> Disposable

    public var configure: (JourneyPresenter<P>) -> ()
    
    public let presentable: AnyPresentable<UITabBarController, Disposable>
    
    static func becameActive(_ from: UIViewController, activeViewController: UIViewController) {
        viewControllerWasPresented(activeViewController)

        let presentationEvent = PresentationEvent.willPresent(
            .init(activeViewController.presentationDescription),
            from: .init(from.presentationDescription),
            styleName: "default"
        )

        presentablePresentationEventHandler(presentationEvent, #file, #function, #line)
    }
    
    static func resignedActive(_ from: UIViewController, activeViewController: UIViewController) {
        let presentationEvent = PresentationEvent.didCancel(
            .init(activeViewController.presentationDescription),
            from: .init(from.presentationDescription)
        )

        presentablePresentationEventHandler(presentationEvent, #file, #function, #line)
    }
    
    static func activeHandler(_ tabBarController: UITabBarController) -> Disposable {
        tabBarController.signal(for: \.selectedViewController).atOnce().compactMap { viewController in
            viewController
        }.onValueDisposePrevious { viewController in
            guard let navigationController = viewController as? UINavigationController, let lastViewController = navigationController.viewControllers.last else {
                Self.becameActive(tabBarController, activeViewController: viewController)
                
                return Disposer {
                    Self.resignedActive(tabBarController, activeViewController: viewController)
                }
            }
            
            Self.becameActive(tabBarController, activeViewController: lastViewController)
            
            return Disposer {
                Self.resignedActive(tabBarController, activeViewController: lastViewController)
            }
        }
    }
    
    public init<Tab1: JourneyPresentation>(
        @JourneyBuilder _ tab1: @escaping () -> Tab1,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.autoPop]
    ) {
        let tab1Presentation = tab1()
        
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let tabBarController = UITabBarController()
            
            let (viewController, configurer, bag) = tabBarController.makeStandalone(tab1Presentation, dismisser: { dismisser($0) })
            
            tabBarController.viewControllers = [viewController].filter { $0 as? ContinuerPresentable.ContinuerViewController == nil }
            configurer()
            
            return (tabBarController, bag)
        })

        self.options = options
        self.onDismiss = { _ in }
        self.style = style
        self.configure = { presenter in
            presenter.bag += Self.activeHandler(presenter.matter)
            
            dismisser = { error in
                presenter.dismisser(error)
            }
        }
        self.transform = { $0 }
    }
    
    public init<Tab1: JourneyPresentation, Tab2: JourneyPresentation>(
        @JourneyBuilder _ tab1: @escaping () -> Tab1,
        @JourneyBuilder _ tab2: @escaping () -> Tab2,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.autoPop]
    ) {
        let tab1Presentation = tab1()
        let tab2Presentation = tab2()
        
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let tabBarController = UITabBarController()
            
            let bag = DisposeBag()

            let (tab1ViewController, configurer1, tab1Bag) = tabBarController.makeStandalone(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, configurer2, tab2Bag) = tabBarController.makeStandalone(tab2Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController].filter { $0 as? ContinuerPresentable.ContinuerViewController == nil }
            
            configurer1()
            configurer2()
            
            return (tabBarController, bag)
        })

        self.options = options
        self.onDismiss = { _ in }
        self.style = style
        self.configure = { presenter in
            presenter.bag += Self.activeHandler(presenter.matter)
            
            dismisser = { error in
                presenter.dismisser(error)
            }
        }
        self.transform = { $0 }
    }
    
    public init<Tab1: JourneyPresentation, Tab2: JourneyPresentation, Tab3: JourneyPresentation>(
        @JourneyBuilder _ tab1: @escaping () -> Tab1,
        @JourneyBuilder _ tab2: @escaping () -> Tab2,
        @JourneyBuilder _ tab3: @escaping () -> Tab3,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.autoPop]
    ) {
        let tab1Presentation = tab1()
        let tab2Presentation = tab2()
        let tab3Presentation = tab3()
        
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let tabBarController = UITabBarController()
            
            let bag = DisposeBag()

            let (tab1ViewController, configurer1, tab1Bag) = tabBarController.makeStandalone(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, configurer2, tab2Bag) = tabBarController.makeStandalone(tab2Presentation, dismisser: { dismisser($0) })
            let (tab3ViewController, configurer3, tab3Bag) = tabBarController.makeStandalone(tab3Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            bag += tab3Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController, tab3ViewController].filter { $0 as? ContinuerPresentable.ContinuerViewController == nil }
            
            configurer1()
            configurer2()
            configurer3()
            
            return (tabBarController, bag)
        })

        self.options = options
        self.onDismiss = { _ in }
        self.style = style
        self.configure = { presenter in
            presenter.bag += Self.activeHandler(presenter.matter)
            
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
        @JourneyBuilder _ tab4: @escaping () -> Tab4,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.autoPop]
    ) {
        let tab1Presentation = tab1()
        let tab2Presentation = tab2()
        let tab3Presentation = tab3()
        let tab4Presentation = tab4()
        
        var dismisser: (Error?) -> Void = { _ in }
        
        self.presentable = AnyPresentable(materialize: {
            let tabBarController = UITabBarController()
            
            let bag = DisposeBag()

            let (tab1ViewController, configurer1, tab1Bag) = tabBarController.makeStandalone(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, configurer2, tab2Bag) = tabBarController.makeStandalone(tab2Presentation, dismisser: { dismisser($0) })
            let (tab3ViewController, configurer3, tab3Bag) = tabBarController.makeStandalone(tab3Presentation, dismisser: { dismisser($0) })
            let (tab4ViewController, configurer4, tab4Bag) = tabBarController.makeStandalone(tab4Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            bag += tab3Bag
            bag += tab4Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController, tab3ViewController, tab4ViewController].filter { $0 as? ContinuerPresentable.ContinuerViewController == nil }
            
            configurer1()
            configurer2()
            configurer3()
            configurer4()
            
            return (tabBarController, bag)
        })

        self.options = options
        self.onDismiss = { _ in }
        self.style = style
        self.configure = { presenter in
            presenter.bag += Self.activeHandler(presenter.matter)
            
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
        @JourneyBuilder _ tab5: @escaping () -> Tab5,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.autoPop]
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

            let (tab1ViewController, configurer1, tab1Bag) = tabBarController.makeStandalone(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, configurer2, tab2Bag) = tabBarController.makeStandalone(tab2Presentation, dismisser: { dismisser($0) })
            let (tab3ViewController, configurer3, tab3Bag) = tabBarController.makeStandalone(tab3Presentation, dismisser: { dismisser($0) })
            let (tab4ViewController, configurer4, tab4Bag) = tabBarController.makeStandalone(tab4Presentation, dismisser: { dismisser($0) })
            let (tab5ViewController, configurer5, tab5Bag) = tabBarController.makeStandalone(tab5Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            bag += tab3Bag
            bag += tab4Bag
            bag += tab5Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController, tab3ViewController, tab4ViewController, tab5ViewController].filter { $0 as? ContinuerPresentable.ContinuerViewController == nil }
            
            configurer1()
            configurer2()
            configurer3()
            configurer4()
            configurer5()
            
            return (tabBarController, bag)
        })

        self.options = options
        self.onDismiss = { _ in }
        self.style = style
        self.configure = { presenter in
            presenter.bag += Self.activeHandler(presenter.matter)
            
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
        @JourneyBuilder _ tab6: @escaping () -> Tab6,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.autoPop]
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

            let (tab1ViewController, configurer1, tab1Bag) = tabBarController.makeStandalone(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, configurer2, tab2Bag) = tabBarController.makeStandalone(tab2Presentation, dismisser: { dismisser($0) })
            let (tab3ViewController, configurer3, tab3Bag) = tabBarController.makeStandalone(tab3Presentation, dismisser: { dismisser($0) })
            let (tab4ViewController, configurer4, tab4Bag) = tabBarController.makeStandalone(tab4Presentation, dismisser: { dismisser($0) })
            let (tab5ViewController, configurer5, tab5Bag) = tabBarController.makeStandalone(tab5Presentation, dismisser: { dismisser($0) })
            let (tab6ViewController, configurer6, tab6Bag) = tabBarController.makeStandalone(tab6Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            bag += tab3Bag
            bag += tab4Bag
            bag += tab5Bag
            bag += tab6Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController, tab3ViewController, tab4ViewController, tab5ViewController, tab6ViewController].filter { $0 as? ContinuerPresentable.ContinuerViewController == nil }
            
            configurer1()
            configurer2()
            configurer3()
            configurer4()
            configurer5()
            configurer6()
            
            return (tabBarController, bag)
        })

        self.options = options
        self.onDismiss = { _ in }
        self.style = style
        self.configure = { presenter in
            presenter.bag += Self.activeHandler(presenter.matter)
            
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
        @JourneyBuilder _ tab7: @escaping () -> Tab7,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.autoPop]
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

            let (tab1ViewController, configurer1, tab1Bag) = tabBarController.makeStandalone(tab1Presentation, dismisser: { dismisser($0) })
            let (tab2ViewController, configurer2, tab2Bag) = tabBarController.makeStandalone(tab2Presentation, dismisser: { dismisser($0) })
            let (tab3ViewController, configurer3, tab3Bag) = tabBarController.makeStandalone(tab3Presentation, dismisser: { dismisser($0) })
            let (tab4ViewController, configurer4, tab4Bag) = tabBarController.makeStandalone(tab4Presentation, dismisser: { dismisser($0) })
            let (tab5ViewController, configurer5, tab5Bag) = tabBarController.makeStandalone(tab5Presentation, dismisser: { dismisser($0) })
            let (tab6ViewController, configurer6, tab6Bag) = tabBarController.makeStandalone(tab6Presentation, dismisser: { dismisser($0) })
            let (tab7ViewController, configurer7, tab7Bag) = tabBarController.makeStandalone(tab7Presentation, dismisser: { dismisser($0) })
            
            bag += tab1Bag
            bag += tab2Bag
            bag += tab3Bag
            bag += tab4Bag
            bag += tab5Bag
            bag += tab6Bag
            bag += tab7Bag
            
            tabBarController.viewControllers = [tab1ViewController, tab2ViewController, tab3ViewController, tab4ViewController, tab5ViewController, tab6ViewController, tab7ViewController].filter { $0 as? ContinuerPresentable.ContinuerViewController == nil }
            
            configurer1()
            configurer2()
            configurer3()
            configurer4()
            configurer5()
            configurer6()
            configurer7()
            
            return (tabBarController, bag)
        })

        self.options = options
        self.onDismiss = { _ in }
        self.style = style
        self.configure = { presenter in
            presenter.bag += Self.activeHandler(presenter.matter)
            
            dismisser = { error in
                presenter.dismisser(error)
            }
        }
        self.transform = { $0 }
    }
}
