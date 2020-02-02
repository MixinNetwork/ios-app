//
//  Signal.swift
//  libsignal-protocol-swift iOS
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 Main entry point for initialization of a client.
 */
public final class Signal {

    private static let def = Signal()

    static var context: OpaquePointer {
        return def.globalContext
    }

    private let globalContext: OpaquePointer

    init() {
        guard let con = signal_setup() else {
            fatalError("Could not create global signal context")
        }
        self.globalContext = OpaquePointer(con)
    }

    deinit {
        let ptr = UnsafeMutableRawPointer(globalContext)
        signal_destroy(ptr)
    }
}

public extension Signal {

    /**
     Generate an identity key pair.  Clients should only do this once,
     at install time.
     - returns: The public and private key on success, nil on failure
     - throws: Errors of type `SignalError`
     */
    static func generateIdentityKeyPair() throws -> KeyPair {
        // Create key pair
        var keyPair: OpaquePointer? = nil
        var result = withUnsafeMutablePointer(to: &keyPair) {
            signal_protocol_key_helper_generate_identity_key_pair($0, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { ratchet_identity_key_pair_destroy(keyPair) }
        return try KeyPair(pointer: keyPair!)
    }

    /**
     Generate a registration ID.  Clients should only do this once,
     at install time.
     - parameter extendedRange: By default (false), the generated registration
     Id is sized to require the minimal possible protobuf encoding overhead.
     Specify `true` if the caller needs the full range of `UInt32.max` at the
     cost of slightly higher encoding overhead.
     - returns: The generated registration Id on success, or nil on failure
     - throws: Errors of type `SignalError`
     */
    static func generateRegistrationId(extendedRange: Bool = false) throws -> UInt32 {
        let range: Int32 = extendedRange ? 1 : 0
        var id: UInt32 = 0
        let result = withUnsafeMutablePointer(to: &id) { p in
            signal_protocol_key_helper_generate_registration_id(p, range, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }
        return id
    }

    /**
     Generate a list of PreKeys.  Clients should do this at install time, and
     subsequently any time the list of PreKeys stored on the server runs low.

     - note:
     Pre key IDs are shorts, so they will eventually be repeated.
     Clients should  store pre keys in a circular buffer,
     so that they are repeated as infrequently as possible.

     - parameter start: the starting pre key ID, inclusive.
     - parameter count: the number of pre keys to generate.
     - returns: The pre keys on success, or nil on failure
     - throws: Errors of type `SignalError`
     */
    static func generatePreKeys(start: UInt32, count: Int) throws -> [SessionPreKey] {
        var head: OpaquePointer? = nil
        let result = withUnsafeMutablePointer(to: &head) {
            signal_protocol_key_helper_generate_pre_keys($0, start, UInt32(count), Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }

        defer { signal_protocol_key_helper_key_list_free(head) }

        var keys = [SessionPreKey]()
        var current = head
        while (current != nil) {
            let keyPtr = signal_protocol_key_helper_key_list_element(current)
            let key = try SessionPreKey(pointer: keyPtr!)
            keys.append(key)
            current = signal_protocol_key_helper_key_list_next(current)
        }
        return keys
    }

    /**
     Generate a signed pre key

     - parameter signedPreKey: the pre key Id to assign the generated signed pre key
     - parameter identity: the local client's identity key pair.
     - parameter timestamp: the current time in milliseconds since the UNIX epoch
     - returns: The signed pre key on success, or nil on failure
     - throws: Errors of type `SignalError`
     */
    static func generate(signedPreKey: UInt32, identity: KeyPair, timestamp: UInt64) throws -> SessionSignedPreKey {

        let pointer = try identity.pointer()
        defer { ec_key_pair_destroy(pointer) }
        var keyPtr: OpaquePointer? = nil
        var result = withUnsafeMutablePointer(to: &keyPtr) {
            signal_protocol_key_helper_generate_signed_pre_key($0, pointer, signedPreKey, timestamp, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { session_signed_pre_key_destroy(keyPtr) }

        return try SessionSignedPreKey(pointer: keyPtr!)
    }
}
