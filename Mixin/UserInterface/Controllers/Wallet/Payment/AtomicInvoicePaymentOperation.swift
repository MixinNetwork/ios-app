import Foundation
import MixinServices
import TIP

final class AtomicInvoicePaymentOperation: InvoicePaymentOperation {
    
    enum OperationError: Error, LocalizedError {
        
        case sign(NSError?)
        case buildTx(Error?)
        case missingTransactionResponse
        case inconsistentBroadcast
        case decodeExtra
        
        var errorDescription: String? {
            switch self {
            case .sign(let error):
                error?.localizedDescription ?? "Null signature"
            case .buildTx(let error):
                error?.localizedDescription ?? "Null tx"
            case .missingTransactionResponse:
                "Mising tx resp"
            case .inconsistentBroadcast:
                "Inconsistent Broadcast"
            case .decodeExtra:
                "Decode Extra"
            }
        }
        
    }
    
    class Transaction: InvoicePaymentOperationTransaction {
        
        let entry: Invoice.Entry
        let token: MixinTokenItem
        let outputCollection: UTXOService.OutputCollection
        
        init(
            entry: Invoice.Entry,
            token: MixinTokenItem,
            outputCollection: UTXOService.OutputCollection
        ) {
            self.entry = entry
            self.token = token
            self.outputCollection = outputCollection
        }
        
    }
    
    private class VerifyTransaction: Transaction {
        
        let changeGhostKey: GhostKey
        let kernelTransaction: KernelTx
        let verifyRequest: TransactionRequest
        
        init(
            changeGhostKey: GhostKey,
            kernelTransaction: KernelTx,
            verifyRequest: TransactionRequest,
            transaction tx: Transaction
        ) {
            self.changeGhostKey = changeGhostKey
            self.kernelTransaction = kernelTransaction
            self.verifyRequest = verifyRequest
            super.init(
                entry: tx.entry,
                token: tx.token,
                outputCollection: tx.outputCollection
            )
        }
        
    }
    
    private class SignedTransaction: VerifyTransaction {
        
        let changeOutput: Output?
        let signedKernelTransaction: KernelTx
        let rawTransaction: RawTransaction
        let snapshot: SafeSnapshot
        let trace: Trace?
        
        init(
            changeOutput: Output?,
            signedKernelTransaction: KernelTx,
            rawTransaction: RawTransaction,
            snapshot: SafeSnapshot,
            trace: Trace?,
            transaction tx: VerifyTransaction
        ) {
            self.changeOutput = changeOutput
            self.signedKernelTransaction = signedKernelTransaction
            self.rawTransaction = rawTransaction
            self.snapshot = snapshot
            self.trace = trace
            super.init(
                changeGhostKey: tx.changeGhostKey,
                kernelTransaction: tx.kernelTransaction,
                verifyRequest: tx.verifyRequest,
                transaction: tx
            )
        }
        
    }
    
    let destination: Payment.TransferDestination
    let transactions: [Transaction]
    let memo: TransferExtra?
    
    init(
        destination: Payment.TransferDestination,
        transactions: [Transaction],
        memo: TransferExtra?,
    ) {
        self.destination = destination
        self.transactions = transactions
        self.memo = memo
    }
    
    func start(pin: String) async throws {
        // Early exit if PIN is wrong
        let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
        
        let senderID = myUserId
        var error: NSError?
        
        var verifyTransactions: [VerifyTransaction] = []
        for (index, transaction) in transactions.enumerated() {
            let entry = transaction.entry
            let destination: Payment.TransferDestination = if entry.isStorage {
                .storageFeeReceiver
            } else {
                self.destination
            }
            let amount = entry.amount
            let kernelAssetID = transaction.token.kernelAssetID
            let traceID = entry.traceID
            let inputsData = try transaction.outputCollection.encodeAsInputData()
            
            let ghostKeyRequests = switch destination {
            case let .user(opponent):
                GhostKeyRequest.contactTransfer(receiverIDs: [opponent.userId], senderIDs: [senderID], traceID: traceID)
            case let .multisig(_, receivers):
                GhostKeyRequest.contactTransfer(receiverIDs: receivers.map(\.userId), senderIDs: [senderID], traceID: traceID)
            case .mainnet:
                GhostKeyRequest.mainnetAddressTransfer(senderID: senderID, traceID: traceID)
            }
            let ghostKeys = try await SafeAPI.ghostKeys(requests: ghostKeyRequests)
            
            let receiverGhostKey = ghostKeys.first!
            let receiverKeys = receiverGhostKey.keys.joined(separator: ",")
            let receiverMask = receiverGhostKey.mask
            
            let changeGhostKey = ghostKeys.last!
            let changeKeys = changeGhostKey.keys.joined(separator: ",")
            let changeMask = changeGhostKey.mask
            
            let references = entry.references.map { reference in
                switch reference {
                case let .index(index):
                    verifyTransactions[index].kernelTransaction.hash
                case let .hash(hash):
                    hash
                }
            }.joined(separator: ",")
            
            let tx: KernelTx?
            switch destination {
            case .user:
                guard let extra = String(data: entry.extra, encoding: .utf8) else {
                    throw OperationError.decodeExtra
                }
                tx = KernelBuildTx(
                    kernelAssetID,
                    amount,
                    1,
                    receiverKeys,
                    receiverMask,
                    inputsData,
                    changeKeys,
                    changeMask,
                    extra,
                    references,
                    &error
                )
            case let .multisig(threshold, _):
                guard let extra = String(data: entry.extra, encoding: .utf8) else {
                    throw OperationError.decodeExtra
                }
                tx = KernelBuildTx(
                    kernelAssetID,
                    amount,
                    threshold,
                    receiverKeys,
                    receiverMask,
                    inputsData,
                    changeKeys,
                    changeMask,
                    extra,
                    references,
                    &error
                )
            case let .mainnet(thresold, address):
                tx = KernelBuildTxToKernelAddress(
                    kernelAssetID,
                    amount,
                    thresold,
                    address,
                    inputsData,
                    changeKeys,
                    changeMask,
                    entry.extra.hexEncodedString(),
                    references,
                    &error
                )
            }
            guard let tx, error == nil else {
                throw OperationError.buildTx(error)
            }
            let verifyRequest = TransactionRequest(id: traceID, raw: tx.raw)
            
            let verifyTransaction = VerifyTransaction(
                changeGhostKey: changeGhostKey,
                kernelTransaction: tx,
                verifyRequest: verifyRequest,
                transaction: transaction
            )
            verifyTransactions.append(verifyTransaction)
            Logger.general.info(category: "Transfer", message: "Tx\(index) built")
        }
        
        let verifyRequests = verifyTransactions.map(\.verifyRequest)
        Logger.general.info(category: "Transfer", message: "Will verify: \(verifyRequests.map(\.id))")
        let verifyResponses = try await SafeAPI.requestTransaction(requests: verifyRequests)
            .reduce(into: [:]) { result, response in
                result[response.requestID] = response
            }
        
        let now = Date().toUTCString()
        let signedTransactions: [SignedTransaction] = try verifyTransactions.enumerated().map { (index, transaction) in
            let entry = transaction.entry
            let token = transaction.token
            guard let verifyResponse = verifyResponses[entry.traceID] else {
                throw OperationError.missingTransactionResponse
            }
            
            let outputKeys = try transaction.outputCollection.encodedKeys()
            let viewKeys = verifyResponse.views.joined(separator: ",")
            let signedTx = KernelSignTx(transaction.kernelTransaction.raw, outputKeys, viewKeys, spendKey, false, &error)
            guard let signedTx, error == nil else {
                throw OperationError.sign(error)
            }
            Logger.general.info(category: "Transfer", message: "Tx\(index) signed")
            
            let changeOutput: Output?
            if let change = signedTx.change {
                let output = Output(
                    change: change,
                    asset: token.kernelAssetID,
                    mask: transaction.changeGhostKey.mask,
                    keys: transaction.changeGhostKey.keys,
                    lastOutput: transaction.outputCollection.lastOutput
                )
                Logger.general.info(category: "Transfer", message: "Created change output: \(output.id), amount: \(change.amount)")
                changeOutput = output
            } else {
                Logger.general.info(category: "Transfer", message: "No change")
                changeOutput = nil
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
            let rawTransaction = RawTransaction(
                requestID: entry.traceID,
                rawTransaction: signedTx.raw,
                receiverID: rawTransactionReceiverID,
                state: .unspent,
                type: .transfer,
                createdAt: now
            )
            let snapshot = SafeSnapshot(
                type: .snapshot,
                assetID: token.assetID,
                amount: "-" + entry.amount,
                userID: senderID,
                opponentID: snapshotOpponentID,
                memo: entry.extra.hexEncodedString(),
                transactionHash: signedTx.hash,
                createdAt: now,
                traceID: entry.traceID,
                inscriptionHash: nil
            )
            
            let trace: Trace? = switch destination {
            case .user, .multisig:
                Trace(
                    traceId: entry.traceID,
                    assetId: token.assetID,
                    amount: entry.amount,
                    opponentId: snapshotOpponentID,
                    destination: nil,
                    tag: nil,
                    snapshotId: snapshot.id
                )
            case .mainnet:
                nil
            }
            
            return SignedTransaction(
                changeOutput: changeOutput,
                signedKernelTransaction: signedTx,
                rawTransaction: rawTransaction,
                snapshot: snapshot,
                trace: trace,
                transaction: transaction
            )
        }
        
        let allOutputIDs = transactions.map(\.outputCollection).flatMap(\.outputs).map(\.id)
        OutputDAO.shared.signOutputs(with: allOutputIDs) { db in
            for tx in signedTransactions {
                try tx.changeOutput?.save(db)
                try tx.trace?.save(db)
            }
            
            let snapshots = signedTransactions.map(\.snapshot)
            switch destination {
            case .user(let opponent):
                try SafeSnapshotDAO.shared.save(snapshots: snapshots, db: db)
                if opponent.isCreatedByMessenger {
                    let receiverID = opponent.userId
                    let conversationID = ConversationDAO.shared.makeConversationId(userId: senderID, ownerUserId: receiverID)
                    for snapshot in snapshots {
                        let message: Message = .createMessage(
                            snapshot: snapshot,
                            inscription: nil,
                            conversationID: conversationID,
                            createdAt: now
                        )
                        try MessageDAO.shared.insertMessage(
                            database: db,
                            message: message,
                            messageSource: MessageDAO.LocalMessageSource.transfer,
                            silentNotification: false
                        )
                    }
                    if try !Conversation.exists(db, key: conversationID) {
                        let conversation: Conversation = .createConversation(
                            conversationId: conversationID,
                            category: ConversationCategory.CONTACT.rawValue,
                            recipientId: receiverID,
                            status: ConversationStatus.START.rawValue
                        )
                        try conversation.save(db)
                        db.afterNextTransaction { _ in
                            let createConversation = CreateConversationJob(conversationId: conversationID)
                            ConcurrentJobQueue.shared.addJob(job: createConversation)
                        }
                    }
                }
            case .multisig, .mainnet:
                try SafeSnapshotDAO.shared.save(snapshots: snapshots, db: db)
            }
            
            for tx in signedTransactions {
                try tx.rawTransaction.save(db)
            }
            let tokens = transactions.map(\.token).reduce(into: [:]) { result, item in
                result[item.assetID] = item
            }
            for item in tokens.values {
                try UTXOService.shared.updateBalance(assetID: item.assetID, kernelAssetID: item.kernelAssetID, db: db)
            }
            Logger.general.info(category: "Transfer", message: "Outputs signed")
        }
        
        let broadcastRequests = signedTransactions.enumerated().map { (index, tx) in
            let signedKernelTx = tx.signedKernelTransaction
            Logger.general.info(category: "Transfer", message: "Will broadcast tx: \(tx.entry.traceID), hash: \(signedKernelTx.hash)")
            return TransactionRequest(id: tx.entry.traceID, raw: signedKernelTx.raw)
        }
        
        var partialResponseIDs: Set<String>?
        try await SafeAPI.withRetryingOnServerError(maxNumberOfTries: 20) {
            try await SafeAPI.postTransaction(requests: broadcastRequests)
        } shouldRetry: {
            do {
                let transactions = try await SafeAPI.transactions(ids: broadcastRequests.map(\.id))
                let requestIDs = Set(broadcastRequests.map(\.id))
                let responseIDs = Set(transactions.map(\.requestID))
                if requestIDs == responseIDs {
                    Logger.general.warn(category: "Transfer", message: "Found tx, stop retrying")
                    return false
                } else {
                    partialResponseIDs = responseIDs
                    Logger.general.error(category: "Transfer", message: "Inconsistent txn, Request: \(requestIDs), Response: \(responseIDs)")
                    return false
                }
            } catch {
                Logger.general.warn(category: "Transfer", message: "Keep retrying: \(error)")
                return true
            }
        }
        if let ids = partialResponseIDs {
            // Part of invoice is paid
            RawTransactionDAO.shared.signRawTransactions(requestIDs: ids)
            throw OperationError.inconsistentBroadcast
        }
        
        Logger.general.info(category: "Transfer", message: "Will sign raw txs")
        RawTransactionDAO.shared.signRawTransactions(requestIDs: signedTransactions.map(\.rawTransaction.requestID))
        NotificationCenter.default.post(onMainThread: dismissSearchNotification, object: nil)
        Logger.general.info(category: "Transfer", message: "RawTx signed")
        
        AppGroupUserDefaults.User.hasPerformedTransfer = true
    }
    
}
