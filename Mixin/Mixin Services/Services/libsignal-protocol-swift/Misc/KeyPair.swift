//
//  KeyPair.swift
//  libsignal-protocol-swift
//
//  Created by User on 16.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import SignalProtocolC

/**
 A key pair consists of an elliptic curve public key and corresponding private key.
 */
public struct KeyPair {

    /// The public key data
    public let publicKey: Data

    /// The private key data
    public let privateKey: Data

    /**
     Create a key pair from the components.
     - parameter publicKey: The public key data
     - parameter privateKey: The private key data
     */
    init(publicKey: Data, privateKey: Data) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }

    /**
     Create a key pair from a pointer.
     - parameter pointer: The ec_key_pair pointer.
     - throws: Errors of type `SignalError`
     */
    init(pointer: OpaquePointer) throws {
        let pubKey = ec_key_pair_get_public(pointer)!
        let privKey = ec_key_pair_get_private(pointer)!

        var pubBuffer: OpaquePointer? = nil
        var result = withUnsafeMutablePointer(to: &pubBuffer) {
            ec_public_key_serialize($0, pubKey)
        }
        guard result == 0 else { throw SignalError(value: result) }

        var privBuffer: OpaquePointer? = nil
        result = withUnsafeMutablePointer(to: &privBuffer) {
            ec_private_key_serialize($0, privKey)
        }
        guard result == 0 else { throw SignalError(value: result) }

        self.publicKey = Data(signalBuffer: pubBuffer!)
        self.privateKey = Data(signalBuffer: privBuffer!)
        signal_buffer_free(pubBuffer)
        signal_buffer_free(privBuffer)
    }

    /// Convert to a pointer (must be freed through ec_key_pair_destroy)
    func pointer() throws -> OpaquePointer {
        // Convert public key
        let publicBuffer = publicKey.signalBuffer
        defer { signal_buffer_free(publicBuffer) }
        let pubLength = signal_buffer_len(publicBuffer)
        let pubData = signal_buffer_data(publicBuffer)!
        var pubKey: OpaquePointer? = nil
        var result = withUnsafeMutablePointer(to: &pubKey) {
            curve_decode_point($0, pubData, pubLength, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }

        // Convert private key
        let privateBuffer = privateKey.signalBuffer
        defer { signal_buffer_free(privateBuffer) }
        let privLength = signal_buffer_len(privateBuffer)
        let privData = signal_buffer_data(privateBuffer)!
        var privKey: OpaquePointer? = nil
        result = withUnsafeMutablePointer(to: &privKey) {
            curve_decode_private_point($0, privData, privLength, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }

        // Create key pair
        var keyPair: OpaquePointer? = nil
        result = withUnsafeMutablePointer(to: &keyPair) {
            ec_key_pair_create($0, pubKey, privKey)
        }
        guard result == 0 else { throw SignalError(value: result) }
        return keyPair!
    }
}
