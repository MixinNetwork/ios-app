//
//  SessionBuilder.swift
//  libsignal-protocol-swift
//
//  Created by User on 16.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 Session builder is responsible for setting up encrypted sessions.
 Once a session has been established, session_cipher
 can be used to encrypt/decrypt messages in that session.

 Sessions are built from one these different possible vectors:
 - A session_pre_key_bundle retrieved from a server
 - A pre_key_signal_message received from a client

 Sessions are constructed per Signal Protocol address
 (recipient name + device ID tuple). Remote logical users are identified by
 their recipient name, and each logical recipient can have multiple
 physical devices.
 */
public final class SessionBuilder {

    let remoteAddress: SignalAddress

    let store: SignalStore

    /**
     Constructs a session builder.
     - parameter remoteAddress: The address of the remote user to build a session with
     - parameter store: The store for the keys and state information
     */
    public init(for remoteAddress: SignalAddress, in store: SignalStore) {
        self.remoteAddress = remoteAddress
        self.store = store
    }

    /**
     Build a new session from a session_pre_key_bundle retrieved from a server.

     - note: Possible errors:
     - `untrustedIdentity` if the sender's identity key is not trusted
     - parameter preKeyBundle: A pre key bundle for the destination recipient, retrieved from a server.
     - throws: Errors of type `signalError`
     */
    public func process(preKeyBundle: SessionPreKeyBundle) throws {
        var builder: OpaquePointer? = nil
        var result = withUnsafeMutablePointer(to: &builder) {
            session_builder_create($0, store.storeContext, remoteAddress.signalAddress, Signal.context)
        }
        
        guard result == 0 else { throw SignalError(value: result) }
        defer { session_builder_free(builder) }

        let bundle = try preKeyBundle.pointer()
        defer { session_pre_key_bundle_destroy(bundle) }

        result = session_builder_process_pre_key_bundle(builder, bundle)
        guard result == 0 else { throw SignalError(value: result) }
    }
}
