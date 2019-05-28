//
//  DataExtensions.swift
//  libsignal-protocol-swift
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import SignalProtocolC

extension Data {

    /**
     Allocate a signal buffer to assign to the input pointer and copy the data into it.
     - parameter pointer: The pointer to copy the data to.
     */
    func copy(to pointer: UnsafeMutablePointer<OpaquePointer?>) {
        // Assign output pointer
        pointer.pointee = self.signalBuffer
    }

    /**
     Create data from a C pointer and length.
     - parameter pointer: The C pointer to the data.
     - parameter length: The number of bytes
     */
    init(from pointer: UnsafePointer<UInt8>, length: Int) {
        let buffer = UnsafeBufferPointer(start: pointer, count: length)
        self.init(buffer: buffer)
    }

    /**
     Create data from a signal buffer.
     - parameter signalBuffer: The C pointer to the signal buffer.
     */
    init(signalBuffer: OpaquePointer) {
        let length = signal_buffer_len(signalBuffer)
        let data = signal_buffer_data(signalBuffer)!
        self.init(from: data, length: length)
    }

    /// Convert the data to a signal buffer (needs to be freed manually)
    var signalBuffer: OpaquePointer {
        let buffer = signal_buffer_alloc(count)!
        let ptr = signal_buffer_data(buffer)!
        // Copy data
        self.withUnsafeUInt8Pointer { ptr.assign(from: $0!, count: self.count) }
        return buffer
    }

    /// Convert data to an `ec_public_key` pointer (needs to be freed manually)
    func publicKeyPointer() throws -> OpaquePointer {
        // Convert public key
        let buffer = self.signalBuffer
        defer { signal_buffer_free(buffer) }
        let length = signal_buffer_len(buffer)
        let data = signal_buffer_data(buffer)!
        var ptr: OpaquePointer? = nil
        let result = withUnsafeMutablePointer(to: &ptr) {
            curve_decode_point($0, data, length, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }
        return ptr!
    }
}
