import Foundation
import MixinServices
import TIP

struct TransferPaymentOperation {
    
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
    let spendingOutputs: UTXOService.OutputCollection
    let destination: Payment.TransferDestination
    let token: TokenItem
    let amount: Decimal
    let memo: String
    let reference: String?
    let inscription: Payment.InscriptionContext?
    
    init(
        traceID: String, spendingOutputs: UTXOService.OutputCollection, 
        destination: Payment.TransferDestination, token: TokenItem,
        amount: Decimal, memo: String, reference: String?
    ) {
        self.traceID = traceID
        self.spendingOutputs = spendingOutputs
        self.destination = destination
        self.token = token
        self.amount = amount
        self.memo = memo
        self.reference = reference
        self.inscription = nil
    }
    
    init(
        traceID: String, spendingOutputs: UTXOService.OutputCollection,
        destination: Payment.TransferDestination, token: TokenItem,
        memo: String, reference: String?, inscription: Payment.InscriptionContext
    ) {
        self.traceID = traceID
        self.spendingOutputs = spendingOutputs
        self.destination = destination
        self.token = token
        self.amount = inscription.transferAmount
        self.memo = memo
        self.reference = reference
        self.inscription = inscription
    }
    
    func start(pin: String) async throws {
        let destination = self.destination
        let traceID = self.traceID
        let kernelAssetID = token.kernelAssetID
        let senderID = myUserId
        let amount = Token.amountString(from: amount)
        Logger.general.info(category: "Transfer", message: "Transfer: \(amount) \(token.symbol), to \(destination.debugDescription), traceID: \(traceID), inscription: \(inscription?.description ?? "(null)")")
        
        let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
        Logger.general.info(category: "Transfer", message: "SpendKey ready")
        
        let spendingOutputIDs = spendingOutputs.outputs.map(\.id)
        Logger.general.info(category: "Transfer", message: "Spending \(spendingOutputs.debugDescription), id: \(spendingOutputIDs)")
        
        let inputsData = try spendingOutputs.encodeAsInputData()
        let outputKeys = try spendingOutputs.encodedKeys()
        
        let ghostKeyRequests: [GhostKeyRequest]
        let isConsolidation: Bool
        switch destination {
        case let .user(opponent):
            ghostKeyRequests = GhostKeyRequest.contactTransfer(receiverIDs: [opponent.userId], senderIDs: [senderID], traceID: traceID)
            isConsolidation = inscription == nil && opponent.userId == myUserId
        case let .multisig(_, receivers):
            ghostKeyRequests = GhostKeyRequest.contactTransfer(receiverIDs: receivers.map(\.userId), senderIDs: [senderID], traceID: traceID)
            isConsolidation = false
        case .mainnet:
            ghostKeyRequests = GhostKeyRequest.mainnetAddressTransfer(senderID: senderID, traceID: traceID)
            isConsolidation = false
        }
        let ghostKeys = try await SafeAPI.ghostKeys(requests: ghostKeyRequests)
        
        let receiverGhostKey = ghostKeys.first!
        let receiverKeys = receiverGhostKey.keys.joined(separator: ",")
        let receiverMask = receiverGhostKey.mask
        
        let changeGhostKey = ghostKeys.last!
        let changeKeys = changeGhostKey.keys.joined(separator: ",")
        let changeMask = changeGhostKey.mask
        
        Logger.general.info(category: "Transfer", message: "GhostKeys ready, isConsolidation: \(isConsolidation)")
        
        var error: NSError?
        let tx: String
        switch destination {
        case .user:
            tx = KernelBuildTx(kernelAssetID,
                               amount,
                               1,
                               receiverKeys,
                               receiverMask,
                               inputsData,
                               changeKeys,
                               changeMask,
                               memo,
                               reference ?? "",
                               &error)
        case let .multisig(threshold, _):
            tx = KernelBuildTx(kernelAssetID,
                               amount,
                               threshold,
                               receiverKeys,
                               receiverMask,
                               inputsData,
                               changeKeys,
                               changeMask,
                               memo,
                               reference ?? "",
                               &error)
        case .mainnet(let address):
            tx = KernelBuildTxToKernelAddress(kernelAssetID,
                                              amount,
                                              address,
                                              inputsData,
                                              changeKeys,
                                              changeMask,
                                              memo,
                                              reference ?? "",
                                              &error)
        }
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
        let rawTransactionReceiverID: String
        let snapshotOpponentID: String
        switch destination {
        case let .user(opponent):
            rawTransactionReceiverID = opponent.userId
            snapshotOpponentID = opponent.userId
        case let .multisig(_, receivers):
            rawTransactionReceiverID = receivers.map(\.userId).joined(separator: ",")
            snapshotOpponentID = ""
        case .mainnet:
            rawTransactionReceiverID = ""
            snapshotOpponentID = ""
        }
        let rawTransaction = RawTransaction(requestID: traceID,
                                            rawTransaction: signedTx.raw,
                                            receiverID: rawTransactionReceiverID,
                                            state: .unspent,
                                            type: .transfer,
                                            createdAt: now)
        let snapshot = SafeSnapshot(type: .snapshot,
                                    assetID: token.assetID,
                                    amount: "-" + amount,
                                    userID: senderID,
                                    opponentID: snapshotOpponentID,
                                    memo: memo.data(using: .utf8)?.hexEncodedString() ?? memo,
                                    transactionHash: signedTx.hash,
                                    createdAt: now,
                                    traceID: traceID, 
                                    inscriptionHash: inscription?.item.inscriptionHash)
        let trace: Trace?
        switch destination {
        case .user, .multisig:
            trace = Trace(traceId: traceID,
                          assetId: token.assetID,
                          amount: amount,
                          opponentId: snapshotOpponentID,
                          destination: nil,
                          tag: nil,
                          snapshotId: snapshot.id)
        case .mainnet:
            trace = nil
        }
        OutputDAO.shared.signOutputs(with: spendingOutputIDs) { db in
            try changeOutput?.save(db)
            switch destination {
            case .user(let opponent):
                if isConsolidation {
                    let output = Output.consolidation(hash: signedTx.hash,
                                                      asset: kernelAssetID,
                                                      amount: amount,
                                                      mask: receiverMask,
                                                      keys: receiverGhostKey.keys,
                                                      createdAt: now,
                                                      lastOutput: spendingOutputs.lastOutput)
                    try output.save(db)
                } else {
                    try SafeSnapshotDAO.shared.save(snapshot: snapshot, db: db)
                    try trace?.save(db)
                    if opponent.isCreatedByMessenger {
                        let receiverID = opponent.userId
                        let conversationID = ConversationDAO.shared.makeConversationId(userId: senderID, ownerUserId: receiverID)
                        let message = if let inscription, case .transfer = inscription.operation {
                            Message.createMessage(snapshot: snapshot,
                                                  inscription: inscription.item,
                                                  conversationID: conversationID,
                                                  createdAt: now)
                        } else {
                            Message.createMessage(snapshot: snapshot,
                                                  inscription: nil,
                                                  conversationID: conversationID,
                                                  createdAt: now)
                        }
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
                }
            case .multisig, .mainnet:
                try SafeSnapshotDAO.shared.save(snapshot: snapshot, db: db)
                try trace?.save(db)
            }
            try rawTransaction.save(db)
            try UTXOService.shared.updateBalance(assetID: token.assetID, kernelAssetID: kernelAssetID, db: db)
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
        
        if !isConsolidation {
            AppGroupUserDefaults.User.hasPerformedTransfer = true
            AppGroupUserDefaults.Wallet.defaultTransferAssetId = token.assetID
        }
    }
    
}
