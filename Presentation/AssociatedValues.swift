//
//  AssociatedValues.swift
//  Presentation
//
//  Created by Måns Bernhardt on 2016-08-26.
//  Copyright © 2016 iZettle. All rights reserved.
//

import Foundation

extension NSObject {
    public func associatedValue<T>(forKey key: UnsafeRawPointer) -> T? {
        return objc_getAssociatedObject(self, key) as? T
    }

    public func associatedValue<T>(forKey key: UnsafeRawPointer, initial: @autoclosure () throws -> T) rethrows -> T {
        if let val: T = associatedValue(forKey: key) {
            return val
        }
        let val = try initial()
        setAssociatedValue(val, forKey: key)
        return val
    }

    public func setAssociatedValue<T>(_ val: T?, forKey key: UnsafeRawPointer) {
        objc_setAssociatedObject(self, key, val, .OBJC_ASSOCIATION_RETAIN)
    }

    public func clearAssociatedValue(forKey key: UnsafeRawPointer) {
        objc_setAssociatedObject(self, key, nil, .OBJC_ASSOCIATION_RETAIN)
    }
}
