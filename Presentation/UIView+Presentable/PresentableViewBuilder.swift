//
//  PresentableViewBuilder.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-17.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow
import UIKit

@resultBuilder public struct PresentableViewBuilder {
    public static func buildBlock<P: Presentable>(_ component: P) -> [(UIView, Disposable)] where P.Matter: UIView, P.Result: Disposable {
        let (matter, result) = component.materialize()
        return [(matter, result)]
    }
    
    public static func buildBlock<P1: Presentable, P2: Presentable>(_ p1: P1, _ p2: P2) -> [(UIView, Disposable)]
    where
    P1.Matter: UIView, P1.Result: Disposable,
    P2.Matter: UIView, P2.Result: Disposable {
        let (p1Matter, p1Result) = p1.materialize()
        let (p2Matter, p2Result) = p2.materialize()
            
        return [(p1Matter, p1Result), (p2Matter, p2Result)]
    }
}
