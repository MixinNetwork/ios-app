//
//  SignalSenderKeyName.swift
//  libsignal-protocol-swift
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation
import SignalProtocolC

/**
 The identifier of a party in a group conversation setting.
 */
public final class SignalSenderKeyName {

    /// The group identifier
    public let groupId: String

    /// The sender/recipient
    public let sender: SignalAddress

    private let groupPointer: UnsafeMutablePointer<Int8>

    private let address: UnsafeMutablePointer<signal_protocol_sender_key_name>

    var pointer: UnsafePointer<signal_protocol_sender_key_name> {
        return UnsafePointer(address)
    }

    /**
     Create a sender key name.
     - parameter groupId: the identifier of the group
     - parameter sender: The sender of the messages
     */
    public init(groupId: String, sender: SignalAddress) {
        self.groupId = groupId
        self.sender = sender
        let count = groupId.utf8.count
        self.groupPointer = UnsafeMutablePointer<Int8>(mutating: (groupId as NSString).utf8String!)
        // groupPointer.assign(from: groupId, count: count)
        self.address = UnsafeMutablePointer<signal_protocol_sender_key_name>.allocate(capacity: 1)

        address.pointee = signal_protocol_sender_key_name(group_id: groupPointer, group_id_len: count, sender: sender.signalAddress.pointee)
    }

    /**
     Create an a sender key name from a pointer to a libsignal-protocol-c address.
     - parameter address: The pointer to the address
     */
    convenience init?(from address: UnsafePointer<signal_protocol_sender_key_name>?) {
        guard let add = address?.pointee else {
            return nil
        }
        self.init(from: add)
    }

    /**
     Create an a sender key name from a libsignal-protocol-c address.
     - parameter address: The libsignal-protocol-c address
     */
    convenience init?(from address: signal_protocol_sender_key_name) {
        guard let groupPtr = address.group_id,
            let sender = SignalAddress(from: address.sender) else {
            return nil
        }
        self.init(groupId: String(cString: groupPtr), sender: sender)
    }

    deinit {
        // groupPointer.deallocate(capacity: groupId.utf8.count)
        // TODO
        // signalAddress.deallocate()
        address.deallocate()
    }
}

extension SignalSenderKeyName: Equatable {

    /**
    Compare two sender key names for equality
    - parameter lhs: The first address
    - parameter rhs: The second address
    - returns: `true` if the sender key names match
    */
    public static func == (lhs: SignalSenderKeyName, rhs: SignalSenderKeyName) -> Bool {
        return lhs.groupId == rhs.groupId && lhs.sender == rhs.sender
    }

}

extension SignalSenderKeyName: Hashable {
    
    /// The hash of the sender key name
    public func hash(into hasher: inout Hasher) {
        let value = groupId.hashValue &+ sender.hashValue
        hasher.combine(value)
    }
    
}
