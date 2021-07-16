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

public struct Journey<P: Presentable>: JourneyPresentation where P.Matter: UIViewController {
    public var onDismiss: (Error?) -> ()
    
    public var style: PresentationStyle
    
    public var options: PresentationOptions
    
    public var transform: (P.Result) -> P.Result
    
    public var configure: (JourneyPresenter<P>) -> ()
    
    public let presentable: P
    
    public init<InnerJourney: JourneyPresentation, Value>(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop],
        @JourneyBuilder _ content: @escaping (_ value: P.Result.Value, _ context: PresentableStoreContainer) -> InnerJourney
    ) where P.Result == CoreSignal<Finite, Value> {
        self.presentable = presentable
        self.style = style
        self.options = options
        self.transform = { $0 }
        self.configure = { _ in }
        self.onDismiss = { _ in }
        
        var result: P.Result? = nil
        
        self.transform = { signal in
            result = signal
            return signal
        }
        
        configure = { presenter in
            presenter.bag += result?.onError { error in
                presenter.dismisser(error)
            }
            
            presenter.bag += result?.onError { error in
                presenter.dismisser(nil)
            }
            
            presenter.bag += result?.onValue { value in
                let presentation = content(value, presentable.storeContainer)
                
                let presentationWithError = presentation.onError { error in
                    if let error = error as? JourneyError, error == JourneyError.dismissed {
                        presenter.dismisser(error)
                    }
                }
                
                let result: JourneyPresentResult<InnerJourney> = presenter.matter.present(presentationWithError)
                
                switch result {
                case let .presented(result):
                    presenter.bag.hold(result as AnyObject)
                case .shouldDismiss:
                    presenter.dismisser(JourneyError.dismissed)
                case .shouldPop:
                    break
                case .shouldContinue:
                    break
                }
            }
        }
        
        onDismiss = { _ in
            result = nil
        }
    }
    
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
        self.configure = { _ in }
        self.onDismiss = { _ in }
        
        var result: P.Result? = nil
        
        self.transform = { signal in
            result = signal
            return signal
        }
        
        configure = { presenter in
            presenter.bag += result?.onError { error in
                presenter.dismisser(error)
            }
            
            presenter.bag += result?.onError { error in
                presenter.dismisser(nil)
            }
            
            presenter.bag += result?.onValue { value in
                let presentation = content(value)
                
                let presentationWithError = presentation.onError { error in
                    if let error = error as? JourneyError, error == JourneyError.dismissed {
                        presenter.dismisser(error)
                    }
                }
                
                let result: JourneyPresentResult<InnerJourney> = presenter.matter.present(presentationWithError)
                
                switch result {
                case let .presented(result):
                    presenter.bag.hold(result as AnyObject)
                case .shouldDismiss:
                    presenter.dismisser(JourneyError.dismissed)
                case .shouldPop:
                    break
                case .shouldContinue:
                    break
                }
            }
        }
        
        onDismiss = { _ in
            result = nil
        }
    }
    
    public init<InnerJourney: JourneyPresentation, Value>(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop],
        @JourneyBuilder _ content: @escaping (_ value: P.Result.Value, _ context: PresentableStoreContainer) -> InnerJourney
    ) where P.Result == CoreSignal<Plain, Value> {
        self.presentable = presentable
        self.style = style
        self.options = options
        self.transform = { $0 }
        self.configure = { _ in }
        self.onDismiss = { _ in }
        
        var result: P.Result? = nil
        
        self.transform = { signal in
            result = signal
            return signal
        }
        
        configure = { presenter in
            presenter.bag += result?.onValue { value in
                let presentation = content(value, presentable.storeContainer)
                
                let presentationWithError = presentation.onError { error in
                    if let error = error as? JourneyError, error == JourneyError.dismissed {
                        presenter.dismisser(error)
                    }
                }
                
                let result: JourneyPresentResult<InnerJourney> = presenter.matter.present(presentationWithError)
                
                switch result {
                case let .presented(result):
                    presenter.bag.hold(result as AnyObject)
                case .shouldDismiss:
                    presenter.dismisser(JourneyError.dismissed)
                case .shouldPop:
                    break
                case .shouldContinue:
                    break
                }
            }
        }
        
        onDismiss = { _ in
            result = nil
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
        self.configure = { _ in }
        self.onDismiss = { _ in }
        
        var result: P.Result? = nil
        
        self.transform = { signal in
            result = signal
            return signal
        }
        
        configure = { presenter in
            presenter.bag += result?.onValue { value in
                let presentation = content(value)
                
                let presentationWithError = presentation.onError { error in
                    if let error = error as? JourneyError, error == JourneyError.dismissed {
                        presenter.dismisser(error)
                    }
                }
                
                let result: JourneyPresentResult<InnerJourney> = presenter.matter.present(presentationWithError)
                
                switch result {
                case let .presented(result):
                    presenter.bag.hold(result as AnyObject)
                case .shouldDismiss:
                    presenter.dismisser(JourneyError.dismissed)
                case .shouldPop:
                    break
                case .shouldContinue:
                    break
                }
            }
        }
        
        onDismiss = { _ in
            result = nil
        }
    }
    
    public init<Value>(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop]
    ) where P.Result == Future<Value> {
        self.presentable = presentable
        self.style = style
        self.options = options
        self.transform = { $0 }
        self.configure = { _ in }
        self.onDismiss = { _ in }
        
        var result: P.Result? = nil
        
        self.transform = { future in
            result = future
            return future
        }
        
        configure = { presenter in
            result?.onError { error in
                presenter.dismisser(error)
            }
            
            result?.onValue { value in
                presenter.dismisser(nil)
            }
        }
        
        onDismiss = { _ in
            result = nil
        }
    }
    
    public init(
        _ presentable: P,
        style: PresentationStyle = .default,
        options: PresentationOptions = [.defaults, .autoPop]
    ) where P.Result == Disposable {
        self.presentable = presentable
        self.style = style
        self.options = options
        self.transform = { $0 }
        self.configure = { _ in }
        self.onDismiss = { _ in }
    }
}
