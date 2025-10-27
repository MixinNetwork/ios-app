import Foundation
import MixinServices
import TIP

struct WithdrawPaymentOperation {
    
    enum Error: Swift.Error, LocalizedError {
        
        case buildWithdrawalTx(Swift.Error?)
        case buildFeeTx(Swift.Error?)
        case missingWithdrawalResponse
        case missingFeeResponse
        case alreadyPaid
        case signWithdrawal(Swift.Error?)
        case signFee(Swift.Error?)
        case insufficientFee
        case maxSpendingCountExceeded
        
        var errorDescription: String? {
            switch self {
            case .buildWithdrawalTx(let error):
                return error?.localizedDescription ?? "Null withdrawal tx"
            case .buildFeeTx(let error):
                return error?.localizedDescription ?? "Null fee tx"
            case .missingWithdrawalResponse:
                return "No withdrawal resp"
            case .missingFeeResponse:
                return "No fee resp"
            case .alreadyPaid:
                return "Already paid"
            case .signWithdrawal(let error):
                return error?.localizedDescription ?? "Sign withdrawal"
            case .signFee(let error):
                return error?.localizedDescription ?? "Sign fee"
            case .insufficientFee:
                return R.string.localizable.insufficient_transaction_fee()
            case .maxSpendingCountExceeded:
                return R.string.localizable.utxo_count_exceeded()
            }
        }
        
    }
    
    let traceID: String
    
    let withdrawalToken: MixinTokenItem
    let withdrawalTokenAmount: Decimal
    let withdrawalFiatMoneyAmount: Decimal
    
    let withdrawalOutputs: UTXOService.OutputCollection
    
    let feeToken: MixinToken
    let feeAmount: Decimal
    let isFeeTokenDifferent: Bool
    
    let address: WithdrawableAddress
    let addressLabel: AddressLabel?
    let addressID: String?
    
    private let cashierID = "674d6776-d600-4346-af46-58e77d8df185"
    
    init(
        traceID: String, withdrawalToken: MixinTokenItem, withdrawalTokenAmount: Decimal,
        withdrawalFiatMoneyAmount: Decimal, withdrawalOutputs: UTXOService.OutputCollection,
        feeToken: MixinToken, feeAmount: Decimal, address: WithdrawableAddress,
        addressLabel: AddressLabel? = nil, addressID: String? = nil
    ) {
        self.traceID = traceID
        self.withdrawalToken = withdrawalToken
        self.withdrawalTokenAmount = withdrawalTokenAmount
        self.withdrawalFiatMoneyAmount = withdrawalFiatMoneyAmount
        self.withdrawalOutputs = withdrawalOutputs
        self.feeToken = feeToken
        self.feeAmount = feeAmount
        self.isFeeTokenDifferent = withdrawalToken.assetID != feeToken.assetID
        self.address = address
        self.addressLabel = addressLabel
        self.addressID = addressID
    }
    
    func start(pin: String) async throws {
        let senderID = myUserId
        let threshold: Int32 = 1
        let emptyMemo = ""
        let fullAddress = address.fullRepresentation
        let withdrawalAmount = withdrawalTokenAmount
        let withdrawalAmountString = TokenAmountFormatter.string(from: withdrawalAmount)
        let feeAmountString = TokenAmountFormatter.string(from: feeAmount)
        let feeTraceID = UUID.uniqueObjectIDString(traceID, "FEE")
        Logger.general.info(category: "Withdraw", message: "Withdraw: \(withdrawalAmount) \(withdrawalToken.symbol), fee: \(feeAmount) \(feeToken.symbol), to \(fullAddress), traceID: \(traceID), feeTraceID: \(feeTraceID)")
        
        let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
        Logger.general.info(category: "Withdraw", message: "SpendKey ready")
        
        let trace = Trace(traceId: traceID, assetId: feeToken.assetID, amount: withdrawalAmountString, opponentId: nil, destination: address.destination, tag: address.tag)
        TraceDAO.shared.saveTrace(trace: trace)
        
        let feeOutputs: UTXOService.OutputCollection?
        if isFeeTokenDifferent {
            let result = UTXOService.shared.collectAvailableOutputs(
                kernelAssetID: feeToken.kernelAssetID,
                amount: feeAmount
            )
            switch result {
            case .insufficientBalance:
                throw Error.insufficientFee
            case .maxSpendingCountExceeded:
                throw Error.maxSpendingCountExceeded
            case .success(let collection):
                feeOutputs = collection
            }
        } else {
            feeOutputs = nil
        }
        Logger.general.info(category: "Withdraw", message: "Withdraw \(withdrawalOutputs.debugDescription), id: \(withdrawalOutputs.outputs.map(\.id))")
        if let feeOutputs {
            Logger.general.info(category: "Withdraw", message: "Fee \(feeOutputs.debugDescription), id: \(feeOutputs.outputs.map(\.id))")
        }
        
        let ghostKeyRequests: [GhostKeyRequest]
        if isFeeTokenDifferent {
            ghostKeyRequests = GhostKeyRequest.withdrawFee(receiverID: cashierID, senderID: senderID, traceID: traceID)
        } else {
            ghostKeyRequests = GhostKeyRequest.withdrawSubmit(receiverID: cashierID, senderID: senderID, traceID: traceID)
        }
        let ghostKeys = try await SafeAPI.ghostKeys(requests: ghostKeyRequests)
        let feeOutputKeys = ghostKeys[0].keys.joined(separator: ",")
        let feeOutputMask = ghostKeys[0].mask
        let changeKeys = ghostKeys[1].keys.joined(separator: ",")
        let changeMask = ghostKeys[1].mask
        Logger.general.info(category: "Withdraw", message: "GhostKeys ready")
        
        var error: NSError?
        
        let withdrawalTx = KernelBuildWithdrawalTx(withdrawalToken.kernelAssetID,
                                                   withdrawalAmountString,
                                                   address.destination,
                                                   address.tag,
                                                   isFeeTokenDifferent ? "" : feeAmountString,
                                                   isFeeTokenDifferent ? "" : feeOutputKeys,
                                                   isFeeTokenDifferent ? "" : feeOutputMask,
                                                   try withdrawalOutputs.encodeAsInputData(),
                                                   changeKeys,
                                                   changeMask,
                                                   emptyMemo,
                                                   &error)
        guard let withdrawalTx, error == nil else {
            throw Error.buildWithdrawalTx(error)
        }
        Logger.general.info(category: "Withdraw", message: "Withdrawal tx built")
        
        var verifyRequests = [TransactionRequest(id: traceID, raw: withdrawalTx.raw)]
        let feeTx: String?
        if let feeOutputs {
            let feeChangeKeys = ghostKeys[2].keys.joined(separator: ",")
            let feeChangeMask = ghostKeys[2].mask
            let tx = KernelBuildTx(feeToken.kernelAssetID,
                                   feeAmountString,
                                   threshold,
                                   feeOutputKeys,
                                   feeOutputMask,
                                   try feeOutputs.encodeAsInputData(),
                                   feeChangeKeys,
                                   feeChangeMask,
                                   emptyMemo,
                                   withdrawalTx.hash,
                                   &error)
            guard let tx, error == nil else {
                throw Error.buildFeeTx(error)
            }
            verifyRequests.append(TransactionRequest(id: feeTraceID, raw: tx.raw))
            feeTx = tx.raw
            Logger.general.info(category: "Withdraw", message: "Fee tx built")
        } else {
            feeTx = nil
        }
        
        Logger.general.info(category: "Withdraw", message: "Will verify: \(verifyRequests.map(\.id))")
        let verifyResponses = try await SafeAPI.requestTransaction(requests: verifyRequests)
        guard let withdrawalVerifyResponse = verifyResponses.first(where: { $0.requestID == traceID }) else {
            throw Error.missingWithdrawalResponse
        }
        guard withdrawalVerifyResponse.state == Output.State.unspent.rawValue else {
            throw Error.alreadyPaid
        }
        let withdrawalViews = withdrawalVerifyResponse.views.joined(separator: ",")
        let signedWithdrawal = KernelSignTx(withdrawalTx.raw,
                                            try withdrawalOutputs.encodedKeys(),
                                            withdrawalViews,
                                            spendKey,
                                            isFeeTokenDifferent,
                                            &error)
        guard let signedWithdrawal, error == nil else {
            throw Error.signWithdrawal(error)
        }
        Logger.general.info(category: "Withdraw", message: "Withdrawal signed")
        let now = Date().toUTCString()
        let broadcastRequests: [TransactionRequest]
        let withdrawalSnapshotAmount = isFeeTokenDifferent ? withdrawalAmount : withdrawalAmount + feeAmount
        let withdrawalSnapshot = SafeSnapshot(type: .withdrawal,
                                              assetID: withdrawalToken.assetID,
                                              amount: "-" + TokenAmountFormatter.string(from: withdrawalSnapshotAmount),
                                              userID: senderID,
                                              opponentID: "",
                                              memo: emptyMemo,
                                              transactionHash: signedWithdrawal.hash,
                                              createdAt: now,
                                              traceID: traceID,
                                              inscriptionHash: nil,
                                              withdrawal: .init(hash: "", receiver: address.destination))
        let isFeeWaived = addressLabel?.isFeeWaived() ?? false
        let feeType: FeeType? = isFeeWaived ? .free : nil
        if let feeOutputs, let feeTx {
            guard let feeResponse = verifyResponses.first(where: { $0.requestID == feeTraceID }) else {
                throw Error.missingFeeResponse
            }
            let feeViews = feeResponse.views.joined(separator: ",")
            let signedFee = KernelSignTx(feeTx,
                                         try feeOutputs.encodedKeys(),
                                         feeViews,
                                         spendKey,
                                         false,
                                         &error)
            guard let signedFee, error == nil else {
                throw Error.signFee(error)
            }
            Logger.general.info(category: "Withdraw", message: "Fee signed")
            let feeSnapshot = SafeSnapshot(type: .snapshot,
                                           assetID: feeToken.assetID,
                                           amount: "-" + feeAmountString,
                                           userID: senderID,
                                           opponentID: cashierID,
                                           memo: emptyMemo,
                                           transactionHash: signedFee.hash,
                                           createdAt: now,
                                           traceID: feeTraceID, 
                                           inscriptionHash: nil)
            broadcastRequests = [
                TransactionRequest(id: traceID, raw: signedWithdrawal.raw, feeType: feeType),
                TransactionRequest(id: feeTraceID, raw: signedFee.raw)
            ]
            let spendingOutputIDs = withdrawalOutputs.outputs.map(\.id) + feeOutputs.outputs.map(\.id)
            let rawTransactions = [
                RawTransaction(requestID: traceID,
                               rawTransaction: signedWithdrawal.raw,
                               receiverID: fullAddress,
                               state: .unspent,
                               type: .withdrawal,
                               createdAt: now),
                RawTransaction(requestID: feeTraceID,
                               rawTransaction: signedFee.raw,
                               receiverID: fullAddress,
                               state: .unspent,
                               type: .fee,
                               createdAt: now),
            ]
            Logger.general.info(category: "Withdraw", message: "Will sign: \(spendingOutputIDs)")
            OutputDAO.shared.signOutputs(with: spendingOutputIDs) { db in
                if let change = signedWithdrawal.change {
                    let output = Output(change: change,
                                        asset: withdrawalToken.kernelAssetID,
                                        mask: ghostKeys[1].mask,
                                        keys: ghostKeys[1].keys,
                                        lastOutput: withdrawalOutputs.lastOutput)
                    try output.save(db)
                    Logger.general.info(category: "Withdraw", message: "Saved change output: \(output.amount)")
                } else {
                    Logger.general.info(category: "Withdraw", message: "No change")
                }
                if let change = signedFee.change {
                    let output = Output(change: change,
                                        asset: feeToken.kernelAssetID,
                                        mask: ghostKeys[1].mask,
                                        keys: ghostKeys[2].keys,
                                        lastOutput: feeOutputs.lastOutput)
                    try output.save(db)
                    Logger.general.info(category: "Withdraw", message: "Saved fee change output: \(output.amount)")
                } else {
                    Logger.general.info(category: "Withdraw", message: "No fee change")
                }
                try rawTransactions.save(db)
                try UTXOService.shared.updateBalance(assetID: withdrawalToken.assetID,
                                                     kernelAssetID: withdrawalToken.kernelAssetID,
                                                     db: db)
                try UTXOService.shared.updateBalance(assetID: feeToken.assetID,
                                                     kernelAssetID: feeToken.kernelAssetID,
                                                     db: db)
                try SafeSnapshotDAO.shared.save(snapshot: withdrawalSnapshot, db: db)
                try SafeSnapshotDAO.shared.save(snapshot: feeSnapshot, db: db)
                try Trace.filter(key: traceID).updateAll(db, Trace.column(of: .snapshotId).set(to: withdrawalSnapshot.id))
                db.afterNextTransaction { _ in
                    Logger.general.info(category: "Withdraw", message: "Outputs signed")
                }
            }
        } else {
            broadcastRequests = [
                TransactionRequest(id: traceID, raw: signedWithdrawal.raw, feeType: feeType)
            ]
            let spendingOutputIDs = withdrawalOutputs.outputs.map(\.id)
            let rawTransaction = RawTransaction(requestID: traceID,
                                                rawTransaction: signedWithdrawal.raw,
                                                receiverID: fullAddress,
                                                state: .unspent,
                                                type: .withdrawal,
                                                createdAt: now)
            Logger.general.info(category: "Withdraw", message: "Will sign: \(spendingOutputIDs)")
            OutputDAO.shared.signOutputs(with: spendingOutputIDs) { db in
                if let change = signedWithdrawal.change {
                    let output = Output(change: change,
                                        asset: withdrawalToken.kernelAssetID,
                                        mask: ghostKeys[1].mask,
                                        keys: ghostKeys[1].keys,
                                        lastOutput: withdrawalOutputs.lastOutput)
                    try output.save(db)
                    Logger.general.info(category: "Withdraw", message: "Saved change output: \(output.id), amount: \(change.amount)")
                }
                try rawTransaction.save(db)
                try UTXOService.shared.updateBalance(assetID: withdrawalToken.assetID,
                                                     kernelAssetID: withdrawalToken.kernelAssetID,
                                                     db: db)
                try SafeSnapshotDAO.shared.save(snapshot: withdrawalSnapshot, db: db)
                try Trace.filter(key: traceID).updateAll(db, Trace.column(of: .snapshotId).set(to: withdrawalSnapshot.id))
                db.afterNextTransaction { _ in
                    Logger.general.info(category: "Withdraw", message: "Outputs signed")
                }
            }
        }
        let broadcastRequestIDs = broadcastRequests.map(\.id)
        try await SafeAPI.withRetryingOnServerError(maxNumberOfTries: 20) {
            Logger.general.info(category: "Withdraw", message: "Will broadcast tx: \(broadcastRequestIDs), hash: \(signedWithdrawal.hash)")
            try await SafeAPI.postTransaction(requests: broadcastRequests)
        } shouldRetry: {
            do {
                _ = try await SafeAPI.transaction(id: traceID)
                Logger.general.warn(category: "Withdraw", message: "Found tx, stop retrying")
                return false
            } catch {
                Logger.general.warn(category: "Withdraw", message: "Keep retrying: \(error)")
                return true
            }
        }
        Logger.general.info(category: "Withdraw", message: "Will sign raw txs")
        RawTransactionDAO.shared.signRawTransactions(requestIDs: broadcastRequestIDs)
        NotificationCenter.default.post(onMainThread: dismissSearchNotification, object: nil)
        Logger.general.info(category: "Withdraw", message: "RawTx signed")
        if let addressID {
            AppGroupUserDefaults.Wallet.withdrawnAddressIds[addressID] = true
        }
    }
    
}
