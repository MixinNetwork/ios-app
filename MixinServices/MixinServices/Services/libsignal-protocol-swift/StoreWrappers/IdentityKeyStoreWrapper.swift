//
//  IdentityKeyStoreWrapper.swift
//  libsignal-protocol-swift iOS
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 This class acts as a bridge between the Swift implementation and the C API for the identity key store
 */
final class IdentityKeyStoreWrapper: KeyStoreWrapper {

    /// The dictionary of all registered delegates
    static var delegates = [Int : IdentityKeyStore]()

    /**
     Set the store for a signal context to act as an identity store.
     - parameter context: The signal context
     - parameter delegate: The store that handles the operations
     - parameter userData: A pointer to the unique id of the delegate
     - returns: `true` on success, `false` on failure
     */
    static func setStore(in context: OpaquePointer, delegate: IdentityKeyStore, userData: UnsafeMutablePointer<Int>) throws {

        // Set pointer to unique id as user data to allow the right delegate to handle store callbacks
        let id = userData.pointee
        let userPtr = UnsafeMutableRawPointer(mutating: userData)
        delegates[id] = delegate

        var store = signal_protocol_identity_key_store(
            get_identity_key_pair: getIdentityKeyPair,
            get_local_registration_id: getLocalRegistrationId,
            save_identity: saveIdentity,
            is_trusted_identity: isUntrustedIdentity,
            destroy_func: destroy,
            user_data: userPtr)

        let result = withUnsafePointer(to: &store) {
            signal_protocol_store_context_set_identity_key_store(context, $0)
        }
        guard result == 0 else { throw SignalError(value: result) }
    }
}

/**
 Get the local client's identity key pair.

 - parameter publicData: pointer to a newly allocated buffer containing the
     public key, if found. Unset if no record was found.
     The Signal Protocol library is responsible for freeing this buffer.
 - parameter privateData: pointer to a newly allocated buffer containing the
     private key, if found. Unset if no record was found.
     The Signal Protocol library is responsible for freeing this buffer.
 - parameter userData: Pointer to the user data.
 - returns: 0 on success, negative on failure
 */
private func getIdentityKeyPair(
    _ publicData: UnsafeMutablePointer<OpaquePointer?>?,
    _ privateData: UnsafeMutablePointer<OpaquePointer?>?,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = IdentityKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let keyPair = delegate.identityKeyPair() else {
        return SignalError.noData.rawValue
    }

    // Will be deallocated by signal library
    keyPair.publicKey.copy(to: publicData!)
    keyPair.privateKey.copy(to: privateData!)
    return 0
}

/**
 Return the local client's registration ID.

 Clients should maintain a registration ID, a random number
 between 1 and 16380 that's generated once at install time.

 - parameter userData: Pointer to the user data.
 - parameter registrationId: Pointer to be set to the local client's
     registration Id, if it was successfully retrieved.
 - returns: 0 on success, negative on failure
 */
private func getLocalRegistrationId(
    _ userData: UnsafeMutableRawPointer?,
    _ registrationId: UnsafeMutablePointer<UInt32>?) -> Int32 {

    guard let delegate = IdentityKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let id = delegate.localRegistrationId() else {
        return SignalError.noData.rawValue
    }

    registrationId!.pointee = id
    return 0
}

/**
 Save a remote client's identity key

 Store a remote client's identity key as trusted.
 The value of key_data may be null. In this case remove the key data
 from the identity store, but retain any metadata that may be kept
 alongside it.

 - parameter address: The address of the remote client
 - parameter keyData: Pointer to the remote client's identity key, may be null
 - parameter keyLength: Length of the remote client's identity key
 - parameter userData: Pointer to the user data.
 - returns: 0 on success, negative on failure
 */
private func saveIdentity(
    _ address: UnsafePointer<signal_protocol_address>?,
    _ keyData: UnsafeMutablePointer<UInt8>?,
    _ keyLength: Int,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = IdentityKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let add = SignalAddress(from: address) else {
        return SignalError.noSignalAddress.rawValue
    }

    var key: Data? = nil
    if let data = keyData {
        key = Data(from: data, length: keyLength)
    }

    guard delegate.save(identity: key, for: add) else {
        return SignalError.notSuccessful.rawValue
    }
    return 0
}

/**
 Verify a remote client's identity key.

 Determine whether a remote client's identity is trusted.  Convention is
 that the TextSecure protocol is 'trust on first use.'  This means that
 an identity key is considered 'trusted' if there is no entry for the recipient
 in the local store, or if it matches the saved key for a recipient in the local
 store.  Only if it mismatches an entry in the local store is it considered
 'untrusted.'

 - parameter address: the address of the remote client
 - parameter keyData: Pointer to the identity key to verify
 - parameter keyLen: Length of the identity key to verify
 - parameter userData: Pointer to the user data.
 - returns: 1 if trusted, 0 if untrusted, negative on failure
 */
private func isUntrustedIdentity(
    _ address: UnsafePointer<signal_protocol_address>?,
    _ keyData: UnsafeMutablePointer<UInt8>?,
    _ keyLength: Int,
    _ userData: UnsafeMutableRawPointer?) -> Int32 {

    guard let delegate = IdentityKeyStoreWrapper.delegate(for: userData) else {
        return SignalError.noDelegate.rawValue
    }

    guard let add = SignalAddress(from: address) else {
        return SignalError.noSignalAddress.rawValue
    }

    let key = Data(from: keyData!, length: keyLength)

    guard let result = delegate.isTrusted(identity: key, for: add) else {
        return SignalError.isTrustedFailed.rawValue
    }
    return result ? 1 : 0
}

/**
 Function called to perform cleanup when the data store context is being
 destroyed.
 - parameter userData: Pointer to the user data.
 */
private func destroy(_ userData: UnsafeMutableRawPointer?) {
    IdentityKeyStoreWrapper.delegate(for: userData)?.destroy()
}
