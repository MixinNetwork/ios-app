//
//  IdentityKeyStore.swift
//  libsignal-protocol-swift
//
//  Created by User on 14.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 The `IdentityKeyStore`protocol must be adopted to provide the storage for identity keys.
 */
public protocol IdentityKeyStore {

    /**
     Get the local client's identity key pair.
     - returns: The identity key pair on success, nil on failure
     */
    func identityKeyPair() -> KeyPair?

    /**
     Return the local client's registration ID.

     Clients should maintain a registration ID, a random number
     between 1 and 16380 that's generated once at install time.

     - returns: The registration id on success, nil on failure
     */
    func localRegistrationId() -> UInt32?

    /**
     Save a remote client's identity key

     Store a remote client's identity key as trusted.
     The value of `identity` may be nil. In this case remove the key data
     from the identity store, but retain any metadata that may be kept
     alongside it.

     - parameter identity: The remote client's identity key, may be nil
     - parameter address: The address of the remote client
     - returns: `true` on success, `false` on failure
     */
    func save(identity: Data?, for address: SignalAddress) -> Bool

    /**
     Verify a remote client's identity key.

     Determine whether a remote client's identity is trusted. Convention is that the Signal protocol is 'trust on first use.' This means that an identity key is considered 'trusted' if there is no entry for the recipient in the local store, or if it matches the saved key for a recipient in the local store.  Only if it mismatches an entry in the local store is it considered 'untrusted.'

     - parameter address: The address of the remote client
     - parameter identity: The identity key to verify
     - returns: `true` if trusted, `false` if untrusted, nil on failure
     */
    func isTrusted(identity: Data, for address: SignalAddress) -> Bool?

    /**
     Function called to perform cleanup when the data store context is being
     destroyed.
     */
    func destroy()

}

public extension IdentityKeyStore {

    /**
     Function called to perform cleanup when the data store context is being
     destroyed.
     */
    func destroy() {
        // Empty implementation to make this function 'optional'
    }
}


