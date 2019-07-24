//
//  SessionSignedPreKey.swift
//  libsignal-protocol-swift
//
//  Created by User on 16.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import SignalProtocolC

/**
 A signed pre key.
 */
public struct SessionSignedPreKey {

    /// The id of the signed pre key
    public let id: UInt32

    /// The creation timestamp of the key
    public let timestamp: UInt64

    /// The signature of the public key signed by the identity key
    public let signature: Data

    /// The key pair of the signed pre key
    public let keyPair: KeyPair

    /**
     Create a signed pre key from serialized data.
     - parameter data: The serialized data
     - throws: Errors of type `SignalError`
     */
    public init(from data: Data) throws {
        var signedPreKey: OpaquePointer? = nil
        let result = data.withUnsafeUInt8Pointer { dPtr in
            withUnsafeMutablePointer(to: &signedPreKey) {
                session_signed_pre_key_deserialize($0, dPtr, data.count, Signal.context)
            }
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { session_signed_pre_key_destroy(signedPreKey) }
        try self.init(pointer: signedPreKey!)
    }

    /**
     Create a key pair from a pointer.
     - parameter pointer: A `session_signed_pre_key` pointer
     - throws: Errors of type `SignalError`
     */
    init(pointer: OpaquePointer) throws {

        let ptr = session_signed_pre_key_get_key_pair(pointer)!
        self.keyPair = try KeyPair(pointer: ptr)

        let signatureData = session_signed_pre_key_get_signature(pointer)
        let signatureLength = session_signed_pre_key_get_signature_len(pointer)
        guard signatureData != nil else { throw SignalError.unknownError }
        self.signature = Data(from: signatureData!, length: signatureLength)
        self.timestamp = session_signed_pre_key_get_timestamp(pointer)
        self.id = session_signed_pre_key_get_id(pointer)
    }

    /// Serialize the session signed pre key
    public func data() throws -> Data {
        let keyPairPtr = try keyPair.pointer()
        defer { ec_key_pair_destroy(keyPairPtr) }

        // Create pre key
        var signedPreKey: OpaquePointer? = nil
        var result = signature.withUnsafeUInt8Pointer { ptr in
            withUnsafeMutablePointer(to: &signedPreKey) {
                return session_signed_pre_key_create($0, id, timestamp, keyPairPtr, ptr, signature.count)
            }
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { session_signed_pre_key_destroy(signedPreKey) }

        // Serialize pre key
        var signedPreKeyRecord: OpaquePointer? = nil
        result = withUnsafeMutablePointer(to: &signedPreKeyRecord) {
            session_signed_pre_key_serialize($0, signedPreKey)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { signal_buffer_free(signedPreKeyRecord) }

        // Return serialized data
        return Data(signalBuffer: signedPreKeyRecord!)
    }
}
