//
//  SignalError.swift
//  libsignal-protocol-swift
//
//  Created by User on 16.02.18.
//  Copyright © 2018 User. All rights reserved.
//

import Foundation

/**
 Errors thrown by the framework.
 - note: Most errors correspond directly to
 the error codes of `libsignal-protocol-c`.
 */
public enum SignalError: Int32, Error {

    // MARK: libsignal-protocol-c errors

    /// Allocation of memory failed
    case noMemory = -12

    /// An argument to the function was invalid/missing
    case invalidArgument = -22

    /// Unspecified error
    case unknownError = -1000

    /// The message has already been received
    case duplicateMessage = -1001

    /// The key is invalid
    case invalidKey = -1002

    /// The key id is invalid
    case invalidKeyId = -1003

    /// The MAC of a message is invalid
    case invalidMac = -1004

    /// The message is malformed or corrupt
    case invalidMessage = -1005

    /// The version does not match
    case invalidVersion = -1006

    /// The message version is no longer supported
    case legacyMessage = -1007

    /// There is no session saved
    case noSession = -1008

    //case staleKeyExchange = -1009

    /// The identity of the sender is untrusted
    case untrustedIdentity = -1010

    /// The VRF signature is invalid
    case incalidVrfSignature = -1011

    /// The (de)serialization failed
    case invalidProtoBuf = -1100

    /// The fingerprint versions don't match
    case fpVersionMismatch = -1200

    /// The identities of the fingerprints don't match
    case fpIdentityMismatch = -1201

    // MARK: libsignal-protocol-swift errors

    /// There is no delegate registered
    case noDelegate = -2001

    /// No identity key or registration id in the identity key store
    case noData = -2002

    /// A Swift SignalAddress could not be created
    case noSignalAddress = -2003

    /// Retrieving data from a key store failed
    case notSuccessful = -2004

    /// An identity key could not be checked
    case isTrustedFailed = -2005

    /**
     Create a SignalError from a `libsignal-protocol-c` result.
     - note: For unknown error codes the error will be set to `unknownError`
     - parameter value: The result code of an operation.
     */
    public init(value: Int32) {
        if let status = SignalError(rawValue: Int32(value)) {
            self = status
        } else {
            print("Unknown error: \(value)")
            self = .unknownError
        }
    }
}
