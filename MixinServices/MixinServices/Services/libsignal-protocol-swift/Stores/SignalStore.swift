//
//  SignalStore.swift
//  libsignal-protocol-swift
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 A `SignalStore` provides access to all required data stores for a client.
 */
public final class SignalStore {

    /// Count of all active stores
    private static var instanceCount = 0

    /// Pointer to store, used to identify delegate in callbacks
    private let instanceId: UnsafeMutablePointer<Int>

    /// The store context pointer of the instance
    let storeContext: OpaquePointer

    /// The delegate that handles the identity key store operations
    public let identityKeyStore: IdentityKeyStore

    /// The delegate that handles the pre key store operations
    public let preKeyStore: PreKeyStore

    /// The delegate that handles the session store operations
    public let sessionStore: SessionStore

    /// The delegate that handles the signed pre key store operations
    public let signedPreKeyStore: SignedPreKeyStore

    /// The delegate that handles the sender key store operations, optional
    public let senderKeyStore: SenderKeyStore?

    /**
     Create a `SignalStore` with the necessary delegates.
     - parameter identityKeyStore: The identity key store for this instance
     - parameter preKeyStore: The pre key store for this instance
     - parameter sessionStore: The session store for this instance
     - parameter signedPreKeyStore: The signed pre key store for this instance
     - parameter senderKeyStore: The (optional) sender key store for this instance, only needed for group messages
     - throws: Errors of type `SignalError`
     */
    public init(identityKeyStore: IdentityKeyStore,
         preKeyStore: PreKeyStore,
         sessionStore: SessionStore,
         signedPreKeyStore: SignedPreKeyStore,
         senderKeyStore: SenderKeyStore?) throws {

        var store: OpaquePointer? = nil
        let result = withUnsafeMutablePointer(to: &store) {
            signal_protocol_store_context_create($0, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }

        self.instanceId = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        self.instanceId.pointee = SignalStore.instanceCount
        SignalStore.instanceCount += 1

        self.storeContext = store!
        self.identityKeyStore = identityKeyStore
        self.preKeyStore = preKeyStore
        self.senderKeyStore = senderKeyStore
        self.sessionStore = sessionStore
        self.signedPreKeyStore = signedPreKeyStore

        try registerDelegates()
    }

    /// Add delegates to wrapper classes
    private func registerDelegates() throws {
        try IdentityKeyStoreWrapper.setStore(in: storeContext, delegate: identityKeyStore, userData: instanceId)
        try PreKeyStoreWrapper.setStore(in: storeContext, delegate: preKeyStore, userData: instanceId)
        try SessionStoreWrapper.setStore(in: storeContext, delegate: sessionStore, userData: instanceId)
        try SignedPreKeyStoreWrapper.setStore(in: storeContext, delegate: signedPreKeyStore, userData: instanceId)
        if senderKeyStore != nil {
            try SenderKeyStoreWrapper.setStore(in: storeContext, delegate: senderKeyStore!, userData: instanceId)
        }
    }

    /// Remove delegates from wrapper classes
    private func unregisterDelegates() {
        let id = instanceId.pointee

        IdentityKeyStoreWrapper.removeDelegate(for: id)
        PreKeyStoreWrapper.removeDelegate(for: id)
        SenderKeyStoreWrapper.removeDelegate(for: id)
        SessionStoreWrapper.removeDelegate(for: id)
        SignedPreKeyStoreWrapper.removeDelegate(for: id)
    }

    deinit {
        unregisterDelegates()
        self.instanceId.deallocate()
        signal_protocol_store_context_destroy(storeContext)
    }
}
