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
    
    @MainActor fileprivate var fee: DisplayFee?
    
    fileprivate init(
        wallet: MixinServices.Web3Wallet,
        fromAddress: String,
        toAddress: String,
        chain: Web3Chain,
        hardcodedSimulation: TransactionSimulation?
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
        )
    }
    
    func respond(signature: String) async throws {
        assertionFailure("Must override")
    }
    
    func baseFee(for transaction: Solana.Transaction) throws -> DisplayFee {
        let lamportsPerSignature: UInt64 = 5000
        let tokenCount = try transaction.fee(lamportsPerSignature: lamportsPerSignature)
        let fiatMoneyAmount = tokenCount * feeToken.decimalUSDPrice * Currency.current.decimalRate
        let fee = DisplayFee(tokenAmount: tokenCount, fiatMoneyAmount: fiatMoneyAmount)
        return fee
    }
    
    func signAndSend(transaction: Solana.Transaction, with pin: String) async throws {
        let signedTransaction: String
        do {
            Logger.web3.info(category: "SolanaTransfer", message: "Start")
            let privateKey: Data
            switch wallet.category.knownCase {
            case .classic:
                privateKey = try await TIP.deriveSolanaPrivateKey(pin: pin)
            case .importedMnemonic, .importedPrivateKey:
                guard let encryptedKey = AppGroupKeychain.encryptedWalletPrivateKey(address: fromAddress) else {
                    throw SigningError.missingPrivateKey
                }
                let spendKey = try await TIP.importedWalletSpendKey(pin: pin)
                privateKey = try AESCryptor.decrypt(encryptedKey, with: spendKey)
            case .none:
                throw SigningError.unknownCategory
            }
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
                from: fromAddress,
                rawTransaction: signedTransaction
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
        wallet: MixinServices.Web3Wallet,
        transaction: Solana.Transaction,
        fromAddress: String,
        toAddress: String,
        chain: Web3Chain
    ) throws {
        self.transaction = transaction
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: toAddress,
            chain: chain,
            hardcodedSimulation: nil
        )
        self.state = .ready
    }
    
    override func loadFee() async throws -> DisplayFee {
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
        wallet: MixinServices.Web3Wallet,
        transaction: Solana.Transaction,
        fromAddress: String,
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
        try await Web3Wallet.instance.respond(
            topic: request.topic,
            requestId: request.id,
            response: response
        )
    }
    
    override func reject() {
        Task {
            let error = JSONRPCError(code: 0, message: "User rejected")
            try await Web3Wallet.instance.respond(
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
        wallet: MixinServices.Web3Wallet,
        transaction: Solana.Transaction,
        fromAddress: String,
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
    
    private var createAssociatedTokenAccountForReceiver: Bool?
    private var priorityFee: PriorityFee?
    
    init(payment: Web3SendingTokenToAddressPayment, decimalAmount: Decimal) throws {
        guard let amount = payment.token.nativeAmount(decimalAmount: decimalAmount) else {
            throw InitError.invalidAmount(decimalAmount)
        }
        let simulation: TransactionSimulation = .balanceChange(
            token: payment.token,
            amount: decimalAmount
        )
        self.payment = payment
        self.decimalAmount = decimalAmount
        self.amount = amount.uint64Value
        try super.init(
            wallet: payment.wallet,
            fromAddress: payment.fromAddress,
            toAddress: payment.toAddress,
            chain: payment.chain,
            hardcodedSimulation: simulation
        )
    }
    
    override func loadFee() async throws -> DisplayFee {
        let ata = try Solana.tokenAssociatedAccount(owner: payment.toAddress, mint: payment.token.assetKey)
        let receiverAccountExists = try await RouteAPI.solanaAccountExists(pubkey: ata)
        let createAccount = !receiverAccountExists
        let transaction = try Solana.Transaction(
            from: payment.fromAddress,
            to: payment.toAddress,
            createAssociatedTokenAccountForReceiver: createAccount,
            amount: amount,
            priorityFee: nil,
            token: payment.token
        )
        
        let baseFee = try baseFee(for: transaction)
        let priorityFee = try await RouteAPI.solanaPriorityFee(base64Transaction: transaction.rawTransaction)
        
        let tokenAmount = baseFee.tokenAmount + priorityFee.decimalCount
        let fiatMoneyAmount = tokenAmount * feeToken.decimalUSDPrice * Currency.current.decimalRate
        let fee = DisplayFee(tokenAmount: tokenAmount, fiatMoneyAmount: fiatMoneyAmount)
        
        await MainActor.run {
            self.createAssociatedTokenAccountForReceiver = createAccount
            self.priorityFee = priorityFee
            self.fee = fee
            self.state = .ready
        }
        return fee
    }
    
    override func start(pin: String) async throws {
        let (createAccount, priorityFee) = await MainActor.run {
            (self.createAssociatedTokenAccountForReceiver, self.priorityFee)
        }
        guard let createAccount, let priorityFee else {
            assertionFailure("This shouldn't happen. Check when `state` becomes `ready`")
            return
        }
        await MainActor.run {
            state = .signing
        }
        let transaction = try Solana.Transaction(
            from: payment.fromAddress,
            to: payment.toAddress,
            createAssociatedTokenAccountForReceiver: createAccount,
            amount: amount,
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
