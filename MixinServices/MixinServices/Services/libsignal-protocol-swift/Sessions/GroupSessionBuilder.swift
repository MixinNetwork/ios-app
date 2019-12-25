//
//  GroupSessionBuilder.swift
//  libsignal-protocol-swift
//
//  Created by User on 17.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import libsignal_protocol_c

/**
 Group session builder is responsible for setting up
 group sender key encrypted sessions.

 Once a session has been established, `GroupCipher`
 can be used to encrypt/decrypt messages in that session.

 The built sessions are unidirectional: they can be
 used either for sending or for receiving, but not both.

 Sessions are constructed per (groupId + senderId + deviceId) tuple.
 Remote logical users are identified by their senderId, and each
 logical recipientId can have multiple physical devices.
 */
public final class GroupSessionBuilder {

    /// The key store in which the group sessions are stored
    let store: SignalStore

    /**
     Constructs a group session builder.

     The store and global contexts must remain valid for the lifetime of the
     session builder.

     - parameter remoteAddress: The (groupId, senderId, deviceId) tuple
     - parameter store: The SignalStore to store all state information in
     */
    public init(in store: SignalStore) {
        self.store = store
    }

    /**
     Construct a group session for receiving messages from senderKeyName.

     - parameter message: A received senderKeyDistributionMessage
     - throws: Errors of type `SignalError`
     */
    public func process(senderKeyDistributionMessage message: CiphertextMessage, from remoteAddress: SignalSenderKeyName) throws {
        guard message.type == .distribution else { throw SignalError.invalidArgument }
        return try process(senderKeyDistributionMessage: message.message, from: remoteAddress)
    }

    /**
     Construct a group session for receiving messages from senderKeyName.

     - parameter message: A received senderKeyDistributionMessage
     - throws: Errors of type `SignalError`
     */
    public func process(senderKeyDistributionMessage message: Data, from remoteAddress: SignalSenderKeyName) throws {

        // Deserialize message
        var messagePtr: OpaquePointer? = nil
        var result = message.withUnsafeUInt8Pointer { mPtr in
            withUnsafeMutablePointer(to: &messagePtr) {
                sender_key_distribution_message_deserialize($0, mPtr, message.count, Signal.context)
            }
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { sender_key_distribution_message_destroy(messagePtr) }

        // Create group builder
        var builder: OpaquePointer? = nil
        result = withUnsafeMutablePointer(to: &builder) {
            group_session_builder_create($0, store.storeContext, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { group_session_builder_free(builder) }

        // Process message
        result = group_session_builder_process_session(builder, remoteAddress.pointer, messagePtr)
        guard result == 0 else { throw SignalError(value: result) }
    }

    /**
     Construct a group session for sending messages.

     * @param distribution_message a distribution message to be allocated and populated
     - parameter localAddress: The (groupId, senderId, deviceId) tuple.
     In this case, the sender should be the caller
     - returns: The result of the operation, and a sender key distribution message on success
     - throws: Errors of type `SignalError`
     */
    public func createSession(for localAddress: SignalSenderKeyName) throws -> CiphertextMessage {

        // Create group builder
        var builder: OpaquePointer? = nil
        var result = withUnsafeMutablePointer(to: &builder) {
            group_session_builder_create($0, store.storeContext, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { group_session_builder_free(builder) }

        // Create message
        var message: OpaquePointer? = nil
        result = withUnsafeMutablePointer(to: &message) {
            group_session_builder_create_session(builder, $0, localAddress.pointer)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { sender_key_distribution_message_destroy(message) }

        // Serialize message
        guard let serialized = ciphertext_message_get_serialized(message) else {
            throw SignalError.unknownError
        }


        // Convert to data
        let mess = Data(signalBuffer: serialized)
        return CiphertextMessage(type: .distribution, message: mess)
    }

    public func getDistributionMessage(for localAddress: SignalSenderKeyName) throws -> CiphertextMessage {

        // Create group builder
        var builder: OpaquePointer? = nil
        var result = withUnsafeMutablePointer(to: &builder) {
            group_session_builder_create($0, store.storeContext, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { group_session_builder_free(builder) }

        // get message
        var message: OpaquePointer? = nil
        result = withUnsafeMutablePointer(to: &message) {
            get_sender_key_distribution_message(builder, $0, localAddress.pointer)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { sender_key_distribution_message_destroy(message) }

        // Serialize message
        guard let serialized = ciphertext_message_get_serialized(message) else {
            throw SignalError.unknownError
        }


        // Convert to data
        let mess = Data(signalBuffer: serialized)
        return CiphertextMessage(type: .distribution, message: mess)
    }
}
