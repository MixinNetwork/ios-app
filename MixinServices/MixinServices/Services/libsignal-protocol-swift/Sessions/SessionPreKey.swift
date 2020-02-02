//
//  SessionPreKey.swift
//  libsignal-protocol-swift
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 A session pre key is uploaded to the server and
 used as part of the pre key bundle to establish new sessions.
 */
public struct SessionPreKey {

    /// The pre key id
    public let id: UInt32

    /// The key pair of the pre key
    public let keyPair: KeyPair

    /**
     Create a pre key from serialized data
     - parameter pointer: The serialized data
     - throws: Errors of type `SignalError`
     */
    public init(from data: Data) throws {
        var preKey: OpaquePointer? = nil
        let result = data.withUnsafeUInt8Pointer { dPtr in
            withUnsafeMutablePointer(to: &preKey) {
                session_pre_key_deserialize($0, dPtr, data.count, Signal.context)
            }
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { session_pre_key_destroy(preKey) }
        try self.init(pointer: preKey!)
    }

    /**
     Create a pre key from a pointer
     - parameter pointer: The `session_pre_key` pointer
     - throws: Errors of type `SignalError`
     */
    init(pointer: OpaquePointer) throws {
        let ptr = session_pre_key_get_key_pair(pointer)!

        self.keyPair = try KeyPair(pointer: ptr)
        self.id = session_pre_key_get_id(pointer)
    }

    /// Serialize the session pre key
    public func data() throws -> Data {
        let keyPairPtr = try keyPair.pointer()
        defer { ec_public_key_destroy(keyPairPtr) }

        // Create pre key
        var preKey: OpaquePointer? = nil
        var result = withUnsafeMutablePointer(to: &preKey) {
            session_pre_key_create($0, self.id, keyPairPtr)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { session_pre_key_destroy(preKey) }

        // Serialize pre key
        var preKeyRecord: OpaquePointer? = nil
        result = withUnsafeMutablePointer(to: &preKeyRecord) {
            session_pre_key_serialize($0, preKey)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { signal_buffer_free(preKeyRecord) }

        // Return serialized data
        return Data(signalBuffer: preKeyRecord!)
    }

}
