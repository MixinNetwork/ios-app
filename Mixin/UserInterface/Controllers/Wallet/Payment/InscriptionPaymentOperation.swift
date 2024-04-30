import Foundation
import MixinServices
import TIP

struct InscriptionPaymentOperation {
    
    enum Error: Swift.Error, LocalizedError {
        
        case sign(Swift.Error?)
        case invalidTransactionResponse
        
        var errorDescription: String? {
            switch self {
            case .sign(let error):
                return error?.localizedDescription ?? "Null signature"
            case .invalidTransactionResponse:
                return "Invalid txresp"
            }
        }
        
    }
    
    let traceID: String
    let opponent: UserItem
    let inscription: InscriptionItem
    let memo = ""
    
    func start(pin: String) async throws {
        guard let output = OutputDAO.shared.getAsset(inscriptionHash: inscription.inscriptionHash),
              let amount = Decimal(string: output.amount, locale: .enUSPOSIX) else {
            return
        }
        guard let assetId = TokenDAO.shared.assetID(ofAssetWith: output.asset) else {
            return
        }
        
        let spendingOutputs = UTXOService.OutputCollection(outputs: [output], amount: amount)
        let traceID = self.traceID
        let kernelAssetID = output.asset
        let senderID = myUserId
        Logger.general.info(category: "Inscription", message: "Inscription: \(amount), to \(opponent.userId), traceID: \(traceID)")
        
        let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
        Logger.general.info(category: "Transfer", message: "SpendKey ready")
        
        let spendingOutputIDs = spendingOutputs.outputs.map(\.id)
        Logger.general.info(category: "Transfer", message: "Spending \(spendingOutputs.debugDescription), id: \(spendingOutputIDs)")
        
        let inputsData = try spendingOutputs.encodeAsInputData()
        let outputKeys = try spendingOutputs.encodedKeys()
        
        let ghostKeyRequests = GhostKeyRequest.contactTransfer(receiverIDs: [opponent.userId], senderIDs: [senderID], traceID: traceID)
        let ghostKeys = try await SafeAPI.ghostKeys(requests: ghostKeyRequests)
        
        let receiverGhostKey = ghostKeys.first!
        let receiverKeys = receiverGhostKey.keys.joined(separator: ",")
        let receiverMask = receiverGhostKey.mask
        
        let changeGhostKey = ghostKeys.last!
        let changeKeys = changeGhostKey.keys.joined(separator: ",")
        let changeMask = changeGhostKey.mask
        
        var error: NSError?
        let tx = KernelBuildTx(kernelAssetID,
                               output.amount,
                               1,
                               receiverKeys,
                               receiverMask,
                               inputsData,
                               changeKeys,
                               changeMask,
                               "",
                               "",
                               &error)
        
        if let error {
            throw error
        }
        Logger.general.info(category: "Transfer", message: "Tx built")
        
        let verifyRequest = TransactionRequest(id: traceID, raw: tx)
        Logger.general.info(category: "Transfer", message: "Will verify: \(verifyRequest.id)")
        let verifyResponses = try await SafeAPI.requestTransaction(requests: [verifyRequest])
        guard let verifyResponse = verifyResponses.first(where: { $0.requestID == verifyRequest.id }) else {
            throw Error.invalidTransactionResponse
        }
        let viewKeys = verifyResponse.views.joined(separator: ",")
        let signedTx = KernelSignTx(tx, outputKeys, viewKeys, spendKey, false, &error)
        guard let signedTx, error == nil else {
            throw Error.sign(error)
        }
        Logger.general.info(category: "Transfer", message: "Tx signed")
        
        let now = Date().toUTCString()
        let changeOutput: Output?
        if let change = signedTx.change {
            let output = Output(change: change,
                                asset: kernelAssetID,
                                mask: changeMask,
                                keys: changeGhostKey.keys,
                                lastOutput: spendingOutputs.lastOutput)
            Logger.general.info(category: "Transfer", message: "Created change output: \(output.id), amount: \(change.amount)")
            changeOutput = output
        } else {
            changeOutput = nil
            Logger.general.info(category: "Transfer", message: "No change")
        }
        
        Logger.general.info(category: "Transfer", message: "Will sign outputs")
        let rawTransactionReceiverID = opponent.userId
        let snapshotOpponentID = opponent.userId
        let rawTransaction = RawTransaction(requestID: traceID,
                                            rawTransaction: signedTx.raw,
                                            receiverID: rawTransactionReceiverID,
                                            state: .unspent,
                                            type: .transfer,
                                            createdAt: now)
        let snapshot = SafeSnapshot(type: .snapshot,
                                    assetID: assetId,
                                    amount: "-" + output.amount,
                                    userID: senderID,
                                    opponentID: snapshotOpponentID,
                                    memo: memo.data(using: .utf8)?.hexEncodedString() ?? memo,
                                    transactionHash: signedTx.hash,
                                    createdAt: now,
                                    traceID: traceID,
                                    inscriptionHash: inscription.inscriptionHash)
        let trace = Trace(traceId: traceID,
                          assetId: assetId,
                          amount: output.amount,
                          opponentId: snapshotOpponentID,
                          destination: nil,
                          tag: nil,
                          snapshotId: snapshot.id)
        OutputDAO.shared.signOutputs(with: spendingOutputIDs) { db in
            try changeOutput?.save(db)
            try SafeSnapshotDAO.shared.save(snapshot: snapshot, db: db)
            try trace.save(db)
            if opponent.isCreatedByMessenger {
                let receiverID = opponent.userId
                let conversationID = ConversationDAO.shared.makeConversationId(userId: senderID, ownerUserId: receiverID)
                let message = Message.createMessage(snapshot: snapshot, conversationID: conversationID, createdAt: now)
                try MessageDAO.shared.insertMessage(database: db, message: message, messageSource: "Transfer", silentNotification: false)
                if try !Conversation.exists(db, key: conversationID) {
                    let conversation = Conversation.createConversation(conversationId: conversationID,
                                                                       category: ConversationCategory.CONTACT.rawValue,
                                                                       recipientId: receiverID,
                                                                       status: ConversationStatus.START.rawValue)
                    try conversation.save(db)
                    db.afterNextTransaction { _ in
                        let createConversation = CreateConversationJob(conversationId: conversationID)
                        ConcurrentJobQueue.shared.addJob(job: createConversation)
                    }
                }
            }
            try rawTransaction.save(db)
            try UTXOService.shared.updateBalance(assetID: assetId, kernelAssetID: kernelAssetID, db: db)
            Logger.general.info(category: "Transfer", message: "Outputs signed")
        }
        
        let broadcastRequest = TransactionRequest(id: traceID, raw: signedTx.raw)
        try await SafeAPI.withRetryingOnServerError(maxNumberOfTries: 20) {
            Logger.general.info(category: "Transfer", message: "Will broadcast tx: \(broadcastRequest.id), hash: \(signedTx.hash)")
            try await SafeAPI.postTransaction(requests: [broadcastRequest])
        } shouldRetry: {
            do {
                _ = try await SafeAPI.transaction(id: traceID)
                Logger.general.warn(category: "Transfer", message: "Found tx, stop retrying")
                return false
            } catch {
                Logger.general.warn(category: "Transfer", message: "Keep retrying: \(error)")
                return true
            }
        }
        Logger.general.info(category: "Transfer", message: "Will sign raw txs")
        RawTransactionDAO.shared.signRawTransactions(with: [rawTransaction.requestID])
        Logger.general.info(category: "Transfer", message: "RawTx signed")
    }
    
}
