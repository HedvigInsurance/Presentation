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

func unsafeCastToUIViewController(_ any: Any?) -> UIViewController {
    if let vc = any as? UIViewController {
        return vc
    }
    
    fatalError("Matter of JourneyPresentation must always inherit from UIViewController")
}

public enum JourneyPresentResult<J: JourneyPresentation> {
    case presented(_ result: J.P.Result)
    case shouldDismiss
    case shouldPop
    case shouldContinue
}

public enum JourneyError: Error {
    case dismissed
    case cancelled
}

public class Journey<P: Presentable>: JourneyPresentation where P.Matter: UIViewController {
    public var onDismiss: (Error?) -> ()
    
    public var style: PresentationStyle
    
    public var options: PresentationOptions
    
    public var transform: (P.Result) -> P.Result
    
    public var configure: (P.Matter, DisposeBag) -> ()
    
    public let presentable: P
    
    public init<InnerJourney: JourneyPresentation, Value>(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop],
        @JourneyBuilder _ content: @escaping (_ value: P.Result.Value) -> InnerJourney
    ) where P.Result == CoreSignal<Finite, Value> {
        self.presentable = presentable
        self.style = style
        self.options = options
        self.transform = { $0 }
        self.configure = { _, _ in }
        self.onDismiss = { _ in }
        
        var result: P.Result? = nil
        var presentBag: DisposeBag? = nil
        
        self.transform = { signal in
            result = signal
            return signal
        }
        
        configure = { matter, bag in
            presentBag = bag
            
            bag += result?.onEnd {
                bag.dispose()
            }
            
            bag += result?.onValue { value in
                let presentation = content(value)
                let presentationWithError = presentation.onError { error in
                    if let error = error as? JourneyError, error == JourneyError.dismissed {
                        if options.contains(.autoPop) {
                            self.onDismiss(JourneyError.dismissed)
                        }
                        
                        if presentation.options.contains(.autoPop) {
                            bag.dispose()
                        }
                    }
                }
                
                let result: JourneyPresentResult<InnerJourney> = matter.present(presentationWithError)
                
                switch result {
                case .presented:
                    break
                case .shouldDismiss:
                    if options.contains(.autoPop) {
                        self.onDismiss(JourneyError.dismissed)
                    }
                    
                    if presentation.options.contains(.autoPop) {
                        bag.dispose()
                    }
                case .shouldPop:
                    bag.dispose()
                case .shouldContinue:
                    break
                }
            }
        }
        
        onDismiss = { _ in
            result = nil
            presentBag?.dispose()
            presentBag = nil
        }
    }
    
    public init<InnerJourney: JourneyPresentation, Value>(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop],
        @JourneyBuilder _ content: @escaping (_ value: P.Result.Value) -> InnerJourney
    ) where P.Result == CoreSignal<Plain, Value> {
        self.presentable = presentable
        self.style = style
        self.options = options
        self.transform = { $0 }
        self.configure = { _, _ in }
        
        var result: P.Result? = nil
        var presentBag: DisposeBag? = nil
        
        self.onDismiss = { _ in
            result = nil
            presentBag?.dispose()
            presentBag = nil
        }
        
        self.transform = { signal in
            result = signal
            return signal
        }
        
        self.configure = { matter, bag in
            presentBag = bag
                        
            bag += result?.onValue { value in
                let presentation = content(value)
                let presentationWithError = presentation.onError { error in
                    if let error = error as? JourneyError, error == JourneyError.dismissed {
                        if options.contains(.autoPop) {
                            self.onDismiss(JourneyError.dismissed)
                        }
                        
                        if presentation.options.contains(.autoPop) {
                            bag.dispose()
                        }
                    }
                }
                
                let result: JourneyPresentResult<InnerJourney> = matter.present(presentationWithError)
                
                switch result {
                case .presented:
                    break
                case .shouldDismiss:
                    if options.contains(.autoPop) {
                        self.onDismiss(JourneyError.dismissed)
                    }
                    
                    if presentation.options.contains(.autoPop) {
                        bag.dispose()
                    }
                case .shouldPop:
                    bag.dispose()
                case .shouldContinue:
                    break
                }
            }
        }
    }
    
    public init<Value>(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop]
    ) where P.Result == Future<Value> {
        let dismissCallbacker = Callbacker<Void>()
        
        self.transform = { $0 }
        self.onDismiss = { _ in }
        self.configure = { _, bag in
            bag += dismissCallbacker.onValue { _ in
                bag.dispose()
            }
        }
        self.presentable = presentable
        self.style = style
        self.options = options
        
        self.onDismiss = { _ in
            dismissCallbacker.callAll()
        }
        
        self.transform = { future in
            Future { completion in
                let bag = DisposeBag()
                
                bag += future.onResult { result in
                    completion(result)
                    bag.dispose()
                }
                
                return bag
            }
        }
    }
    
    public init(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop]
    ) {
        self.transform = { $0 }
        
        var presentBag: DisposeBag? = nil
        
        self.onDismiss = { _ in
            presentBag?.dispose()
            presentBag = nil
        }
        self.configure = { _, bag in
            presentBag = bag
        }
        self.presentable = presentable
        self.style = style
        self.options = options
    }
}
