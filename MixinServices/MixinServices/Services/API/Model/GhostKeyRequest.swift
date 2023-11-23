import Foundation

public struct GhostKeyRequest: Encodable {
    
    let receivers: [String]
    let index: Int
    let hint: String
    
}

extension GhostKeyRequest {
    
    public static func contactTransfer(receiverID: String, senderID: String, traceID: String) -> [GhostKeyRequest] {
        let output = UUID.uniqueObjectIDString(traceID, "OUTPUT", "0")
        let change = UUID.uniqueObjectIDString(traceID, "OUTPUT", "1")
        return [
            GhostKeyRequest(receivers: [receiverID], index: 0, hint: output),
            GhostKeyRequest(receivers: [senderID], index: 1, hint: change),
        ]
    }
    
    public static func mainnetAddressTransfer(senderID: String, traceID: String) -> [GhostKeyRequest] {
        let change = UUID.uniqueObjectIDString(traceID, "OUTPUT", "1")
        return [GhostKeyRequest(receivers: [senderID], index: 1, hint: change)]
    }
    
    public static func withdrawSubmit(receiverID: String, senderID: String, traceID: String) -> [GhostKeyRequest] {
        // 0 is withdrawal
        let feeOutput = UUID.uniqueObjectIDString(traceID, "OUTPUT", "1")
        let change = UUID.uniqueObjectIDString(traceID, "OUTPUT", "2")
        return [
            GhostKeyRequest(receivers: [receiverID], index: 1, hint: feeOutput),
            GhostKeyRequest(receivers: [senderID], index: 2, hint: change),
        ]
    }
    
    public static func withdrawFee(receiverID: String, senderID: String, traceID: String) -> [GhostKeyRequest] {
        let change = UUID.uniqueObjectIDString(traceID, "OUTPUT", "1")
        let requestID = UUID.uniqueObjectIDString(traceID, "FEE")
        let feeOutput = UUID.uniqueObjectIDString(requestID, "OUTPUT", "0")
        let feeChange = UUID.uniqueObjectIDString(requestID, "OUTPUT", "1")
        return [
            GhostKeyRequest(receivers: [receiverID], index: 0, hint: feeOutput),
            GhostKeyRequest(receivers: [senderID], index: 1, hint: change),
            GhostKeyRequest(receivers: [senderID], index: 1, hint: feeChange),
        ]
    }
    
}
