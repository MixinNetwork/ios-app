//
//  SignedPreKeyStoreWrapper.swift
//  libsignal-protocol-swift
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import SignalProtocolC

/**
 This class acts as a bridge between the Swift implementation and the C API for the signed pre key store
 */
final class SignedPreKeyStoreWrapper: KeyStoreWrapper {

    /// The dictionary of all registered delegates
    static var delegates = [Int : SignedPreKeyStore]()

    /**
     Set the store for a signal context to act as a signed pre key store
     - parameter context: The signal context
     - parameter delegate: The store that handles the operations
     - parameter userData: A pointer to the unique id of the delegate
     - returns: `true` on success, `false` on failure
     */
    static func setStore(in context: OpaquePointer, delegate: SignedPreKeyStore, userData: UnsafeMutablePointer<Int>) throws {

        // Set pointer to unique id as user data to allow the right delegate to handle store callbacks
        let id = userData.pointee
        let userPtr = UnsafeMutableRawPointer(mutating: userData)
        delegates[id] = delegate
        
        var store = signal_protocol_signed_pre_key_store(
            load_signed_pre_key: loadSignedPreKey,
            store_signed_pre_key: storeSignedPreKey,
            contains_signed_pre_key: containsSignedPreKey,
            remove_signed_pre_key: removeSignedPreKey,
            destroy_func: destroy,
            user_data: userPtr)

        let result = withUnsafePointer(to: &store) {
            signal_protocol_store_context_set_signed_pre_key_store(context, $0)
        }
        guard result == 0 else { throw SignalError(value: result) }
    }
}

/**
 Load a local serialized signed PreKey record.

 - parameter record: Pointer to a newly allocated buffer containing the record,
 if found. Unset if no record was found.
 The Signal Protocol library is responsible for freeing this buffer.
 - parameter signedPreKeyId: The ID of the local signed PreKey record
 - returns: SG_SUCCESS if the key was found, SG_ERR_INVALID_KEY_ID if the key could not be found
 */
func loadSignedPreKey(
    _ record: UnsafeMutablePointer<OpaquePointer?>?,
    _ signedPreKeyId: UInt32,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SignedPreKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let key = delegate.load(signedPreKey: signedPreKeyId) else {
        return SG_ERR_INVALID_KEY_ID
    }

    key.copy(to: record!)
    return 0
}

/**
 Store a local serialized signed PreKey record.

 - parameter signedPreKeyId: The ID of the signed PreKey record to store
 - parameter record: Pointer to a buffer containing the serialized record
 - parameter recordLength: Length of the serialized record
 - returns: 0 on success, negative on failure
 */
func storeSignedPreKey(
    _ signedPreKeyId: UInt32,
    _ record: UnsafeMutablePointer<UInt8>?,
    _ recordLength: Int,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SignedPreKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    let keyData = Data(from: record!, length: recordLength)

    guard delegate.store(signedPreKey: keyData, for: signedPreKeyId) else {
        return SignalError.notSuccessful.rawValue
    }
    return 0
}

/**
 Determine whether there is a committed signed PreKey record matching
 the provided ID.

 - parameter signedPreKeyId: A signed PreKey record ID.
 - returns: 1 if the store has a record for the signed PreKey ID, 0 otherwise
 */
func containsSignedPreKey(
    _ signedPreKeyId: UInt32,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SignedPreKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard delegate.contains(signedPreKey: signedPreKeyId) else {
        return 0
    }
    return 1
}

/**
 * Delete a SignedPreKeyRecord from local storage.

 - parameter signedPreKeyId: The ID of the signed PreKey record to remove.
 - parameter userData: Pointer to the user data.
 - returns: 0 on success, negative on failure
 */
func removeSignedPreKey(
    _ signedPreKeyId: UInt32,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SignedPreKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard delegate.remove(signedPreKey: signedPreKeyId) else {
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
    SignedPreKeyStoreWrapper.delegate(for: userData)?.destroy()
}
