//
//  PreKeyStoreWrapper.swift
//  libsignal-protocol-swift
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 This class acts as a bridge between the Swift implementation and the C API for the pre key store
 */
final class PreKeyStoreWrapper: KeyStoreWrapper {

    /// The dictionary of all registered delegates
    static var delegates = [Int : PreKeyStore]()

    /**
     Set the store for a signal context to act as a pre key store.
     - parameter context: The signal context
     - parameter delegate: The store that handles the operations
     - parameter userData: A pointer to the unique id of the delegate
     - returns: `true` on success, `false` on failure
     */
    static func setStore(in context: OpaquePointer, delegate: PreKeyStore, userData: UnsafeMutablePointer<Int>) throws {

        // Set pointer to unique id as user data to allow the right delegate to handle store callbacks
        let id = userData.pointee
        let userPtr = UnsafeMutableRawPointer(mutating: userData)
        delegates[id] = delegate
        
        var store = signal_protocol_pre_key_store(
            load_pre_key: loadPreKey,
            store_pre_key: storePreKey,
            contains_pre_key: containsPreKey,
            remove_pre_key: removePreKey,
            destroy_func: destroy,
            user_data: userPtr)

        let result = withUnsafePointer(to: &store) {
            signal_protocol_store_context_set_pre_key_store(context, $0)
        }
        guard result == 0 else { throw SignalError(value: result) }
    }

}

/**
 * Load a local serialized PreKey record.
 *
 - parameter record: Pointer to a newly allocated buffer containing the
 record, if found. Unset if no record was found. The Signal Protocol library
 is responsible for freeing this buffer.
 - parameter preKeyId: The ID of the local serialized PreKey record
 - parameter recordLength: Length of the serialized record
 - returns: SG_SUCCESS if the key was found, SG_ERR_INVALID_KEY_ID if the key could not be found
 */
func loadPreKey(
    _ record: UnsafeMutablePointer<OpaquePointer?>?,
    _ preKeyId: UInt32,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = PreKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let data = delegate.load(preKey: preKeyId) else {
        return SG_ERR_INVALID_KEY_ID
    }

    data.copy(to: record!)
    return 0
}

/**
 Store a local serialized PreKey record.

 - parameter preKeyId: the ID of the PreKey record to store.
 - parameter record: Pointer to a buffer containing the serialized record
 - parameter recordLength: Length of the serialized record
 - returns: 0 on success, negative on failure
 */
func storePreKey(
    _ preKeyId: UInt32,
    _ record: UnsafeMutablePointer<UInt8>?,
    _ recordLength: Int,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = PreKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    let keyData = Data(from: record!, length: recordLength)

    guard delegate.store(preKey: keyData, for: preKeyId) else {
        return SignalError.notSuccessful.rawValue
    }
    return 0
}

/**
 Determine whether there is a committed PreKey record matching the
 provided ID.

 - parameter preKeyId: A PreKey record ID.
 - parameter userData: Pointer to the user data.
 - returns: 1 if the store has a record for the PreKey ID, 0 otherwise
 */
func containsPreKey(
    _ preKeyId: UInt32,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = PreKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard delegate.contains(preKey: preKeyId) else {
        return 0
    }
    return 1
}

/**
 Delete a PreKey record from local storage.
 *
 - parameter preKeyId: The ID of the PreKey record to remove.
 - parameter userData: Pointer to the user data.
 - returns: 0 on success, negative on failure
 */
func removePreKey(
    _ preKeyId: UInt32,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = PreKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard delegate.remove(preKey: preKeyId) else {
        return SignalError.notSuccessful.rawValue
    }
    return 0
}

/**
 Function called to perform cleanup when the data store context is being
 destroyed.
 - parameter userData: Pointer to the user data.
 */
private func destroy(_ userData: UnsafeMutableRawPointer?) {
    PreKeyStoreWrapper.delegate(for: userData)?.destroy()
}
