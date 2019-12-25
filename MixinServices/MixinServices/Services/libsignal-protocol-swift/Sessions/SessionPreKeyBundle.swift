//
//  SessionPreKeyBundle.swift
//  libsignal-protocol-swift iOS
//
//  Created by User on 16.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 A session pre key bundle can be used to establish a new session.
 */
public struct SessionPreKeyBundle {

    /// The registration id of the remote party
    let registrationId: UInt32

    /// The device id of the remote party
    let deviceId: Int32

    /// The pre key id
    let preKeyId: UInt32

    /// The pre key public data
    let preKey: Data

    /// The signed pre key id
    let signedPreKeyId: UInt32

    /// The signed pre key public data
    let signedPreKey: Data

    /// The signature of the signed pre key
    let signature: Data

    /// The identity public key of the remote party
    let identityKey: Data

    /**
     Create a pre key bundle from the components
     - parameter registrationId: The registration id of the remote party
     - parameter deviceId: The device id of the remote party
     - parameter preKeyId: The pre key id
     - parameter preKey: The pre key public data
     - parameter signedPreKeyId: The signed pre key id
     - parameter signedPreKey: The signed pre key public data
     - parameter signature: The signature of the signed pre key
     - parameter identityKey: The identity public key of the remote party
     */
    public init(registrationId: UInt32,
                deviceId: Int32,
                preKeyId: UInt32,
                preKey: Data,
                signedPreKeyId: UInt32,
                signedPreKey: Data,
                signature: Data,
                identityKey: Data) {
        self.registrationId = registrationId
        self.deviceId = deviceId
        self.preKeyId = preKeyId
        self.preKey = preKey
        self.signedPreKeyId = signedPreKeyId
        self.signedPreKey = signedPreKey
        self.signature = signature
        self.identityKey = identityKey
    }

    /// Convert the bundle to a `session_pre_key_bundle` pointer (needs to be freed)
    func pointer() throws -> OpaquePointer {

        // Convert pre key
        let preKeyPtr = try preKey.publicKeyPointer()
        defer { signal_type_unref(preKeyPtr) }

        // Convert signed pre key
        let signedPreKeyPtr = try signedPreKey.publicKeyPointer()
        defer { signal_type_unref(signedPreKeyPtr) }

        // Convert identity key
        let identityKeyPtr = try identityKey.publicKeyPointer()
        defer { signal_type_unref(identityKeyPtr) }

        var bundlePtr: OpaquePointer? = nil
        let result = signature.withUnsafeUInt8Pointer { ptr in
            withUnsafeMutablePointer(to: &bundlePtr) { bPtr in
                session_pre_key_bundle_create( bPtr, registrationId, deviceId, preKeyId, preKeyPtr, signedPreKeyId, signedPreKeyPtr, ptr, signature.count, identityKeyPtr)
            }
        }
        guard result == 0 else { throw SignalError(value: result) }
        return bundlePtr!
    }
}
