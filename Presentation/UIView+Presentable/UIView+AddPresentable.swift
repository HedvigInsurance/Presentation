//
//  UIView+AddPresentable.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-17.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Flow

extension UIView {
    public func addSubviews(@PresentableViewBuilder _ builder: () -> [(UIView, Disposable)]) -> Disposable {
        let bag = DisposeBag()
        let viewsAndDisposables = builder()
        
        viewsAndDisposables.forEach { view, disposable in
            addSubview(view)
            bag += disposable
        }
        
        bag += Disposer {
            viewsAndDisposables.forEach { view, _ in
                view.removeFromSuperview()
            }
        }
        
        return bag
    }
}

extension UIStackView {
    public func addArrangedSubviews(@PresentableViewBuilder _ builder: () -> [(UIView, Disposable)]) -> Disposable {
        let bag = DisposeBag()
        let viewsAndDisposables = builder()
        
        viewsAndDisposables.forEach { view, disposable in
            addArrangedSubview(view)
            bag += disposable
        }
        
        bag += Disposer {
            viewsAndDisposables.forEach { view, _ in
                view.removeFromSuperview()
            }
        }
        
        return bag
    }
}
