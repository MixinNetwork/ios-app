import Foundation
import CryptoKit

enum TIPBody {
    
    enum Error: Swift.Error {
        case stringEncoding
    }
    
    static func verify(timestamp: UInt64) throws -> Data {
        let raw = "TIP:VERIFY:" + String(format: "%032lu", timestamp)
        if let data = raw.data(using: .utf8) {
            return data
        } else {
            throw Error.stringEncoding
        }
    }
    
    static func addAddres(assetID: String, publicKey: String?, keyTag: String?, name: String?) throws -> Data {
        try hashData("TIP:ADDRESS:ADD:", assetID, publicKey, keyTag, name)
    }
    
    static func removeAddress(addressID: String) throws -> Data {
        try hashData("TIP:ADDRESS:REMOVE:", addressID)
    }
    
    static func deactivateUser(phoneVerificationID: String) throws -> Data {
        try hashData("TIP:USER:DEACTIVATE:", phoneVerificationID)
    }
    
    static func createEmergencyContact(verificationID: String, code: String) throws -> Data {
        try hashData("TIP:EMERGENCY:CONTACT:CREATE:", verificationID, code)
    }
    
    static func readEmergencyContact() throws -> Data {
        try hashData("TIP:EMERGENCY:CONTACT:READ:0")
    }
    
    static func removeEmergencyContact() throws -> Data {
        try hashData("TIP:EMERGENCY:CONTACT:REMOVE:0")
    }
    
    static func updatePhoneNumber(verificationID: String, code: String) throws -> Data {
        try hashData("TIP:PHONE:NUMBER:UPDATE:", verificationID, code)
    }
    
    static func signMultisigRequest(id: String) throws -> Data {
        try hashData("TIP:MULTISIG:REQUEST:SIGN:", id)
    }
    
    static func unlockMultisigRequest(id: String) throws -> Data {
        try hashData("TIP:MULTISIG:REQUEST:UNLOCK:", id)
    }
    
    static func signCollectibleRequest(id: String) throws -> Data {
        try hashData("TIP:COLLECTIBLE:REQUEST:SIGN:", id)
    }
    
    static func unlockCollectibleRequest(id: String) throws -> Data {
        try hashData("TIP:COLLECTIBLE:REQUEST:UNLOCK:", id)
    }
    
    static func transfer(assetID: String, oppositeUserID: String, amount: String, traceID: String?, memo: String?) throws -> Data {
        try hashData("TIP:TRANSFER:CREATE:", assetID, oppositeUserID, amount, traceID, memo)
    }
    
    static func createWithdrawal(addressID: String, amount: String, fee: String?, traceID: String, memo: String?) throws -> Data {
        try hashData("TIP:WITHDRAWAL:CREATE:", addressID, amount, fee, traceID, memo)
    }
    
    static func createRawTransaction(assetID: String, opponentKey: String, opponentReceivers: [String], opponentThreshold: Int, amount: String, traceID: String?, memo: String?) throws -> Data {
        try hashData("TIP:TRANSACTION:CREATE:", assetID, opponentKey, opponentReceivers.joined(), String(opponentThreshold), amount, traceID, memo)
    }
    
    static func authorizeRequest(authorizationId: String) throws -> Data {
        try hashData("TIP:OAUTH:APPROVE:", authorizationId)
    }
    
    static func updateProvisioning(id: String, secret: String) throws -> Data {
        try hashData("TIP:PROVISIONING:UPDATE:", id, secret)
    }
    
    @inline(__always)
    private static func hashData(_ arguments: String?...) throws -> Data {
        let string = arguments.compactMap({ $0 }).joined()
        guard let data = string.data(using: .utf8) else {
            throw Error.stringEncoding
        }
        let hash = SHA256.hash(data: data)
        return Data(hash)
    }
    
}
