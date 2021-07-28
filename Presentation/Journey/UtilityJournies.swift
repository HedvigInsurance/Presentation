//
//  UtilityJournies.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-15.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

public struct DismisserPresentable: Presentable {
    public class DismisserViewController: UIViewController {}
    
    public func materialize() -> (DismisserViewController, Void) {
        return (DismisserViewController(), ())
    }
}

public struct DismissJourney: JourneyPresentation {
    public var presentable: DismisserPresentable {
        DismisserPresentable()
    }

    public var style: PresentationStyle {
        .default
    }

    public var options: PresentationOptions {
        []
    }

    public var configure: (JourneyPresenter<P>) -> () = { _ in }

    public var onDismiss: (Error?) -> () = { _ in }
    
    public var transform: (()) -> Void = { $0 }

    public init() {}
}

public struct PopperPresentable: Presentable {
    public class PopperViewController: UIViewController {}
    
    public func materialize() -> (PopperViewController, Void) {
        return (PopperViewController(), ())
    }
}

public struct PopJourney: JourneyPresentation {
    public var presentable: PopperPresentable {
        PopperPresentable()
    }

    public var style: PresentationStyle {
        .default
    }

    public var options: PresentationOptions {
        []
    }

    public var configure: (JourneyPresenter<P>) -> () = { _ in }

    public var onDismiss: (Error?) -> () = { _ in }
    
    public var transform: (()) -> Void = { $0 }

    public init() {}
}

public struct ContinuerPresentable: Presentable {
    public class ContinuerViewController: UIViewController {}
    
    public func materialize() -> (ContinuerViewController, Void) {
        return (ContinuerViewController(), ())
    }
}

public struct ContinueJourney: JourneyPresentation {
    public var presentable: ContinuerPresentable {
        ContinuerPresentable()
    }

    public var style: PresentationStyle {
        .default
    }

    public var options: PresentationOptions {
        []
    }

    public var configure: (JourneyPresenter<ContinuerPresentable>) -> () = { _ in }

    public var onDismiss: (Error?) -> () = { _ in }
    
    public var transform: (()) -> Void = { $0 }

    public init() {}
}
