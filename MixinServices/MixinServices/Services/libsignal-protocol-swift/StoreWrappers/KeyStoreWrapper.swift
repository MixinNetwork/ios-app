//
//  KeyWrapper.swift
//  libsignal-protocol-swift
//
//  Created by User on 17.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation


protocol KeyStoreWrapper {

    associatedtype StoreType

    static var delegates: [Int: StoreType] { get set }

    static func setStore(in context: OpaquePointer, delegate: StoreType, userData: UnsafeMutablePointer<Int>) throws
}

extension KeyStoreWrapper {

    static func removeDelegate(for id: Int) {
        delegates[id] = nil
    }

    static func delegate(for pointer: UnsafeMutableRawPointer?) -> StoreType? {
        guard let ptr = pointer else {
            return nil
        }
        let typedPtr = ptr.assumingMemoryBound(to: Int.self)
        return delegates[typedPtr.pointee]
    }
}
