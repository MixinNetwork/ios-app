//
//  SessionStoreWrapper.swift
//  libsignal-protocol-swift
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import SignalProtocolC

/**
 This class acts as a bridge between the Swift implementation and the C API for the session store
 */
final class SessionStoreWrapper: KeyStoreWrapper {

    /// The dictionary of all registered delegates
    static var delegates = [Int : SessionStore]()

    /**
     Set the store for a signal context to act as a session store
     - parameter context: The signal context
     - parameter delegate: The store that handles the operations
     - parameter userData: A pointer to the unique id of the delegate
     - returns: `true` on success, `false` on failure
     */
    static func setStore(in context: OpaquePointer, delegate: SessionStore, userData: UnsafeMutablePointer<Int>) throws {

        // Set pointer to unique id as user data to allow the right delegate to handle store callbacks
        let id = userData.pointee
        let userPtr = UnsafeMutableRawPointer(mutating: userData)
        delegates[id] = delegate

        var store = signal_protocol_session_store(
            load_session_func: loadSession,
            get_sub_device_sessions_func: getSubDeviceSessions,
            store_session_func: storeSession,
            contains_session_func: containsSession,
            delete_session_func: deleteSession,
            delete_all_sessions_func: deleteAllSessions,
            destroy_func: destroy,
            user_data: userPtr)
        
        let result = withUnsafePointer(to: &store) {
            signal_protocol_store_context_set_session_store(context, $0)
        }
        guard result == 0 else { throw SignalError(value: result) }
    }
}

/**
 Returns a copy of the serialized session record corresponding to the
 provided recipient ID + device ID tuple.

 - parameter record: Pointer to a freshly allocated buffer containing the
 serialized session record. Unset if no record was found.
 The Signal Protocol library is responsible for freeing this buffer.
 - parameter userRecord: Pointer to a freshly allocated buffer containing
 application specific data stored alongside the serialized session
 record. If no such data exists, then this pointer may be left unset.
 The Signal Protocol library is responsible for freeing this buffer.
 - parameter address: The address of the remote client
 - parameter userData: Pointer to the user data.
 - returns: 1 if the session was loaded, 0 if the session was not found, negative on failure
 */
func loadSession(
    _ record: UnsafeMutablePointer<OpaquePointer?>?,
    _ userRecord: UnsafeMutablePointer<OpaquePointer?>?,
    _ address: UnsafePointer<signal_protocol_address>?,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SessionStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }
    guard let add = SignalAddress(from: address) else {
        return SignalError.noSignalAddress.rawValue
    }

    guard let (session, userData) = delegate.loadSession(for: add) else {
        return 0
    }

    session.copy(to: record!)
    userData?.copy(to: userRecord!)
    return 1
}

/**
 Returns all known devices with active sessions for a recipient
 
 - parameter sessions: Pointer to an array that will be allocated and populated with the result
 - parameter name: The name of the remote client
 - parameter nameLength: The length of the name
 - parameter userData: Pointer to the user data.
 - returns: size of the sessions array, or negative on failure
 */
func getSubDeviceSessions(
    _ sessions: UnsafeMutablePointer<OpaquePointer?>?,
    _ name: UnsafePointer<Int8>?,
    _ nameLength: Int,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SessionStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let namePtr = name else {
        return SignalError.noSignalAddress.rawValue
    }

    let nameString = String(cString: namePtr)

    guard let results = delegate.subDeviceSessions(for: nameString) else {
        return SignalError.notSuccessful.rawValue
    }

    guard let list = signal_int_list_alloc() else {
        return SG_ERR_NOMEM
    }

    // Copy items to list
    for item in results {
        let result = signal_int_list_push_back(list, item)
        guard result == 0 else {
            return result
        }
    }

    sessions?.pointee = list
    return 0
}

/**
 Commit to storage the session record for a given
 recipient ID + device ID tuple.

 - parameter address: The address of the remote client
 - parameter record: Pointer to a buffer containing the serialized session
     record for the remote client
 - parameter recordLength: Length of the serialized session record
 - parameter userRecord: Pointer to a buffer containing application specific
     data to be stored alongside the serialized session record for the
     remote client. If no such data exists, then this pointer will be null.
 - parameter userRecordLength: length of the application specific data
 - parameter userData: Pointer to the user data.
 - returns: 0 on success, negative on failure
 */
func storeSession(
    _ address: UnsafePointer<signal_protocol_address>?,
    _ record: UnsafeMutablePointer<UInt8>?,
    _ recordLength: Int,
    _ userRecord: UnsafeMutablePointer<UInt8>?,
    _ userRecordLength: Int,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SessionStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let add = SignalAddress(from: address) else {
        return SignalError.noSignalAddress.rawValue
    }

    let recordData = Data(from: record!, length: recordLength)

    var userRecordData: Data? = nil
    if let data = userRecord {
        userRecordData = Data(from: data, length: userRecordLength)
    }

    guard delegate.store(session: recordData, for: add, userRecord: userRecordData) else {
        return SignalError.notSuccessful.rawValue
    }
    return 0
}

/**
 Determine whether there is a committed session record for a
 recipient ID + device ID tuple.

 - parameter address: the address of the remote client
 - parameter userData: Pointer to the user data.
 - returns: 1 if a session record exists, 0 otherwise.
 */
func containsSession(
    _ address: UnsafePointer<signal_protocol_address>?,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SessionStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let add = SignalAddress(from: address) else {
        return SignalError.noSignalAddress.rawValue
    }

    let result = delegate.containsSession(for: add)
    return result ? 1 : 0
}

/**
 Remove a session record for a recipient ID + device ID tuple.
 *
 - parameter address: The address of the remote client
 - parameter userData: Pointer to the user data.
 - returns: 1 if a session was deleted, 0 if a session was not deleted, negative on error
 */
func deleteSession(
    _ address: UnsafePointer<signal_protocol_address>?,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SessionStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let add = SignalAddress(from: address) else {
        return SignalError.noSignalAddress.rawValue
    }

    guard let result = delegate.deleteSession(for: add) else {
        return SignalError.notSuccessful.rawValue
    }
    return result ? 1 : 0
}

/**
 Remove the session records corresponding to all devices of a recipient ID.

 - parameter name: The name of the remote client
 - parameter nameLength: The length of the name
 - parameter userData: Pointer to the user data.
 - returns: the number of deleted sessions on success, negative on failure
 */
func deleteAllSessions(
    _ name: UnsafePointer<Int8>?,
    _ nameLength: Int,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = SessionStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let namePtr = name else {
        return SignalError.noSignalAddress.rawValue
    }

    let nameString = String(cString: namePtr)

    guard let result = delegate.deleteAllSessions(for: nameString) else {
        return SignalError.notSuccessful.rawValue
    }
    return Int32(result)
}

/**
 Function called to perform cleanup when the data store context is being
 destroyed.
 - parameter userData: Pointer to the user data.
 */
private func destroy(_ userData: UnsafeMutableRawPointer?) {
    SessionStoreWrapper.delegate(for: userData)?.destroy()
}
