import Foundation
import MixinServices
import Tip

struct WithdrawPaymentOperation {
    
    enum Error: Swift.Error, LocalizedError {
        
        case buildWithdrawalTx(Swift.Error?)
        case buildFeeTx(Swift.Error)
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
                return error.localizedDescription
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
    
    let withdrawalToken: TokenItem
    let withdrawalTokenAmount: Decimal
    let withdrawalFiatMoneyAmount: Decimal
    
    let withdrawalOutputs: UTXOService.OutputCollection
    
    let feeToken: Token
    let feeAmount: Decimal
    
    let address: Address
    
    private let receiverID = "674d6776-d600-4346-af46-58e77d8df185"
    
    func start(pin: String) async throws {
        let isFeeTokenDifferent = withdrawalToken.assetID != feeToken.assetID
        let amount = withdrawalTokenAmount
        let senderID = myUserId
        let threshold: Int32 = 1
        let memo = ""
        let fullAddress = address.fullAddress
        let amountString = Token.amountString(from: amount)
        let feeAmountString = Token.amountString(from: feeAmount)
        let feeTraceID = UUID.uniqueObjectIDString(traceID, "FEE")
        Logger.general.info(category: "Withdraw", message: "Withdraw: \(amount) \(withdrawalToken.symbol), fee: \(feeAmount) \(feeToken.symbol), to \(fullAddress), traceID: \(traceID), feeTraceID: \(feeTraceID)")
        
        let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
        Logger.general.info(category: "Withdraw", message: "SpendKey ready")
        
        let trace = Trace(traceId: traceID, assetId: feeToken.assetID, amount: amountString, opponentId: nil, destination: address.destination, tag: address.tag)
        TraceDAO.shared.saveTrace(trace: trace)
        
        let feeOutputs: UTXOService.OutputCollection?
        if isFeeTokenDifferent {
            let result = UTXOService.shared.collectUnspentOutputs(kernelAssetID: feeToken.kernelAssetID, amount: feeAmount)
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
            ghostKeyRequests = GhostKeyRequest.withdrawFee(receiverID: receiverID, senderID: senderID, traceID: traceID)
        } else {
            ghostKeyRequests = GhostKeyRequest.withdrawSubmit(receiverID: receiverID, senderID: senderID, traceID: traceID)
        }
        let ghostKeys = try await SafeAPI.ghostKeys(requests: ghostKeyRequests)
        let feeOutputKeys = ghostKeys[0].keys.joined(separator: ",")
        let feeOutputMask = ghostKeys[0].mask
        let changeKeys = ghostKeys[1].keys.joined(separator: ",")
        let changeMask = ghostKeys[1].mask
        Logger.general.info(category: "Withdraw", message: "GhostKeys ready")
        
        var error: NSError?
        
        let withdrawalTx = KernelBuildWithdrawalTx(withdrawalToken.kernelAssetID,
                                                   amountString,
                                                   address.destination,
                                                   address.tag,
                                                   isFeeTokenDifferent ? "" : feeAmountString,
                                                   isFeeTokenDifferent ? "" : feeOutputKeys,
                                                   isFeeTokenDifferent ? "" : feeOutputMask,
                                                   try withdrawalOutputs.encodeAsInputData(),
                                                   changeKeys,
                                                   changeMask,
                                                   memo,
                                                   &error)
        guard let withdrawalTx, error == nil else {
            throw Error.buildWithdrawalTx(error)
        }
        Logger.general.info(category: "Withdraw", message: "Withdrawal tx built")
        
        var requests = [TransactionRequest(id: traceID, raw: withdrawalTx.raw)]
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
                                   memo,
                                   withdrawalTx.hash,
                                   &error)
            if let error {
                throw Error.buildFeeTx(error)
            }
            requests.append(TransactionRequest(id: feeTraceID, raw: tx))
            feeTx = tx
            Logger.general.info(category: "Withdraw", message: "Fee tx built")
        } else {
            feeTx = nil
        }
        
        Logger.general.info(category: "Withdraw", message: "Will request: \(requests.map(\.id))")
        let responses = try await SafeAPI.requestTransaction(requests: requests)
        guard let withdrawalResponse = responses.first(where: { $0.requestID == traceID }) else {
            throw Error.missingWithdrawalResponse
        }
        guard withdrawalResponse.state == Output.State.unspent.rawValue else {
            throw Error.alreadyPaid
        }
        let withdrawalViews = withdrawalResponse.views.joined(separator: ",")
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
        let rawRequests: [TransactionRequest]
        if let feeOutputs, let feeTx {
            guard let feeResponse = responses.first(where: { $0.requestID == feeTraceID }) else {
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
            rawRequests = [
                TransactionRequest(id: traceID, raw: signedWithdrawal.raw),
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
                Logger.general.info(category: "Withdraw", message: "Outputs signed")
            }
        } else {
            rawRequests = [
                TransactionRequest(id: traceID, raw: signedWithdrawal.raw)
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
                    Logger.general.info(category: "Withdraw", message: "Saved change output: \(output.amount)")
                }
                try rawTransaction.save(db)
                try UTXOService.shared.updateBalance(assetID: withdrawalToken.assetID,
                                                     kernelAssetID: withdrawalToken.kernelAssetID,
                                                     db: db)
                Logger.general.info(category: "Withdraw", message: "Outputs signed")
            }
        }
        let rawRequestIDs = rawRequests.map(\.id)
        Logger.general.info(category: "Withdraw", message: "Will post tx: \(rawRequestIDs)")
        let postResponses = try await SafeAPI.postTransaction(requests: rawRequests)
        Logger.general.info(category: "Withdraw", message: "Will sign raw txs")
        RawTransactionDAO.shared.signRawTransactions(with: rawRequestIDs) { db in
            if let withdrawalResponse = postResponses.first(where: { $0.requestID == traceID }) {
                let snapshotID = withdrawalResponse.snapshotID
                try Trace.filter(key: traceID).updateAll(db, Trace.column(of: .snapshotId).set(to: snapshotID))
                Logger.general.info(category: "Withdraw", message: "Trace updated with: \(snapshotID)")
            }
            Logger.general.info(category: "Withdraw", message: "RawTx signed")
        }
    }
    
}