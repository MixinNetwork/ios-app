//
//  Fingerprint.swift
//  libsignal-protocol-swift
//
//  Created by User on 19.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import SignalProtocolC

/**
 Fingerprints can be used to compare identity keys across devices.
 A fingerprint consists of a human readable string of numbers and
 a data that can be transmitted to another device (e.g. through a QR Code).
 */
public class Fingerprint {

    /// A displayable string of numbers to compare fingerprints visually
    public let displayable: String

    /// Data that can be transmitted to another device
    public let scannable: Data

    // MARK: Public initialization

    /**
     Construct a fingerprint (Version 0) generator for 60 digit numerics.
     - note: The higher the iteration count, the higher the security level:
     - 1024 iterations ~ 109.7 bits
     - 1400 iterations > 110 bits
     - 5200 iterations > 112 bits
     - parameter iterations: The number of internal iterations to perform in the process of generating a fingerprint. This needs to be constant, and synchronized across all clients.
     - parameter localIdentifier: The client's "stable" identifier.
     - parameter localIdentity: The client's identity key.
     - parameter remoteIdentifier: The remote party's "stable" identifier.
     - parameter remoteIdentity: The remote party's identity key.
     - throws: Errors of type `SignalError`
     */
    public convenience init(
        iterations: Int,
        localIdentifier: String,
        localIdentity: Data,
        remoteIdentifier: String,
        remoteIdentity: Data) throws {

        try self.init(
            iterations: iterations,
            version: 0,
            localStableIdentifier: localIdentifier,
            localIdentityData: localIdentity,
            remoteStableIdentifier: remoteIdentifier,
            remoteIdentityData: remoteIdentity)
    }

    /**
     Construct a fingerprint (Version 1) generator for 60 digit numerics.
     - note: The higher the iteration count, the higher the security level:
     - 1024 iterations ~ 109.7 bits
     - 1400 iterations > 110 bits
     - 5200 iterations > 112 bits
     - parameter iterations: The number of internal iterations to perform in the process of generating a fingerprint. This needs to be constant, and synchronized across all clients.
     - parameter localIdentity: The client's identity key.
     - parameter remoteIdentity: The remote party's identity key.
     - throws: Errors of type `SignalError`
     */
    public convenience init(
        iterations: Int,
        localIdentity: Data,
        remoteIdentity: Data) throws {

        try self.init(
            iterations: iterations,
            version: 1,
            localStableIdentifier: nil,
            localIdentityData: localIdentity,
            remoteStableIdentifier: nil,
            remoteIdentityData: remoteIdentity)
    }

    /**
    Generate a scannable and displayble fingerprint (Version 0) for a list of keys.
     - note: The higher the iteration count, the higher the security level:
     - 1024 iterations ~ 109.7 bits
     - 1400 iterations > 110 bits
     - 5200 iterations > 112 bits
     - parameter iterations: The number of internal iterations to perform in the process of generating a fingerprint. This needs to be constant, and synchronized across all clients.
     - parameter localIdentifier: The client's "stable" identifier.
     - parameter localIdentity: The client's identity key.
     - parameter remoteIdentifier: The remote party's "stable" identifier.
     - parameter remoteIdentity: The remote party's identity key.
     - throws: Errors of type `SignalError`
     */
    public convenience init(
        iterations: Int,
        localIdentifier: String,
        localIdentityList: [Data],
        remoteIdentifier: String,
        remoteIdentityList: [Data]) throws {

        try self.init(iterations: iterations,
                  version: 0,
                  localStableIdentifier: localIdentifier,
                  localIdentityList: localIdentityList,
                  remoteStableIdentifier: remoteIdentifier,
                  remoteIdentityList: remoteIdentityList)
    }

    /**
     Generate a scannable and displayble fingerprint (Version 1) for a list of keys.
     - note: The higher the iteration count, the higher the security level:
     - 1024 iterations ~ 109.7 bits
     - 1400 iterations > 110 bits
     - 5200 iterations > 112 bits
     - parameter iterations: The number of internal iterations to perform in the process of generating a fingerprint. This needs to be constant, and synchronized across all clients.
     - parameter localIdentifier: The client's "stable" identifier.
     - parameter localIdentity: The client's identity key.
     - parameter remoteIdentifier: The remote party's "stable" identifier.
     - parameter remoteIdentity: The remote party's identity key.
     - throws: Errors of type `SignalError`
     */
    public convenience init(
        iterations: Int,
        localIdentityList: [Data],
        remoteIdentityList: [Data]) throws {

        try self.init(iterations: iterations,
                      version: 1,
                      localStableIdentifier: nil,
                      localIdentityList: localIdentityList,
                      remoteStableIdentifier: nil,
                      remoteIdentityList: remoteIdentityList)
    }

    // MARK: Private initialization

    private convenience init(
        iterations: Int,
        version: Int32,
        localStableIdentifier: String?,
        localIdentityData: Data,
        remoteStableIdentifier: String?,
        remoteIdentityData: Data) throws {


        var localPublicKey: OpaquePointer? = nil
        var result = localIdentityData.withUnsafeUInt8Pointer { dPtr in
            withUnsafeMutablePointer(to: &localPublicKey) {
                curve_decode_point($0, dPtr, localIdentityData.count, Signal.context)
            }
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { signal_type_unref(localPublicKey) }

        var remotePublicKey: OpaquePointer? = nil
        result = remoteIdentityData.withUnsafeUInt8Pointer { dPtr in
            withUnsafeMutablePointer(to: &remotePublicKey) {
                curve_decode_point($0, dPtr, remoteIdentityData.count, Signal.context)
            }
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { signal_type_unref(remotePublicKey) }

        let fingerprint = try createFingerprint(
            iterations: iterations,
            version: version,
            local: localStableIdentifier,
            remote: remoteStableIdentifier,
            localKeys: localPublicKey!,
            remoteKeys: remotePublicKey!,
            function: fingerprint_generator_create_for)
        defer { signal_type_unref(fingerprint) }

        try self.init(fingerprint: fingerprint)
    }

    /**
     Create a fingerprint from public key lists.
     */
    private convenience init(iterations: Int,
                             version: Int32,
                             localStableIdentifier: String?,
                             localIdentityList: [Data],
                             remoteStableIdentifier: String?,
                             remoteIdentityList: [Data]) throws {


        let localList = try list(from: localIdentityList)
        defer { ec_public_key_list_free(localList) }
        let remoteList = try list(from: remoteIdentityList)
        defer { ec_public_key_list_free(remoteList) }

        let fingerprint = try createFingerprint(
            iterations: iterations,
            version: version,
            local: localStableIdentifier,
            remote: remoteStableIdentifier,
            localKeys: localList,
            remoteKeys: remoteList,
            function: fingerprint_generator_create_for_list)
        defer { signal_type_unref(fingerprint) }

        try self.init(fingerprint: fingerprint)
    }

    private init(fingerprint: OpaquePointer) throws {
        let dPtr = displayable_fingerprint_text(fingerprint_get_displayable(fingerprint))!
        let sPtr = fingerprint_get_scannable(fingerprint)

        var scannableBuffer: OpaquePointer? = nil
        let result = withUnsafeMutablePointer(to: &scannableBuffer) {
            scannable_fingerprint_serialize($0, sPtr)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { signal_buffer_free(scannableBuffer) }

        self.displayable = String.init(cString: dPtr)
        self.scannable = Data(signalBuffer: scannableBuffer!)
    }

    // MARK: Internal functions

    private func pointer(for scannable: Data) throws -> OpaquePointer {
        var ptr: OpaquePointer? = nil
        let result = scannable.withUnsafeUInt8Pointer { sPtr in
            withUnsafeMutablePointer(to: &ptr) {
                scannable_fingerprint_deserialize($0, sPtr, scannable.count, Signal.context)
            }
        }
        guard result == 0 else { throw SignalError(value: result) }
        return ptr!
    }

    // MARK: Comparison

    /**
     Match a received/scanned fingerprint.
     - parameter fingerprint: The received scannable fingerprint data
     - returns: `true` if the fingerprints match
     - throws: Errors of type `SignalError`
     */
    public func matches(scannable data: Data) throws -> Bool {
        let localScannable = try pointer(for: scannable)
        defer { signal_type_ref(localScannable) }
        let remoteScannable = try pointer(for: data)
        defer { signal_type_ref(remoteScannable) }

        let result = scannable_fingerprint_compare(localScannable, remoteScannable)
        guard result >= 0 else { throw SignalError(value: result) }
        return result == 1
    }

    /**
     Match a received/scanned fingerprint.
     - parameter fingerprint: The received scannable fingerprint
     - returns: `true` if the fingerprints match
     - throws: Errors of type `SignalError`
     */
    public func matches(scannable fingerprint: Fingerprint) throws -> Bool {
        return try matches(scannable: fingerprint.scannable)
    }
}

/**
 Helper function to convert strings to data and create a fingerprint.
 */
private func createFingerprint(
    iterations: Int, version: Int32,
    local: String?, remote: String?,
    localKeys: OpaquePointer, remoteKeys: OpaquePointer,
    function: (OpaquePointer, UnsafePointer<Int8>?, OpaquePointer, UnsafePointer<Int8>?, OpaquePointer, UnsafeMutablePointer<OpaquePointer?>) -> Int32) throws -> OpaquePointer {

    var generator: OpaquePointer? = nil
    var result = withUnsafeMutablePointer(to: &generator) {
        fingerprint_generator_create($0, Int32(iterations), version, Signal.context)
    }
    guard result == 0 else { throw SignalError(value: result) }
    defer { fingerprint_generator_free(generator) }

    var fingerprint: OpaquePointer? = nil
    if version == 0 {
        guard let localData = local?.data(using: .utf8),
            let remoteData = remote?.data(using: .utf8) else {
                throw SignalError.invalidArgument
        }
        result = localData.withUnsafeBytes { lBuffer in
            remoteData.withUnsafeBytes { rBuffer in
                withUnsafeMutablePointer(to: &fingerprint) {
                    let lPtr = lBuffer.bindMemory(to: Int8.self).baseAddress
                    let rPtr = rBuffer.bindMemory(to: Int8.self).baseAddress
                    return function(generator!, lPtr, localKeys, rPtr, remoteKeys, $0)
                }
            }
        }
    } else {
        result = withUnsafeMutablePointer(to: &fingerprint) {
            function(generator!, nil, localKeys, nil, remoteKeys, $0)
        }
    }

    guard result == 0 else { throw SignalError(value: result) }
    return fingerprint!
}

/**
 Helper function to create an `ec_public_key_list` from an array of Data objects
 */
private func list(from keyList: [Data]) throws -> OpaquePointer {
    guard let list = ec_public_key_list_alloc() else { throw SignalError.noMemory }
    for item in keyList {
        var key: OpaquePointer? = nil
        var result = item.withUnsafeUInt8Pointer { dPtr in
            withUnsafeMutablePointer(to: &key) {
                curve_decode_point($0, dPtr, item.count, Signal.context)
            }
        }

        result = ec_public_key_list_push_back(list, key)
        guard result == 0 else { throw SignalError(value: result) }
        signal_type_unref(key)
    }
    return list
}


