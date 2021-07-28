//
//  GroupJourney.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-16.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

public struct GroupJourney<InnerJourney: JourneyPresentation>: JourneyPresentation {
    public var onDismiss: (Error?) -> ()
    
    public var style: PresentationStyle
    
    public var options: PresentationOptions
    
    public var transform: (InnerJourney.P.Result) -> InnerJourney.P.Result
    
    public var configure: (JourneyPresenter<P>) -> ()
    
    public let presentable: InnerJourney.P
    
    public init(
        @JourneyBuilder _ content: @escaping () -> InnerJourney
    ) {
        let presentation = content()
        
        self.presentable = presentation.presentable
        self.style = presentation.style
        self.options = presentation.options
        self.transform = presentation.transform
        self.configure = presentation.configure
        self.onDismiss = presentation.onDismiss
    }
    
    public init(
        @JourneyBuilder _ content: @escaping (_ context: PresentableStoreContainer) -> InnerJourney
    ) {
        let presentation = content(globalPresentableStoreContainer)

        self.presentable = presentation.presentable
        self.style = presentation.style
        self.options = presentation.options
        self.transform = presentation.transform
        self.configure = presentation.configure
        self.onDismiss = presentation.onDismiss
    }
}
    
