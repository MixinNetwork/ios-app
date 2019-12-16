//
//  GroupCipher.swift
//  libsignal-protocol-swift
//
//  Created by User on 17.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import SignalProtocolC

/**
 The main entry point for Signal Protocol group encrypt/decrypt operations.

 Once a session has been established with `GroupSessionBuilder` and a
 sender key distribution message has been distributed to each member of
 the group, this class can be used for all subsequent encrypt/decrypt
 operations within that session (i.e. until group membership changes).
 */
public final class GroupCipher {

    private let remoteAddress: SignalSenderKeyName

    private let store: SignalStore

    /**
     Construct a group cipher for encrypt/decrypt operations.

     - parameter remoteAddress: The groupId + sender
     - parameter store: The key store
     */
    public init(for remoteAddress: SignalSenderKeyName, in store: SignalStore) {
        self.remoteAddress = remoteAddress
        self.store = store
    }

    /**
     Encrypt a message.

     - note: Possible errors are:
     - `noSession` if there is no established session for this contact.
     - `invalidKey` if there is no valid private key for this session.
     - parameter message: The message data to encrypt
     - returns: The ciphertext message encrypted to the group+sender+device tuple.
     - throws: Errors of type `SignalError`
     */
    public func encrypt(_ message: Data) throws -> CiphertextMessage {

        // Create the cipher
        var cipher: OpaquePointer? = nil
        var result = withUnsafeMutablePointer(to: &cipher) {
            group_cipher_create($0, store.storeContext, remoteAddress.pointer, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { group_cipher_free(cipher) }

        // Encrypt message
        var encryptedMessage: OpaquePointer? = nil
        result = message.withUnsafeUInt8Pointer { mPtr in
            withUnsafeMutablePointer(to: &encryptedMessage) {
                group_cipher_encrypt(cipher, mPtr, message.count, $0)
            }
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { signal_type_unref(cipher) }

        // Convert message to data
        guard let serialized = ciphertext_message_get_serialized(encryptedMessage) else {
            throw SignalError.unknownError
        }

        let data = Data(signalBuffer: serialized)
        return CiphertextMessage(type: .senderKey, message: data)
    }

    /**
     Decrypt a message.

     - note: Possible errors:
     - `invalidArgument` if the ciphertext type is not `senderKey`
     - `invalidMessage` if the input is not valid ciphertext
     - `duplicateMessage` if the input is a message that has already been received
     - `legaceMessage` if the input is a message formatted by a protocol version that
     is no longer supported
     - `noSession` if there is no established session for this contact
     - parameter message: The sender key message data to decrypt
     - returns: The decrypted message data
     - throws: Errors of type `SignalError`
     */
    public func decrypt(_ message: CiphertextMessage, callback: DecryptionCallback? = nil) throws -> Data {
        guard message.type == .senderKey else {
            throw SignalError.invalidArgument
        }
        return try decrypt(message.message, callback: callback)
    }

    /**
     Decrypt a message.

     - note: Possible errors:
     - `invalidMessage` if the input is not valid ciphertext
     - `duplicateMessage` if the input is a message that has already been received
     - `legaceMessage` if the input is a message formatted by a protocol version that
     is no longer supported
     - `noSession` if there is no established session for this contact
     - parameter message: The sender key message data to decrypt
     - returns: The decrypted message on success
     - throws: Errors of type `SignalError`
     */
    public func decrypt(_ message: Data, callback: DecryptionCallback?) throws -> Data {

        // Create the cipher
        var cipher: OpaquePointer? = nil
        var result = withUnsafeMutablePointer(to: &cipher) {
            group_cipher_create($0, store.storeContext, remoteAddress.pointer, Signal.context)
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { group_cipher_free(cipher) }

        // Deserialize message
        var senderKeyMessage: OpaquePointer? = nil
        result = message.withUnsafeUInt8Pointer { mPtr in
            withUnsafeMutablePointer(to: &senderKeyMessage) {
                sender_key_message_deserialize($0, mPtr, message.count, Signal.context)
            }
        }
        guard result == 0 else { throw SignalError(value: result) }
        defer { sender_key_message_destroy(senderKeyMessage) }

        if let callback = callback {
            self.decryptionCallback = callback
            setGroupDecryptionCallback(cipher: cipher!) { (groupCipher, plain, decryptContext) -> Int32 in
                if let decryptContext = decryptContext, let plain = plain {
                    let groupCipher = Unmanaged<GroupCipher>.fromOpaque(decryptContext).takeUnretainedValue()
                    groupCipher.decryptionCallback!(Data(signalBuffer: plain))
                    return 1
                }
                return 0
            }
        }

        // Decrypt message
        var plaintext: OpaquePointer? = nil
        let rawSelf = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        result = withUnsafeMutablePointer(to: &plaintext) {
            group_cipher_decrypt(cipher, senderKeyMessage, rawSelf, $0)
        }

        guard result == 0 else { throw SignalError(value: result) }
        defer { signal_buffer_free(plaintext) }

        return Data(signalBuffer: plaintext!)
    }

    private func setGroupDecryptionCallback(cipher: OpaquePointer, cb: @escaping (@convention(c) (OpaquePointer?, OpaquePointer?, UnsafeMutableRawPointer?) -> Int32)) {
        group_cipher_set_decryption_callback(cipher, cb)
    }

    private var decryptionCallback: DecryptionCallback? = nil
}
