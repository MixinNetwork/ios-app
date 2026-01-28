import Foundation
import WalletConnectSign
import ReownWalletKit
import MixinServices

class BitcoinTransferOperation: Web3TransferOperation {
    
    enum SigningError: Error {
        case feeNotReady
        case missingToAddress
    }
    
    enum InitError: Error {
        case missingToken
        case invalidOutputAmount(String)
        case insufficientOutputs
        case buildTransaction
    }
    
    static let assetID = AssetID.btc
    
    fileprivate let token: Web3TokenItem
    fileprivate let sendAmount: Decimal
    
    @MainActor
    fileprivate var spendingOutputs: [Web3Output]?
    
    fileprivate init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        toAddress: String,
        hardcodedSimulation: TransactionSimulation?,
        isFeeWaived: Bool,
        sendAmount: Decimal,
    ) throws {
        let token = Web3TokenDAO.shared.token(
            walletID: wallet.walletID,
            assetID: Self.assetID
        )
        guard let token else {
            throw InitError.missingToken
        }
        self.token = token
        self.sendAmount = sendAmount
        super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: toAddress,
            chain: .bitcoin,
            feeToken: token,
            isResendingTransactionAvailable: true,
            hardcodedSimulation: hardcodedSimulation,
            isFeeWaived: isFeeWaived,
        )
    }
    
    override func start(pin: String) async throws {
        let (fee, spendingOutputs) = await MainActor.run {
            (self.fee, self.spendingOutputs)
        }
        guard let fee, let spendingOutputs else {
            throw SigningError.feeNotReady
        }
        guard let toAddress else {
            throw SigningError.missingToAddress
        }
        await MainActor.run {
            state = .signing
        }
        let signedTransaction: Bitcoin.SignedTransaction
        do {
            Logger.web3.info(category: "BTCTransfer", message: "Start")
            let privateKey = try await wallet.bitcoinPrivateKey(pin: pin, address: fromAddress)
            Logger.web3.info(category: "BTCTransfer", message: "Spend outputs: \(spendingOutputs)")
            signedTransaction = try Bitcoin.signedTransaction(
                outputs: spendingOutputs,
                sendAddress: fromAddress.destination,
                sendAmount: sendAmount,
                fee: fee.tokenAmount,
                receiveAddress: toAddress,
                privateKey: privateKey
            )
            if let changeOutput = signedTransaction.changeOutput {
                Logger.web3.info(category: "BTCTransfer", message: "Change: \(changeOutput)")
            }
        } catch {
            Logger.web3.error(category: "BTCTransfer", message: "Failed to sign: \(error)")
            await MainActor.run {
                self.state = .signingFailed(error)
            }
            return
        }
        let feeRate = TokenAmountFormatter.string(
            from: fee.tokenAmount / .satoshi / Decimal(signedTransaction.vsize)
        )
        await MainActor.run {
            self.state = .sending
        }
        do {
            Logger.web3.info(category: "BTCTransfer", message: "Will send tx: \(signedTransaction.transaction)")
            let rawTransaction = try await RouteAPI
                .postTransaction(
                    chainID: ChainID.bitcoin,
                    from: fromAddress.destination,
                    rawTransaction: signedTransaction.transaction,
                    feeType: isFeeWaived ? .free : nil,
                )
                .replacingNonce(with: feeRate)
            let hash = rawTransaction.hash
            Logger.web3.info(category: "BTCTransfer", message: "Tx sent, hash: \(hash)")
            let pendingTransaction = Web3Transaction(rawTransaction: rawTransaction, fee: fee.tokenAmount)
            Web3TransactionDAO.shared.save(transactions: [pendingTransaction]) { db in
                try rawTransaction.save(db)
                try Web3OutputDAO.shared.sign(
                    outputIDs: spendingOutputs.map(\.id),
                    save: signedTransaction.changeOutput,
                    db: db
                )
                try Web3TokenDAO.shared.updateAmountByOutputs(
                    walletID: wallet.walletID,
                    address: fromAddress.destination,
                    assetID: token.assetID,
                    db: db,
                    postTokenChangeNofication: true,
                )
            }
            Logger.web3.info(category: "BTCTransfer", message: "Tx saved")
            await MainActor.run {
                self.state = .success
                self.hasTransactionSent = true
            }
        } catch {
            Logger.web3.error(category: "BTCTransfer", message: "Failed to send: \(error)")
            await MainActor.run {
                self.state = .sendingFailed(error)
            }
        }
    }
    
    override func reject() {
        
    }
    
}

final class BitcoinTransferToAddressOperation: BitcoinTransferOperation {
    
    private let payment: Web3SendingTokenToAddressPayment
    private let allOutputs: [Web3Output]
    
    init(
        payment: Web3SendingTokenToAddressPayment,
        decimalAmount: Decimal,
    ) throws {
        let allOutputs = Web3OutputDAO.shared.outputs(
            address: payment.fromAddress.destination,
            assetID: payment.token.assetID,
            status: [.unspent, .pending],
        )
        let simulation: TransactionSimulation = .balanceChange(
            token: payment.token,
            amount: decimalAmount
        )
        let isFeeWaived = payment.toAddressLabel?.isFeeWaived() ?? false
        self.payment = payment
        self.allOutputs = allOutputs
        try super.init(
            wallet: payment.wallet,
            fromAddress: payment.fromAddress,
            toAddress: payment.toAddress,
            hardcodedSimulation: simulation,
            isFeeWaived: isFeeWaived,
            sendAmount: decimalAmount,
        )
    }
    
    override func loadFee() async throws -> Web3DisplayFee {
        let info = try await RouteAPI.bitcoinNetworkInfo(feeRate: nil)
        let calculator = Bitcoin.P2WPKHFeeCalculator(
            outputs: allOutputs,
            rate: info.decimalFeeRate,
            minimum: info.minimalFee,
        )
        let result = try calculator.calculate(transferAmount: sendAmount)
        let displayFee = Web3DisplayFee(token: payment.token, amount: result.feeAmount)
        await MainActor.run {
            self.fee = displayFee
            self.spendingOutputs = result.spendingOutputs
            self.state = .ready
        }
        return displayFee
    }
    
}

// MARK: - Override Transactions
class BitcoinRBFOperation: BitcoinTransferOperation {
    
    enum InitError: Error {
        case invalidFeeRate(String)
        case missingSpentOutputs
        case invalidOutputsCount
        case missingTransferOutput
        case invalidCancellation
        case spentChangeOutput
    }
    
    fileprivate let previousInputsAmount: Decimal
    fileprivate let previousFeeAmount: Decimal
    fileprivate let previousFeeRate: String
    fileprivate let decimalPreviousFeeRate: Decimal
    fileprivate let previousSpentOutputs: [Web3Output]
    fileprivate let availableOutputs: [Web3Output]
    
    init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        rawTransaction: Web3RawTransaction,
        decodedTransaction: Bitcoin.DecodedTransaction,
        newToAddress: String,
        newSendAmount: Decimal
    ) throws {
        let previousFeeRate = rawTransaction.nonce
        let decimalPreviousFeeRate = Decimal(string: previousFeeRate, locale: .enUSPOSIX)
        guard let decimalPreviousFeeRate else {
            throw InitError.invalidFeeRate(previousFeeRate)
        }
        
        var availableOutputs = Web3OutputDAO.shared.outputs(
            address: fromAddress.destination,
            assetID: Self.assetID,
            status: [.unspent]
        )
        let spentOutputs = Web3OutputDAO.shared.outputs(
            ids: decodedTransaction.inputs.map(\.outputID)
        )
        guard spentOutputs.count == decodedTransaction.inputs.count else {
            throw InitError.missingSpentOutputs
        }
        availableOutputs.insert(contentsOf: spentOutputs, at: 0)
        
        let inputsAmount: Decimal = spentOutputs.reduce(0) { result, output in
            result + output.decimalAmount
        }
        let outputsAmount = Decimal(decodedTransaction.outputs.map(\.value).reduce(0, +)) * .satoshi
        let previousFeeAmount = inputsAmount - outputsAmount
        
        self.previousInputsAmount = inputsAmount
        self.previousFeeAmount = previousFeeAmount
        self.previousFeeRate = previousFeeRate
        self.decimalPreviousFeeRate = decimalPreviousFeeRate
        self.previousSpentOutputs = spentOutputs
        self.availableOutputs = availableOutputs
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: newToAddress,
            hardcodedSimulation: .empty,
            isFeeWaived: false,
            sendAmount: newSendAmount,
        )
    }
    
}

final class BitcoinSpeedUpOperation: BitcoinRBFOperation {
    
    init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        transaction: Web3RawTransaction,
    ) throws {
        let tx = try Bitcoin.decode(transaction: transaction.raw)
        guard tx.outputs.count == 1 || tx.outputs.count == 2 else {
            throw InitError.invalidOutputsCount
        }
        
        var changeOutputID: String?
        var transferOutput: Bitcoin.DecodedTransaction.Output?
        for (i, output) in tx.outputs.enumerated() {
            if output.address == fromAddress.destination {
                changeOutputID = Web3Output.bitcoinOutputID(txid: transaction.hash, vout: i)
            } else {
                transferOutput = output
            }
        }
        
        guard let transferOutput else {
            throw InitError.missingTransferOutput
        }
        if let id = changeOutputID, !Web3OutputDAO.shared.isOutputAvailable(id: id) {
            throw InitError.spentChangeOutput
        }
        
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            rawTransaction: transaction,
            decodedTransaction: tx,
            newToAddress: transferOutput.address,
            newSendAmount: Decimal(transferOutput.value) * .satoshi,
        )
    }
    
    override func loadFee() async throws -> Web3DisplayFee {
        let displayFee: Web3DisplayFee
        let info = try await RouteAPI.bitcoinNetworkInfo(feeRate: previousFeeRate)
        if info.decimalFeeRate <= decimalPreviousFeeRate {
            let calculator = Bitcoin.P2WPKHFeeCalculator(
                outputs: availableOutputs,
                rate: decimalPreviousFeeRate,
                minimum: info.minimalFee,
            )
            let result = try calculator.calculate(transferAmount: sendAmount)
            Logger.web3.info(category: "BTCSpeedUp", message: "Already speedy")
            displayFee = Web3DisplayFee(token: token, amount: result.feeAmount)
            await MainActor.run {
                self.fee = displayFee // Really?
                self.state = .unavailable(reason: R.string.localizable.btc_tx_already_speedy())
            }
        } else {
            let calculator = Bitcoin.P2WPKHFeeCalculator(
                outputs: availableOutputs,
                rate: info.decimalFeeRate,
                minimum: max(info.minimalFee, previousFeeAmount),
            )
            let result = try calculator.calculate(transferAmount: sendAmount)
            Logger.web3.info(category: "BTCSpeedUp", message: "Using \(result)")
            displayFee = Web3DisplayFee(token: token, amount: result.feeAmount)
            await MainActor.run {
                self.spendingOutputs = result.spendingOutputs
                self.fee = displayFee
                self.state = .ready
            }
        }
        return displayFee
    }
    
}

final class BitcoinCancelOperation: BitcoinRBFOperation {
    
    private enum CancellationError: Error {
        case unexpectedChange
    }
    
    private let previousChangeOutputID: String?
    
    init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        transaction: Web3RawTransaction,
    ) throws {
        let tx = try Bitcoin.decode(transaction: transaction.raw)
        guard tx.outputs.count == 1 || tx.outputs.count == 2 else {
            throw InitError.invalidOutputsCount
        }
        
        var changeOutputID: String?
        var hasOutputToOthers = false
        for (i, output) in tx.outputs.enumerated() {
            if output.address == fromAddress.destination {
                changeOutputID = Web3Output.bitcoinOutputID(txid: transaction.hash, vout: i)
            } else {
                hasOutputToOthers = true
            }
        }
        
        guard hasOutputToOthers else {
            throw InitError.invalidCancellation
        }
        if let id = changeOutputID, !Web3OutputDAO.shared.isOutputAvailable(id: id) {
            throw InitError.spentChangeOutput
        }
        
        self.previousChangeOutputID = changeOutputID
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            rawTransaction: transaction,
            decodedTransaction: tx,
            newToAddress: fromAddress.destination,
            newSendAmount: -1
        )
    }
    
    override func loadFee() async throws -> Web3DisplayFee {
        let info = try await RouteAPI.bitcoinNetworkInfo(feeRate: previousFeeRate)
        let calculator = Bitcoin.P2WPKHFeeCalculator(
            outputs: availableOutputs,
            rate: info.decimalFeeRate,
            minimum: info.minimalFee,
        )
        let result = try calculator.calculateCancellation(
            requiredOutputIDs: Set(previousSpentOutputs.map(\.id)),
            originalFee: previousFeeAmount,
            incrementalFee: info.incrementalFee
        )
        Logger.web3.info(category: "BTCCancel", message: "Using \(result)")
        let displayFee = Web3DisplayFee(token: token, amount: result.feeAmount)
        await MainActor.run {
            self.spendingOutputs = result.spendingOutputs
            self.fee = displayFee
            self.state = .ready
        }
        return displayFee
    }
    
    override func start(pin: String) async throws {
        let (fee, spendingOutputs) = await MainActor.run {
            (self.fee, self.spendingOutputs)
        }
        guard let fee, let spendingOutputs else {
            throw SigningError.feeNotReady
        }
        await MainActor.run {
            state = .signing
        }
        let sendAmount = previousInputsAmount - fee.tokenAmount
        let signedTransaction: Bitcoin.SignedTransaction
        do {
            Logger.web3.info(category: "BTCCancel", message: "Start")
            let privateKey = try await wallet.bitcoinPrivateKey(pin: pin, address: fromAddress)
            Logger.web3.info(category: "BTCCancel", message: "Cancel inputs: \(spendingOutputs)")
            signedTransaction = try Bitcoin.signedTransaction(
                outputs: spendingOutputs,
                sendAddress: fromAddress.destination,
                sendAmount: sendAmount,
                fee: fee.tokenAmount,
                receiveAddress: fromAddress.destination,
                privateKey: privateKey
            )
            guard signedTransaction.changeOutput == nil else {
                throw CancellationError.unexpectedChange
            }
        } catch {
            Logger.web3.error(category: "BTCCancel", message: "Failed to sign: \(error)")
            await MainActor.run {
                self.state = .signingFailed(error)
            }
            return
        }
        let feeRate = TokenAmountFormatter.string(
            from: fee.tokenAmount / .satoshi / Decimal(signedTransaction.vsize)
        )
        await MainActor.run {
            self.state = .sending
        }
        do {
            Logger.web3.info(category: "BTCCancel", message: "Will send tx: \(signedTransaction.transaction)")
            let rawTransaction = try await RouteAPI
                .postTransaction(
                    chainID: ChainID.bitcoin,
                    from: fromAddress.destination,
                    rawTransaction: signedTransaction.transaction,
                    feeType: isFeeWaived ? .free : nil,
                )
                .replacingNonce(with: feeRate)
            Logger.web3.info(category: "BTCCancel", message: "Tx sent, hash: \(rawTransaction.hash)")
            let pendingTransaction = Web3Transaction(rawTransaction: rawTransaction, fee: fee.tokenAmount)
            let now = Date().toUTCString()
            let receivingOutput = Web3Output(
                id: Web3Output.bitcoinOutputID(txid: rawTransaction.hash, vout: 0),
                assetID: token.assetID,
                transactionHash: rawTransaction.hash,
                outputIndex: 0,
                amount: TokenAmountFormatter.string(from: sendAmount),
                address: fromAddress.destination,
                pubkeyHex: "",
                pubkeyType: "",
                status: .pending,
                createdAt: now,
                updatedAt: now
            )
            Web3TransactionDAO.shared.save(transactions: [pendingTransaction]) { db in
                try rawTransaction.save(db)
                if let id = previousChangeOutputID {
                    try Web3OutputDAO.shared.delete(id: id, db: db)
                }
                try Web3OutputDAO.shared.sign(
                    outputIDs: spendingOutputs.map(\.id),
                    save: receivingOutput,
                    db: db
                )
                try Web3TokenDAO.shared.updateAmountByOutputs(
                    walletID: wallet.walletID,
                    address: fromAddress.destination,
                    assetID: token.assetID,
                    db: db,
                    postTokenChangeNofication: true,
                )
            }
            Logger.web3.info(category: "BTCCancel", message: "Tx saved")
            await MainActor.run {
                self.state = .success
                self.hasTransactionSent = true
            }
        } catch {
            Logger.web3.error(category: "BTCCancel", message: "Failed to send: \(error)")
            await MainActor.run {
                self.state = .sendingFailed(error)
            }
        }
    }
    
}
