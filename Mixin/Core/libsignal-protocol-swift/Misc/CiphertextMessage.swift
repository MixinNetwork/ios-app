//
//  CiphertextMessage.swift
//  libsignal-protocol-swift
//
//  Created by User on 16.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import SignalProtocolC

/**
 A `CiphertextMessage` is an encrypted message ready for delivery. It can be one
 of several types.
 */
public struct CiphertextMessage {

    /// The message type of an encrypted message
    public enum MessageType: UInt8 {

        /// A signal message
        case signal = 2

        /// A pre key signal message to establish a session
        case preKey = 3

        /// A sender key message
        case senderKey = 4

        /// A sender key distribution message to esatblish a group session
        case distribution = 5

        /// Unknown message type
        case unknown

        /**
        Create a ciphertext message type from an Int32 value.
         - note: If the type value does not correspond to a recognised
         type, then the type will be `unknown`
         - parameter value: The raw value of the type
         */
        init(_ value: Int32) {
            switch value {
            case 2...5: self = MessageType(rawValue: UInt8(value))!
            default:    self = .unknown
            }
        }

        /**
         Create a ciphertext message type from a UInt8 value.
         - note: If the type value does not correspond to a recognised
         type, then the type will be `unknown`
         - parameter value: The raw value of the type
         */
        init(_ value: UInt8) {
            switch value {
            case 2...5: self = MessageType(rawValue: value)!
            default:    self = .unknown
            }
        }
    }

    /// The type of the message
    public let type: MessageType

    /// The message data
    public let message: Data

    /**
     Create a CiphertextMessage from type and data.
     - parameter type: The message type
     - parameter data: The encrypted data
     */
    init(type: MessageType, message: Data) {
        self.type = type
        self.message = message
    }

    /**
     Create a message from a `ciphertext_message` pointer
     */
    init(pointer: OpaquePointer) {
        let messageType = ciphertext_message_get_type(pointer)
        self.type = MessageType(messageType)
        let ptr = ciphertext_message_get_serialized(pointer)
        self.message = Data(signalBuffer: ptr!)
    }

    /**
     Create a message from serialized data.
     - parameter data: The serialized message, containing the message type at the first byte.
     */
    public init(from data: Data) {
        guard data.count > 0 else {
            self.type = .unknown
            self.message = Data()
            return
        }
        self.type = MessageType(data[0])
        self.message = data.advanced(by: 1)
    }
}
