//
//  SenderKeyStore.swift
//  libsignal-protocol-swift
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 The `SenderKeyStore`protocol must be adopted to provide the storage for sender keys.
 */
public protocol SenderKeyStore {

    /**
     Store a serialized sender key record for a given
     (groupId + senderId + deviceId) tuple.

     - parameter senderKey: The serialized record
     - parameter address: the (groupId + senderId + deviceId) tuple
     - parameter userRecord: Containing application specific
     data to be stored alongside the serialized record. If no such
     data exists, then this parameter will be nil.
     - returns: `true` on success, `false` on failure
     */
    func store(senderKey: Data, for address: SignalSenderKeyName, userRecord: Data?) -> Bool

    /**
     Returns a copy of the sender key record corresponding to the
     (groupId + senderId + deviceId) tuple.

     - parameter address: the (groupId + senderId + deviceId) tuple
     - returns: The sender key and optional user record, or nil on failure
     */
    func loadSenderKey(for address: SignalSenderKeyName) -> (senderKey: Data, userRecord: Data?)?

    /**
     Function called to perform cleanup when the data store context is being
     destroyed.
     */
    func destroy()
}

public extension SenderKeyStore {

    /**
     Function called to perform cleanup when the data store context is being
     destroyed.
     */
    func destroy() {
        // Empty implementation to make this function 'optional'
    }
}
