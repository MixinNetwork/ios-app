//
//  PreKeyStore.swift
//  libsignal-protocol-swift
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import SignalProtocolC

/**
 The `PreKeyStore`protocol must be adopted to provide the storage for pre keys.
 */
public protocol PreKeyStore {

    /**
     Load a local serialized PreKey record.
     - parameter preKey: The ID of the local serialized PreKey record
     - returns: The record, if found, or nil
     */
    func load(preKey: UInt32) -> Data?

    /**
     Store a local serialized PreKey record.
     - parameter preKey: The serialized record
     - parameter id: The ID of the PreKey record to store.
     - returns: `true` on success, `false` on failure
     */
    func store(preKey: Data, for id: UInt32) -> Bool

    /**
     Determine whether there is a committed PreKey record matching the
     provided ID.
     - parameter preKey: A PreKey record ID.
     - returns: `true` if the store has a record for the PreKey ID, `false` otherwise
     */
    func contains(preKey: UInt32) -> Bool

    /**
     Delete a PreKey record from local storage.
     - parameter preKey: The ID of the PreKey record to remove.
     - returns: `true` on success, `false` on failure
     */
    func remove(preKey: UInt32) -> Bool

    /**
     Function called to perform cleanup when the data store context is being
     destroyed.
     */
    func destroy()
}

public extension PreKeyStore {

    /**
     Function called to perform cleanup when the data store context is being
     destroyed.
     */
    func destroy() {
        // Empty implementation to make this function 'optional'
    }
}
