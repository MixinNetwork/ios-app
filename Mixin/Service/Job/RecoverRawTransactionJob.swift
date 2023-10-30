import Foundation
import MixinServices
import Tip

final class RecoverRawTransactionJob: AsynchronousJob {
    
    private enum Error: Swift.Error {
        case notDecodable(String)
        case noAsset(String)
    }
    
    override func getJobId() -> String {
        return "recover-raw-tx"
    }
    
    override func execute() -> Bool {
        Task {
            while let tx = RawTransactionDAO.shared.firstRawTransaction() {
                Logger.general.info(category: "RecoverRawTransaction", message: "Found tx: \(tx.requestID)")
                do {
                    let response = try await SafeAPI.transaction(id: tx.requestID)
                    try updateDatabase(with: response, transaction: tx)
                    Logger.general.info(category: "RecoverRawTransaction", message: "Recovered by finding")
                } catch MixinAPIError.notFound {
                    do {
                        let response = try await SafeAPI.postTransaction(requestID: tx.requestID, raw: tx.rawTransaction)
                        try updateDatabase(with: response, transaction: tx)
                        Logger.general.info(category: "RecoverRawTransaction", message: "Recovered by posting")
                    } catch {
                        Logger.general.error(category: "RecoverRawTransaction", message: "Error: \(error)")
                    }
                } catch {
                    Logger.general.error(category: "RecoverRawTransaction", message: "Error: \(error)")
                }
            }
            self.finishJob()
        }
        return true
    }
    
    private func updateDatabase(with response: TransactionResponse, transaction: RawTransaction) throws {
        var error: NSError?
        let decoded = KernelDecodeRawTx(transaction.rawTransaction, 0, &error)
        if let error {
            throw error
        }
        guard let decodedData = decoded.data(using: .utf8) else {
            throw Error.notDecodable(decoded)
        }
        let data = try JSONDecoder.default.decode(TransactionData.self, from: decodedData)
        guard let assetID = TokenDAO.shared.assetID(ofAssetWith: data.asset) else {
            throw Error.noAsset(data.asset)
        }
        let memo = {
            if let encoded = data.extra, let data = Data(base64Encoded: encoded) {
                return String(data: data, encoding: .utf8) ?? ""
            } else {
                return ""
            }
        }()
        let outputIDs = data.inputs.map { input in
            "\(input.hash):\(input.index)".uuidDigest()
        }
        let snapshot = SafeSnapshot(id: "\(response.userID):\(response.transactionHash)".uuidDigest(),
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
                                    closingBalance: nil)
        let conversationID = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: transaction.receiverID)
        let message = Message.createMessage(snapshot: snapshot, conversationID: conversationID, createdAt: response.createdAt)
        OutputDAO.shared.spendOutputs(with: outputIDs, raw: transaction, snapshot: snapshot, message: message)
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
