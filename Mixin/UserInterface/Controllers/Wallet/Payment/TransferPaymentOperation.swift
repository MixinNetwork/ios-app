import Foundation
import MixinServices
import Tip

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
    let tokenAmount: Decimal
    let memo: String
    
    func start(pin: String) async throws {
        let destination = self.destination
        let traceID = self.traceID
        let kernelAssetID = token.kernelAssetID
        let senderID = myUserId
        let amount = Token.amountString(from: tokenAmount)
        Logger.general.info(category: "Transfer", message: "Transfer: \(amount) \(token.symbol), to \(destination.debugDescription), traceID: \(traceID)")
        
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
            isConsolidation = opponent.userId == myUserId
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
                               "",
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
                               "",
                               &error)
        case .mainnet(let address):
            tx = KernelBuildTxToKernelAddress(kernelAssetID,
                                              amount,
                                              address,
                                              inputsData,
                                              changeKeys,
                                              changeMask,
                                              memo,
                                              &error)
        }
        if let error {
            throw error
        }
        Logger.general.info(category: "Transfer", message: "Tx built")
        
        let request = TransactionRequest(id: traceID, raw: tx)
        Logger.general.info(category: "Transfer", message: "Will request: \(request.id)")
        let responses = try await SafeAPI.requestTransaction(requests: [request])
        guard let response = responses.first(where: { $0.requestID == request.id }) else {
            throw Error.invalidTransactionResponse
        }
        let viewKeys = response.views.joined(separator: ",")
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
        let trace: Trace?
        let rawTransactionReceiverID: String
        let snapshotOpponentID: String
        switch destination {
        case let .user(opponent):
            trace = Trace(traceId: traceID, assetId: token.assetID, amount: amount, opponentId: opponent.userId, destination: nil, tag: nil)
            rawTransactionReceiverID = opponent.userId
            snapshotOpponentID = opponent.userId
        case let .multisig(_, receivers):
            trace = Trace(traceId: traceID, assetId: token.assetID, amount: amount, opponentId: "", destination: nil, tag: nil)
            rawTransactionReceiverID = receivers.map(\.userId).joined(separator: ",")
            snapshotOpponentID = ""
        case .mainnet:
            trace = nil
            rawTransactionReceiverID = ""
            snapshotOpponentID = ""
        }
        let rawTransaction = RawTransaction(requestID: traceID,
                                            rawTransaction: signedTx.raw,
                                            receiverID: rawTransactionReceiverID,
                                            state: .unspent,
                                            type: .transfer,
                                            createdAt: now)
        OutputDAO.shared.signOutputs(with: spendingOutputIDs) { db in
            try changeOutput?.save(db)
            if isConsolidation {
                let output = Output.consolidation(hash: signedTx.hash,
                                                  asset: kernelAssetID,
                                                  amount: amount,
                                                  mask: receiverMask,
                                                  keys: receiverGhostKey.keys,
                                                  createdAt: now,
                                                  lastOutput: spendingOutputs.lastOutput)
                try output.save(db)
            }
            
            try rawTransaction.save(db)
            try trace?.save(db)
            try UTXOService.shared.updateBalance(assetID: token.assetID, kernelAssetID: kernelAssetID, db: db)
            Logger.general.info(category: "Transfer", message: "Outputs signed")
        }
        
        let signedRequest = TransactionRequest(id: traceID, raw: signedTx.raw)
        Logger.general.info(category: "Transfer", message: "Will post tx: \(signedRequest.id)")
        let postResponses = try await SafeAPI.postTransaction(requests: [signedRequest])
        guard let postResponse = postResponses.first(where: { $0.requestID == signedRequest.id }) else {
            throw Error.invalidTransactionResponse
        }
        let snapshot = SafeSnapshot(id: postResponse.snapshotID,
                                    type: .snapshot,
                                    assetID: token.assetID,
                                    amount: "-" + amount,
                                    userID: senderID,
                                    opponentID: snapshotOpponentID,
                                    memo: memo.data(using: .utf8)?.hexEncodedString() ?? memo,
                                    transactionHash: signedTx.hash,
                                    createdAt: postResponse.createdAt,
                                    traceID: traceID,
                                    confirmations: nil,
                                    openingBalance: nil,
                                    closingBalance: nil,
                                    deposit: nil,
                                    withdrawal: nil)
        Logger.general.info(category: "Transfer", message: "Will sign raw txs")
        RawTransactionDAO.shared.signRawTransactions(with: [rawTransaction.requestID]) { db in
            if !isConsolidation {
                try snapshot.save(db)
            }
            
            switch destination {
            case .user(let opponent):
                if !isConsolidation {
                    let receiverID = opponent.userId
                    try Trace.filter(key: traceID).updateAll(db, [Trace.column(of: .snapshotId).set(to: snapshot.id)])
                    let conversationID = ConversationDAO.shared.makeConversationId(userId: senderID, ownerUserId: receiverID)
                    let message = Message.createMessage(snapshot: snapshot, conversationID: conversationID, createdAt: now)
                    if try !Conversation.exists(db, key: conversationID) {
                        let conversation = Conversation.createConversation(conversationId: conversationID,
                                                                           category: nil,
                                                                           recipientId: receiverID,
                                                                           status: ConversationStatus.START.rawValue)
                        try conversation.save(db)
                        DispatchQueue.global().async {
                            ConcurrentJobQueue.shared.addJob(job: CreateConversationJob(conversationId: conversationID))
                        }
                    }
                    try MessageDAO.shared.insertMessage(database: db, message: message, messageSource: "PeerTransfer", silentNotification: false)
                }
            case .multisig:
                try Trace.filter(key: traceID).updateAll(db, [Trace.column(of: .snapshotId).set(to: snapshot.id)])
            case .mainnet:
                break
            }
            
            Logger.general.info(category: "Transfer", message: "RawTx signed")
        }
        
        if !isConsolidation {
            AppGroupUserDefaults.User.hasPerformedTransfer = true
            AppGroupUserDefaults.Wallet.defaultTransferAssetId = token.assetID
        }
    }
    
}
