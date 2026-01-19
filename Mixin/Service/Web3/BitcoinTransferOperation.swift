import Foundation
import WalletConnectSign
import ReownWalletKit
import MixinServices

class BitcoinTransferOperation: Web3TransferOperation {
    
    enum InitError: Error {
        case noFeeToken(String)
        case invalidOutputAmount(String)
        case insufficientOutputs
        case buildTransaction
    }
    
    fileprivate init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        toAddress: String,
        chain: Web3Chain,
        hardcodedSimulation: TransactionSimulation?,
        isFeeWaived: Bool,
    ) throws {
        guard let feeToken = try chain.feeToken(walletID: wallet.walletID) else {
            throw InitError.noFeeToken(chain.feeTokenAssetID)
        }
        super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: toAddress,
            chain: chain,
            feeToken: feeToken,
            isResendingTransactionAvailable: true,
            hardcodedSimulation: hardcodedSimulation,
            isFeeWaived: isFeeWaived,
        )
    }
    
    func respond(signature: String) async throws {
        assertionFailure("Must override")
    }
    
}

final class BitcoinTransferToAddressOperation: BitcoinTransferOperation {
    
    enum SigningError: Error {
        case feeNotReady
    }
    
    private let payment: Web3SendingTokenToAddressPayment
    private let decimalAmount: Decimal
    private let allOutputs: [Web3Output]
    
    @MainActor
    private var spendingOutputs: [Web3Output]?
    
    init(
        payment: Web3SendingTokenToAddressPayment,
        decimalAmount: Decimal,
    ) throws {
        let allOutputs = Web3OutputDAO.shared.unspentOutputs(
            address: payment.fromAddress.destination,
            assetID: payment.token.assetID
        )
        let simulation: TransactionSimulation = .balanceChange(
            token: payment.token,
            amount: decimalAmount
        )
        let isFeeWaived = payment.toAddressLabel?.isFeeWaived() ?? false
        self.payment = payment
        self.decimalAmount = decimalAmount
        self.allOutputs = allOutputs
        try super.init(
            wallet: payment.wallet,
            fromAddress: payment.fromAddress,
            toAddress: payment.toAddress,
            chain: payment.chain,
            hardcodedSimulation: simulation,
            isFeeWaived: isFeeWaived,
        )
    }
    
    override func loadFee() async throws -> Web3DisplayFee {
        let fee = try await RouteAPI.bitcoinFee()
        let calculator = Bitcoin.P2WPKHFeeCalculator(
            outputs: allOutputs,
            rate: fee.rate,
            minimum: fee.minimum,
        )
        let result = try calculator.calculate(transferAmount: decimalAmount)
        let fiatMoneyAmount = result.feeAmount * payment.token.decimalUSDPrice * Currency.current.decimalRate
        let displayFee = Web3DisplayFee(
            token: payment.token,
            tokenAmount: result.feeAmount,
            fiatMoneyAmount: fiatMoneyAmount
        )
        await MainActor.run {
            self.fee = displayFee
            self.spendingOutputs = result.spendingOutputs
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
        let signedTransaction: Bitcoin.SignedTransaction
        do {
            Logger.web3.info(category: "BitcoinTransfer", message: "Start")
            let privateKey = try await wallet.bitcoinPrivateKey(pin: pin, address: fromAddress)
            Logger.web3.info(category: "BitcoinTransfer", message: "Spend outputs: \(spendingOutputs)")
            signedTransaction = try Bitcoin.signedTransaction(
                outputs: spendingOutputs,
                sendAddress: payment.fromAddress.destination,
                sendAmount: decimalAmount,
                fee: fee.tokenAmount,
                receiveAddress: payment.toAddress,
                privateKey: privateKey
            )
            if let changeOutput = signedTransaction.changeOutput {
                Logger.web3.info(category: "BitcoinTransfer", message: "Change: \(changeOutput)")
            }
        } catch {
            Logger.web3.error(category: "BitcoinTransfer", message: "Failed to sign: \(error)")
            await MainActor.run {
                self.state = .signingFailed(error)
            }
            return
        }
        await MainActor.run {
            self.state = .sending
        }
        do {
            Logger.web3.info(category: "BitcoinTransfer", message: "Will send tx: \(signedTransaction.transaction)")
            let rawTransaction = try await RouteAPI.postTransaction(
                chainID: ChainID.bitcoin,
                from: fromAddress.destination,
                rawTransaction: signedTransaction.transaction,
                feeType: isFeeWaived ? .free : nil,
            )
            let hash = rawTransaction.hash
            Logger.web3.info(category: "BitcoinTransfer", message: "Tx sent, hash: \(hash)")
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
                    address: payment.fromAddress.destination,
                    assetID: payment.token.assetID,
                    db: db,
                    postTokenChangeNofication: true,
                )
            }
            Logger.web3.info(category: "BitcoinTransfer", message: "Tx saved")
            try await respond(signature: hash)
            await MainActor.run {
                self.state = .success
                self.hasTransactionSent = true
            }
        } catch {
            Logger.web3.error(category: "BitcoinTransfer", message: "Failed to send: \(error)")
            await MainActor.run {
                self.state = .sendingFailed(error)
            }
        }
    }
    
    override func respond(signature: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
}
