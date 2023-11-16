import Foundation
import MixinServices
import Tip

final class RecoverRawTransactionJob: AsynchronousJob {
    
    private enum Error: Swift.Error {
        case notDecodable(String)
        case noAsset(String)
        case missingTransactionResponse
    }
    
    override func getJobId() -> String {
        return "recover-raw-tx"
    }
    
    override func execute() -> Bool {
        Task {
            while let transaction = RawTransactionDAO.shared.firstUnspentRawTransaction(types: [.transfer, .withdrawal]) {
                Logger.general.info(category: "RecoverRawTransaction", message: "Found tx: \(transaction.requestID)")
                let feeTransaction: RawTransaction?
                if RawTransaction.TransactionType(rawValue: transaction.type) == .withdrawal {
                    let feeTraceID = UUID.uniqueObjectIDString(transaction.requestID, "FEE")
                    feeTransaction = RawTransactionDAO.shared.rawTransaction(with: feeTraceID)
                } else {
                    feeTransaction = nil
                }
                do {
                    let response = try await SafeAPI.transaction(id: transaction.requestID)
                    try updateDatabase(with: response, transaction: transaction, feeTransaction: feeTransaction)
                    Logger.general.info(category: "RecoverRawTransaction", message: "Recovered by finding")
                } catch MixinAPIError.notFound {
                    do {
                        var requests = [TransactionRequest(id: transaction.requestID, raw: transaction.rawTransaction)]
                        if let feeTransaction {
                            requests.append(TransactionRequest(id: feeTransaction.requestID, raw: feeTransaction.rawTransaction))
                        }
                        let responses = try await SafeAPI.postTransaction(requests: requests)
                        guard let response = responses.first(where: { $0.requestID == transaction.requestID }) else {
                            throw Error.missingTransactionResponse
                        }
                        try updateDatabase(with: response, transaction: transaction, feeTransaction: feeTransaction)
                        Logger.general.info(category: "RecoverRawTransaction", message: "Recovered by posting")
                    } catch {
                        Logger.general.error(category: "RecoverRawTransaction", message: "Error: \(error)")
                    }
                } catch {
                    Logger.general.error(category: "RecoverRawTransaction", message: "Error: \(error)")
                }
            }
            Logger.general.info(category: "RecoverRawTransaction", message: "Finished")
            self.finishJob()
        }
        return true
    }
    
    private func updateDatabase(with response: TransactionResponse, transaction: RawTransaction, feeTransaction: RawTransaction?) throws {
        var error: NSError?
        let decoded = KernelDecodeRawTx(transaction.rawTransaction, 0, &error)
        if let error {
            throw error
        }
        guard let decodedData = decoded.data(using: .utf8) else {
            throw Error.notDecodable(decoded)
        }
        let data = try JSONDecoder.default.decode(TransactionData.self, from: decodedData)
        let memo = {
            if let encoded = data.extra, let data = Data(base64Encoded: encoded) {
                return String(data: data, encoding: .utf8) ?? ""
            } else {
                return ""
            }
        }()
        guard let assetID = TokenDAO.shared.assetID(ofAssetWith: data.asset) else {
            throw Error.noAsset(data.asset)
        }
        
        var requestIDs = [transaction.requestID]
        if let feeTransaction {
            requestIDs.append(feeTransaction.requestID)
        }
        RawTransactionDAO.shared.signRawTransactions(with: requestIDs) { db in
            let snapshotID = UUID.uniqueObjectIDString(response.userID, ":", response.transactionHash)
            try Trace.filter(key: transaction.requestID).updateAll(db, [Trace.column(of: .snapshotId).set(to: snapshotID)])
            
            guard
                RawTransaction.TransactionType(rawValue: transaction.type) == .transfer,
                !transaction.receiverID.isEmpty
            else {
                return
            }
            let snapshot = SafeSnapshot(id: snapshotID,
                                        type: SafeSnapshot.SnapshotType.snapshot.rawValue,
                                        assetID: assetID,
                                        amount: "-" + response.amount,
                                        userID: response.userID,
                                        opponentID: transaction.receiverID,
                                        memo: memo,
                                        transactionHash: "",
                                        createdAt: response.createdAt,
                                        traceID: response.requestID,
                                        confirmations: nil,
                                        openingBalance: nil,
                                        closingBalance: nil,
                                        deposit: nil,
                                        withdrawal: nil)
            try snapshot.save(db)
            
            let conversationID = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: transaction.receiverID)
            if try !Conversation.exists(db, key: conversationID) {
                DispatchQueue.global().async {
                    ConversationDAO.shared.createPlaceConversation(conversationId: conversationID, ownerId: transaction.receiverID)
                    ConcurrentJobQueue.shared.addJob(job: CreateConversationJob(conversationId: conversationID))
                }
            }
            let message = Message.createMessage(snapshot: snapshot, conversationID: conversationID, createdAt: response.createdAt)
            try MessageDAO.shared.insertMessage(database: db, message: message, messageSource: "RecoverRawTransaction", silentNotification: false)
        }
    }
    
}

extension RecoverRawTransactionJob {
    
    private struct Input: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case hash = "Hash"
            case index = "Index"
        }
        
        let hash: String
        let index: Int
        
    }
    
    private struct TransactionData: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case asset = "Asset"
            case extra = "Extra"
            case inputs = "Inputs"
        }
        
        let asset: String
        let extra: String?
        let inputs: [Input]
        
    }
    
}
