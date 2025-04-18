import Foundation
import WalletConnectSign
import Web3Wallet
import MixinServices

class SolanaTransferOperation: Web3TransferOperation {
    
    enum InitError: Error {
        case noFeeToken(String)
        case invalidAmount(Decimal)
        case buildTransaction
    }
    
    private enum SigningError: Error {
        case invalidTransaction
        case invalidBlockhash
        case noFeeToken(String)
    }
    
    fileprivate var fee: Fee?
    
    fileprivate init(
        fromAddress: String,
        toAddress: String,
        chain: Web3Chain,
        canDecodeBalanceChange: Bool
    ) throws {
        guard let feeToken = try chain.feeToken() else {
            throw InitError.noFeeToken(chain.feeTokenAssetID)
        }
        super.init(fromAddress: fromAddress,
                   toAddress: toAddress,
                   chain: chain,
                   feeToken: feeToken,
                   canDecodeBalanceChange: canDecodeBalanceChange,
                   isResendingTransactionAvailable: false)
    }
    
    func respond(signature: String) async throws {
        assertionFailure("Must override")
    }
    
    func baseFee(for transaction: Solana.Transaction) throws -> Fee {
        let lamportsPerSignature: UInt64 = 5000
        let tokenCount = try transaction.fee(lamportsPerSignature: lamportsPerSignature)
        let fiatMoneyCount = tokenCount * feeToken.decimalUSDPrice * Currency.current.decimalRate
        let fee = Fee(token: tokenCount, fiatMoney: fiatMoneyCount)
        return fee
    }
    
    func signAndSend(transaction: Solana.Transaction, with pin: String) async throws {
        let signedTransaction: String
        do {
            Logger.web3.info(category: "SolanaTransfer", message: "Start")
            let priv = try await TIP.deriveSolanaPrivateKey(pin: pin)
            let recentBlockhash = try await RouteAPI.solanaLatestBlockhash()
            Logger.web3.info(category: "SolanaTransfer", message: "Using blockhash: \(recentBlockhash)")
            guard let blockhash = Data(base58EncodedString: recentBlockhash) else {
                throw SigningError.invalidBlockhash
            }
            Logger.web3.info(category: "SolanaTransfer", message: "Will sign")
            signedTransaction = try transaction.sign(withPrivateKeyFrom: priv, recentBlockhash: blockhash)
        } catch {
            Logger.web3.error(category: "SolanaTransfer", message: "Failed to sign: \(error)")
            await MainActor.run {
                self.state = .signingFailed(error)
            }
            return
        }
        let fee = await MainActor.run {
            self.state = .sending
            return self.fee
        }
        do {
            Logger.web3.info(category: "SolanaTransfer", message: "Will send tx: \(signedTransaction)")
            let rawTransaction = try await RouteAPI.postTransaction(
                chainID: ChainID.solana,
                from: fromAddress,
                rawTransaction: signedTransaction
            )
            let transactionFee = if let fee {
                TokenAmountFormatter.string(from: fee.token)
            } else {
                ""
            }
            let pendingTransaction = switch try? await loadBalanceChange() {
            case .none, .decodingFailed:
                Web3Transaction(
                    transactionHash: rawTransaction.hash,
                    chainID: ChainID.solana,
                    address: fromAddress,
                    transactionType: .known(.unknown),
                    status: .pending,
                    blockNumber: -1,
                    fee: transactionFee,
                    senders: nil,
                    receivers: nil,
                    approvals: nil,
                    sendAssetID: nil,
                    receiveAssetID: nil,
                    transactionAt: rawTransaction.createdAt,
                    createdAt: rawTransaction.createdAt,
                    updatedAt: rawTransaction.createdAt
                )
            case let .detailed(token, decimalAmount):
                Web3Transaction(
                    transactionHash: rawTransaction.hash,
                    chainID: ChainID.solana,
                    address: fromAddress,
                    transactionType: .known(.transferOut),
                    status: .pending,
                    blockNumber: -1,
                    fee: transactionFee,
                    senders: [
                        .init(
                            assetID: token.assetID,
                            amount: TokenAmountFormatter.string(from: decimalAmount),
                            from: fromAddress
                        )
                    ],
                    receivers: nil,
                    approvals: nil,
                    sendAssetID: token.assetID,
                    receiveAssetID: nil,
                    transactionAt: rawTransaction.createdAt,
                    createdAt: rawTransaction.createdAt,
                    updatedAt: rawTransaction.createdAt
                )
            }
            Web3TransactionDAO.shared.save(transactions: [pendingTransaction]) { db in
                try rawTransaction.save(db)
            }
            let hash = rawTransaction.hash
            try await respond(signature: hash)
            Logger.web3.info(category: "SolanaTransfer", message: "Txn sent, hash: \(hash)")
            await MainActor.run {
                self.state = .success
                self.hasTransactionSent = true
            }
        } catch {
            Logger.web3.error(category: "SolanaTransfer", message: "Failed to send: \(error)")
            await MainActor.run {
                self.state = .sendingFailed(error)
            }
        }
    }
    
}

class ArbitraryTransactionSolanaTransferOperation: SolanaTransferOperation {
    
    fileprivate let transaction: Solana.Transaction
    
    private let walletID: String
    
    init(
        walletID: String,
        transaction: Solana.Transaction,
        fromAddress: String,
        toAddress: String,
        chain: Web3Chain
    ) throws {
        self.transaction = transaction
        self.walletID = walletID
        try super.init(fromAddress: fromAddress,
                       toAddress: toAddress,
                       chain: chain,
                       canDecodeBalanceChange: transaction.change != nil)
        self.state = .ready
    }
    
    override func loadBalanceChange() async throws -> BalanceChange {
        if let change = transaction.change,
           let token = Web3TokenDAO.shared.token(walletID: walletID, assetKey: change.assetKey)
        {
            .detailed(token: token, amount: change.amount)
        } else {
            .decodingFailed(rawTransaction: transaction.rawTransaction)
        }
    }
    
    override func loadFee() async throws -> Fee {
        // TODO: This could be wrong. Needs to add up the priority fee if the txn includes
        try baseFee(for: transaction)
    }
    
    override func start(pin: String) async throws {
        state = .signing
        try await self.signAndSend(transaction: transaction, with: pin)
    }
    
    override func respond(signature: String) async throws {
        Logger.web3.info(category: "SolanaTransfer", message: "Respond sig: \(signature)")
    }
    
    override func reject() {
        Logger.web3.info(category: "SolanaTransfer", message: "Rejected")
    }
    
    func transactionContainsSetAuthority() -> Bool {
        transaction.containsSetAuthority()
    }
    
}

final class SolanaTransferWithWalletConnectOperation: ArbitraryTransactionSolanaTransferOperation {
    
    let session: WalletConnectSession
    let request: WalletConnectSign.Request
    
    init(
        walletID: String,
        transaction: Solana.Transaction,
        fromAddress: String,
        chain: Web3Chain,
        session: WalletConnectSession,
        request: WalletConnectSign.Request
    ) throws {
        self.session = session
        self.request = request
        try super.init(
            walletID: walletID,
            transaction: transaction,
            fromAddress: fromAddress,
            toAddress: "", // FIXME: Decode txn
            chain: chain
        )
    }
    
    override func respond(signature: String) async throws {
        let response = RPCResult.response(AnyCodable(["signature": signature]))
        try await Web3Wallet.instance.respond(topic: request.topic,
                                              requestId: request.id,
                                              response: response)
    }
    
    override func reject() {
        Task {
            let error = JSONRPCError(code: 0, message: "User rejected")
            try await Web3Wallet.instance.respond(topic: request.topic,
                                                  requestId: request.id,
                                                  response: .error(error))
        }
    }
    
}

final class SolanaTransferWithCustomRespondingOperation: ArbitraryTransactionSolanaTransferOperation {
    
    private let respondImpl: ((String) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    init(
        walletID: String,
        transaction: Solana.Transaction,
        fromAddress: String,
        chain: Web3Chain,
        respondWith respondImpl: ((String) async throws -> Void)? = nil,
        rejectWith rejectImpl: (() -> Void)? = nil
    ) throws {
        self.respondImpl = respondImpl
        self.rejectImpl = rejectImpl
        try super.init(
            walletID: walletID,
            transaction: transaction,
            fromAddress: fromAddress,
            toAddress: "",
            chain: chain
        )
    }
    
    override func respond(signature: String) async throws {
        try await respondImpl?(signature)
    }
    
    override func reject() {
        rejectImpl?()
    }
    
}

final class SolanaTransferToAddressOperation: SolanaTransferOperation {
    
    private let payment: Web3SendingTokenToAddressPayment
    private let decimalAmount: Decimal
    private let amount: UInt64
    
    private var createAssociatedTokenAccountForReceiver: Bool?
    private var priorityFee: PriorityFee?
    
    init(payment: Web3SendingTokenToAddressPayment, decimalAmount: Decimal) throws {
        guard let amount = payment.token.nativeAmount(decimalAmount: decimalAmount) else {
            throw InitError.invalidAmount(decimalAmount)
        }
        self.payment = payment
        self.decimalAmount = decimalAmount
        self.amount = amount.uint64Value
        try super.init(fromAddress: payment.fromAddress,
                       toAddress: payment.toAddress,
                       chain: payment.chain,
                       canDecodeBalanceChange: true)
    }
    
    override func loadBalanceChange() async throws -> BalanceChange {
        .detailed(token: payment.token, amount: decimalAmount)
    }
    
    override func loadFee() async throws -> Fee {
        let ata = try Solana.tokenAssociatedAccount(owner: payment.toAddress, mint: payment.token.assetKey)
        let receiverAccountExists = try await RouteAPI.solanaAccountExists(pubkey: ata)
        let createAccount = !receiverAccountExists
        let transaction = try Solana.Transaction(
            from: payment.fromAddress,
            to: payment.toAddress,
            createAssociatedTokenAccountForReceiver: createAccount,
            amount: amount,
            priorityFee: nil,
            token: payment.token,
            change: .init(amount: decimalAmount, assetKey: payment.token.assetKey)
        )
        
        let baseFee = try baseFee(for: transaction)
        let priorityFee = try await RouteAPI.solanaPriorityFee(base64Transaction: transaction.rawTransaction)
        
        let tokenCount = baseFee.token + priorityFee.decimalCount
        let fiatMoneyCount = tokenCount * feeToken.decimalUSDPrice * Currency.current.decimalRate
        let fee = Fee(token: tokenCount, fiatMoney: fiatMoneyCount)
        
        await MainActor.run {
            self.createAssociatedTokenAccountForReceiver = createAccount
            self.priorityFee = priorityFee
            self.fee = fee
            self.state = .ready
        }
        return fee
    }
    
    override func start(pin: String) async throws {
        guard let createAccount = createAssociatedTokenAccountForReceiver, let priorityFee else {
            assertionFailure("This shouldn't happen. Check when `state` becomes `ready`")
            return
        }
        state = .signing
        let transaction = try Solana.Transaction(
            from: payment.fromAddress,
            to: payment.toAddress,
            createAssociatedTokenAccountForReceiver: createAccount,
            amount: amount,
            priorityFee: priorityFee,
            token: payment.token,
            change: .init(amount: decimalAmount, assetKey: payment.token.assetKey)
        )
        try await self.signAndSend(transaction: transaction, with: pin)
    }
    
    override func respond(signature: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
}
