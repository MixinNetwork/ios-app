import Foundation
import WalletConnectSign
import ReownWalletKit
import MixinServices

class SolanaTransferOperation: Web3TransferOperation {
    
    enum InitError: Error {
        case noFeeToken(String)
        case invalidAmount(Decimal)
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
            isResendingTransactionAvailable: false,
            hardcodedSimulation: hardcodedSimulation,
            isFeeWaived: isFeeWaived,
        )
    }
    
    func respond(signature: String) async throws {
        assertionFailure("Must override")
    }
    
    func baseFee(for transaction: Solana.Transaction) throws -> Web3DisplayFee {
        let lamportsPerSignature: UInt64 = 5000
        let tokenCount = try transaction.fee(lamportsPerSignature: lamportsPerSignature)
        let fiatMoneyAmount = tokenCount * feeToken.decimalUSDPrice * Currency.current.decimalRate
        let fee = Web3DisplayFee(
            token: feeToken,
            tokenAmount: tokenCount,
            fiatMoneyAmount: fiatMoneyAmount
        )
        return fee
    }
    
    func signAndSend(transaction: Solana.Transaction, with pin: String) async throws {
        let signedTransaction: String
        do {
            Logger.web3.info(category: "SolanaTransfer", message: "Start")
            let privateKey = try await wallet.solanaPrivateKey(pin: pin, address: fromAddress)
            let recentBlockhash = try await RouteAPI.solanaLatestBlockhash()
            Logger.web3.info(category: "SolanaTransfer", message: "Using blockhash: \(recentBlockhash)")
            guard let blockhash = Data(base58EncodedString: recentBlockhash) else {
                throw SigningError.invalidBlockhash
            }
            Logger.web3.info(category: "SolanaTransfer", message: "Will sign")
            signedTransaction = try transaction.sign(
                withPrivateKeyFrom: privateKey,
                recentBlockhash: blockhash
            )
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
                from: fromAddress.destination,
                rawTransaction: signedTransaction,
                feeType: isFeeWaived ? .free : nil,
            )
            let pendingTransaction = Web3Transaction(rawTransaction: rawTransaction, fee: fee?.tokenAmount)
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
    
    @MainActor init(
        wallet: Web3Wallet,
        transaction: Solana.Transaction,
        fromAddress: Web3Address,
        toAddress: String,
        chain: Web3Chain
    ) throws {
        self.transaction = transaction
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: toAddress,
            chain: chain,
            hardcodedSimulation: nil,
            isFeeWaived: false
        )
        self.state = .ready
    }
    
    override func loadFee() async throws -> Web3DisplayFee {
        // TODO: This could be wrong. Needs to add up the priority fee if the txn includes
        try baseFee(for: transaction)
    }
    
    override func simulateTransaction() async throws -> TransactionSimulation {
        try await RouteAPI.simulateSolanaTransaction(rawTransaction: transaction.rawTransaction)
    }
    
    override func start(pin: String) async throws {
        await MainActor.run {
            state = .signing
        }
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
    
    @MainActor init(
        wallet: Web3Wallet,
        transaction: Solana.Transaction,
        fromAddress: Web3Address,
        chain: Web3Chain,
        session: WalletConnectSession,
        request: WalletConnectSign.Request
    ) throws {
        self.session = session
        self.request = request
        try super.init(
            wallet: wallet,
            transaction: transaction,
            fromAddress: fromAddress,
            toAddress: "", // FIXME: Decode txn
            chain: chain
        )
    }
    
    override func respond(signature: String) async throws {
        let response = RPCResult.response(AnyCodable(["signature": signature]))
        try await WalletKit.instance.respond(
            topic: request.topic,
            requestId: request.id,
            response: response
        )
    }
    
    override func reject() {
        Task {
            let error = JSONRPCError(code: 0, message: "User rejected")
            try await WalletKit.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: .error(error)
            )
        }
    }
    
}

final class SolanaTransferWithCustomRespondingOperation: ArbitraryTransactionSolanaTransferOperation {
    
    private let respondImpl: ((String) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    @MainActor init(
        wallet: Web3Wallet,
        transaction: Solana.Transaction,
        fromAddress: Web3Address,
        chain: Web3Chain,
        respondWith respondImpl: ((String) async throws -> Void)? = nil,
        rejectWith rejectImpl: (() -> Void)? = nil
    ) throws {
        self.respondImpl = respondImpl
        self.rejectImpl = rejectImpl
        try super.init(
            wallet: wallet,
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
    
    @MainActor private var createAssociatedTokenAccountForReceiver: Bool?
    @MainActor private var tokenProgramID: String?
    @MainActor private var priorityFee: PriorityFee?
    
    init(payment: Web3SendingTokenToAddressPayment, decimalAmount: Decimal) throws {
        guard let amount = payment.token.nativeAmount(decimalAmount: decimalAmount) else {
            throw InitError.invalidAmount(decimalAmount)
        }
        let simulation: TransactionSimulation = .balanceChange(
            token: payment.token,
            amount: decimalAmount
        )
        let isFeeWaived = payment.toAddressLabel?.isFeeWaived() ?? false
        self.payment = payment
        self.decimalAmount = decimalAmount
        self.amount = amount.uint64Value
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
        let tokenProgramID = try await RouteAPI.solanaGetAccountInfo(pubkey: payment.token.assetKey).owner
        let ata = try Solana.tokenAssociatedAccount(
            walletAddress: payment.toAddress,
            mint: payment.token.assetKey,
            tokenProgramID: tokenProgramID
        )
        let receiverAccountExists = try await RouteAPI.solanaAccountExists(pubkey: ata)
        let createAccount = !receiverAccountExists
        let transaction = try Solana.Transaction(
            from: payment.fromAddress.destination,
            to: payment.toAddress,
            createAssociatedTokenAccountForReceiver: createAccount,
            tokenProgramID: tokenProgramID,
            mint: payment.token.assetKey,
            amount: amount,
            decimals: UInt8(payment.token.precision),
            priorityFee: nil,
            token: payment.token
        )
        
        let baseFee = try baseFee(for: transaction)
        let priorityFee = try await RouteAPI.solanaPriorityFee(base64Transaction: transaction.rawTransaction)
        
        let tokenAmount = baseFee.tokenAmount + priorityFee.decimalCount
        let fiatMoneyAmount = tokenAmount * feeToken.decimalUSDPrice * Currency.current.decimalRate
        let fee = Web3DisplayFee(token: feeToken, tokenAmount: tokenAmount, fiatMoneyAmount: fiatMoneyAmount)
        
        await MainActor.run {
            self.createAssociatedTokenAccountForReceiver = createAccount
            self.tokenProgramID = tokenProgramID
            self.priorityFee = priorityFee
            self.fee = fee
            self.state = .ready
        }
        return fee
    }
    
    override func start(pin: String) async throws {
        let (createAccount, tokenProgramID, priorityFee) = await MainActor.run {
            (
                self.createAssociatedTokenAccountForReceiver,
                self.tokenProgramID,
                self.priorityFee
            )
        }
        guard let createAccount, let tokenProgramID, let priorityFee else {
            assertionFailure("This shouldn't happen. Check when `state` becomes `ready`")
            return
        }
        await MainActor.run {
            state = .signing
        }
        let transaction = try Solana.Transaction(
            from: payment.fromAddress.destination,
            to: payment.toAddress,
            createAssociatedTokenAccountForReceiver: createAccount,
            tokenProgramID: tokenProgramID,
            mint: payment.token.assetKey,
            amount: amount,
            decimals: UInt8(payment.token.precision),
            priorityFee: priorityFee,
            token: payment.token
        )
        try await self.signAndSend(transaction: transaction, with: pin)
    }
    
    override func respond(signature: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
}
