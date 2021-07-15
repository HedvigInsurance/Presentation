//
//  JourneyBuilder.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-15.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

@resultBuilder public struct JourneyBuilder {
    public static func buildEither<TrueP: JourneyPresentation, FalseP: JourneyPresentation>(first p: TrueP) -> ConditionalJourneyPresentation<TrueP, FalseP> {
        return ConditionalJourneyPresentation(first: p)
    }
    
    public static func buildEither<TrueP: JourneyPresentation, FalseP: JourneyPresentation>(second p: FalseP) -> ConditionalJourneyPresentation<TrueP, FalseP> {
        return ConditionalJourneyPresentation(second: p)
    }

    public static func buildBlock<P: JourneyPresentation>(_ p: P) -> P {
        return p
    }
    
    public static func buildOptional<JP: JourneyPresentation>(_ journeyPresentation: JP?) -> ConditionalJourneyPresentation<JP, ContinueJourney> {
        if let journeyPresentation = journeyPresentation {
            return ConditionalJourneyPresentation(first: journeyPresentation)
        }
        
        return ConditionalJourneyPresentation(second: ContinueJourney())
    }
}
