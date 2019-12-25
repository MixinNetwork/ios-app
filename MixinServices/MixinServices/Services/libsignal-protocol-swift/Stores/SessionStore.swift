//
//  SessionStore.swift
//  libsignal-protocol-swift
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 The `SessionStore`protocol must be adopted to provide the storage for sessions.
 */
public protocol SessionStore {

    /**
     Returns a copy of the serialized session record corresponding to the
     provided recipient ID + device ID tuple.

     - parameter address: The address of the remote client
     - returns: The session and optional user record, or nil on failure
     */
    func loadSession(for address: SignalAddress) -> (session: Data, userRecord: Data?)?

    /**
     Returns all known devices with active sessions for a recipient
     - parameter name: The name of the remote client
     - returns: The ids of all active devices
     */
    func subDeviceSessions(for name: String) -> [Int32]?
    
    /**
     Commit to storage the session record for a given
     recipient ID + device ID tuple.

     - parameter session: The serialized session record
     - parameter userRecord: Application specific data to be stored alongside the serialized session record for the remote client. If no such data exists, then this parameter will be nil.
     - parameter address: The address of the remote client
     - returns: `true` on sucess, `false` on failure.
     */
    func store(session: Data, for address: SignalAddress, userRecord: Data?) -> Bool

    /**
     Determine whether there is a committed session record for a
     recipient ID + device ID tuple.

     - parameter address: The address of the remote client
     - returns: `true` if a session record exists, `false` otherwise.
     */
    func containsSession(for address: SignalAddress) -> Bool

    /**
     Remove a session record for a recipient ID + device ID tuple.

     - parameter address: The address of the remote client
     - returns: `true` if a session was deleted, `false` if a session was not deleted, nil on error
     */
    func deleteSession(for address: SignalAddress) -> Bool?

    /**
     Remove the session records corresponding to all devices of a recipient Id.

     - parameter name: The name of the remote client
     - returns: The number of deleted sessions on success, nil on failure
     */
    func deleteAllSessions(for name: String) -> Int?
    
    /**
     Function called to perform cleanup when the data store context is being
     destroyed.
     */
    func destroy()
}

public extension SessionStore {

    /**
     Function called to perform cleanup when the data store context is being
     destroyed.
     */
    func destroy() {
        // Empty implementation to make this function 'optional'
    }
}
