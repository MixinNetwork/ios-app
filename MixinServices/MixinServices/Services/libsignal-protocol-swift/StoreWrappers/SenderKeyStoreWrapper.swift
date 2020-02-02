//
//  SenderKeyStoreWrapper.swift
//  libsignal-protocol-swift iOS
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 This class acts as a bridge between the Swift implementation and the C API for the sender key store
 */
final class SenderKeyStoreWrapper: KeyStoreWrapper {

    /// The dictionary of all registered delegates
    static var delegates = [Int : SenderKeyStore]()


    /**
     Set the store for a signal context to act as a sender key store
     - parameter context: The signal context
     - parameter delegate: The store that handles the operations
     - parameter userData: A pointer to the unique id of the delegate
     - returns: `true` on success, `false` on failure
     */
    static func setStore(in context: OpaquePointer, delegate: SenderKeyStore, userData: UnsafeMutablePointer<Int>) throws {

        // Set pointer to unique id as user data to allow the right delegate to handle store callbacks
        let id = userData.pointee
        let userPtr = UnsafeMutableRawPointer(mutating: userData)
        delegates[id] = delegate

        var store = signal_protocol_sender_key_store(
            store_sender_key: storeSenderKey,
            load_sender_key: loadSenderKey,
            destroy_func: destroy,
            user_data: userPtr)

        let result = withUnsafePointer(to: &store) {
            signal_protocol_store_context_set_sender_key_store(context, $0)
        }
        guard result == 0 else { throw SignalError(value: result) }
    }
}

/**
 Store a serialized sender key record for a given
 (groupId + senderId + deviceId) tuple.

 - parameter senderKeyName: the (groupId + senderId + deviceId) tuple
 - parameter record: Pointer to a buffer containing the serialized record
 - parameter recordLength: Length of the serialized record
 - parameter userRecord: Pointer to a buffer containing application specific data to be stored alongside the serialized record. If no such data exists, then this pointer will be null.
 - parameter userRecordLength: Length of the application specific data
 - returns: 0 on success, negative on failure
 */
private func storeSenderKey(
    _ senderKeyName: UnsafePointer<signal_protocol_sender_key_name>?,
    _ record: UnsafeMutablePointer<UInt8>?,
    _ recordLength: Int,
    _ userRecord: UnsafeMutablePointer<UInt8>?,
    _ userRecordLength: Int,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SenderKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let address = SignalSenderKeyName(from: senderKeyName) else {
        return SignalError.noSignalAddress.rawValue
    }

    let recordData = Data(from: record!, length: recordLength)

    var userRecordData: Data? = nil
    if let data = userRecord {
        userRecordData = Data(from: data, length: userRecordLength)
    }

    guard delegate.store(senderKey: recordData, for: address, userRecord: userRecordData) else {
        return SignalError.notSuccessful.rawValue
    }

    return 0
}

/**
 Returns a copy of the sender key record corresponding to the
 (groupId + senderId + deviceId) tuple.

 - parameter record: Pointer to a newly allocated buffer containing the record, if found. Unset if no record was found. The Signal Protocol library is responsible for freeing this buffer.
 - parameter userRecord: Pointer to a newly allocated buffer containing application-specific data stored alongside the record. If no such data exists, then this pointer may be left unset. The Signal Protocol library is responsible for freeing this buffer.
 - parameter senderKeyName: The (groupId + senderId + deviceId) tuple
 - returns: 1 if the record was loaded, 0 if the record was not found, negative on failure
 */
private func loadSenderKey(
    _ record: UnsafeMutablePointer<OpaquePointer?>?,
    _ userRecord: UnsafeMutablePointer<OpaquePointer?>?,
    _ senderKeyName: UnsafePointer<signal_protocol_sender_key_name>?,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SenderKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let address = SignalSenderKeyName(from: senderKeyName) else {
        return SignalError.noSignalAddress.rawValue
    }

    guard let (senderKey, userRecordData) = delegate.loadSenderKey(for: address) else {
        return 0
    }

    senderKey.copy(to: record!)
    userRecordData?.copy(to: userRecord!)
    return 1

}

/**
 Function called to perform cleanup when the data store context is being
 destroyed.
 - parameter userData: Pointer to the user data.
 */
private func destroy(_ userData: UnsafeMutableRawPointer?) {
    SenderKeyStoreWrapper.delegate(for: userData)?.destroy()
}
