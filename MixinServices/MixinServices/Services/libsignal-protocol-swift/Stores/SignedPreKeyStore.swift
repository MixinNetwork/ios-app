//
//  SignedPreKeyStore.swift
//  libsignal-protocol-swift
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import SignalProtocolC

/**
 The `SignedPreKeyStore`protocol must be adopted to provide the storage for signed pre keys.
 */
public protocol SignedPreKeyStore {


    /**
     Load a local serialized signed PreKey record.
     - parameter signedPreKey: The ID of the local signed PreKey record
     - returns: The record, if found, or nil
     */
    func load(signedPreKey: UInt32) -> Data?

    /**
     Store a local serialized signed PreKey record.
     - parameter signedPreKey: The serialized record
     - parameter id: the Id of the signed PreKey record to store
     - returns: `true` on success, `false` on failure
     */
    func store(signedPreKey: Data, for id: UInt32) -> Bool

    /**
     Determine whether there is a committed signed PreKey record matching
     the provided ID.
     - parameter singedPreKey: A signed PreKey record ID
     - returns: `true` if the store has a record for the signed PreKey ID, `false` otherwise
     */
    func contains(signedPreKey: UInt32) -> Bool

    /**
     Delete a SignedPreKeyRecord from local storage.

     - parameter signedPreKey: The ID of the signed PreKey record to remove.
     - returns: `true` on success, `false` on failure
     */
    func remove(signedPreKey: UInt32) -> Bool

    /**
     Function called to perform cleanup when the data store context is being
     destroyed.
     */
    func destroy()
}

public extension SignedPreKeyStore {

    /**
     Function called to perform cleanup when the data store context is being
     destroyed.
     */
    func destroy() {
        // Empty implementation to make this function 'optional'
    }
}
