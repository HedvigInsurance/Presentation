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

public class GroupJourney<InnerJourney: JourneyPresentation>: JourneyPresentation {
    public var onDismiss: (Error?) -> ()
    
    public var style: PresentationStyle
    
    public var options: PresentationOptions
    
    public var transform: (InnerJourney.P.Result) -> InnerJourney.P.Result
    
    public var configure: (InnerJourney.P.Matter, DisposeBag) -> ()
    
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
}
    
