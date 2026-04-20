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
        simulationDisplay: SimulationDisplay,
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
            simulationDisplay: simulationDisplay,
            isFeeWaived: isFeeWaived,
        )
    }
    
    fileprivate func respond(signature: String) async throws {
        assertionFailure("Must override")
    }
    
    fileprivate func baseFee(for transaction: Solana.Transaction) throws -> Web3DisplayFee {
        let lamportsPerSignature: UInt64 = 5000
        let amount = try transaction.fee(lamportsPerSignature: lamportsPerSignature)
        let fee = Web3DisplayFee(token: nativeFeeToken, amount: amount, gasless: false)
        return fee
    }
    
    fileprivate func sign(transaction: Solana.Transaction, with pin: String) async throws -> String {
        Logger.web3.info(category: "SolanaTransfer", message: "Start")
        let privateKey = try await wallet.solanaPrivateKey(pin: pin, address: fromAddress)
        let recentBlockhash = try await RouteAPI.solanaLatestBlockhash()
        Logger.web3.info(category: "SolanaTransfer", message: "Using blockhash: \(recentBlockhash)")
        guard let blockhash = Data(base58EncodedString: recentBlockhash) else {
            throw SigningError.invalidBlockhash
        }
        Logger.web3.info(category: "SolanaTransfer", message: "Will sign")
        return try transaction.sign(
            withPrivateKeyFrom: privateKey,
            recentBlockhash: blockhash
        )
    }
    
    fileprivate func send(signedTransaction: String, fee: Web3DisplayFee?) async throws {
        Logger.web3.info(category: "SolanaTransfer", message: "Will send tx: \(signedTransaction)")
        let rawTransaction = try await RouteAPI.postTransaction(
            chainID: ChainID.solana,
            from: fromAddress.destination,
            rawTransaction: signedTransaction,
            feeType: isFeeWaived ? .free : nil,
        )
        let pendingTransaction = Web3Transaction(
            rawTransaction: rawTransaction,
            fee: fee?.amount,
            myAddress: fromAddress.destination
        )
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
            simulationDisplay: .byRemote,
            isFeeWaived: false
        )
        self.state = .ready
    }
    
    override func reloadFee() async throws -> Fee {
        // TODO: This could be wrong. Needs to add up the priority fee if the txn includes
        let baseFee = try baseFee(for: transaction)
        return Fee(options: [baseFee], selectedIndex: 0)
    }
    
    override func simulateTransaction() async throws -> TransactionSimulation {
        try await RouteAPI.simulateSolanaTransaction(rawTransaction: transaction.rawTransaction)
    }
    
    override func start(pin: String) async throws {
        await MainActor.run {
            state = .signing
        }
        let signedTransaction: String
        do {
            signedTransaction = try await sign(transaction: transaction, with: pin)
        } catch {
            Logger.web3.error(category: "SolanaTransfer", message: "Failed to sign: \(error)")
            await MainActor.run {
                self.state = .signingFailed(error)
            }
            return
        }
        let fee = await MainActor.run {
            self.state = .sending
            return self.fee?.selected
        }
        do {
            try await send(signedTransaction: signedTransaction, fee: fee)
        } catch {
            Logger.web3.error(category: "SolanaTransfer", message: "Failed to send: \(error)")
            await MainActor.run {
                self.state = .sendingFailed(error)
            }
        }
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
    
    enum ReceiverAccountStatus {
        case unknown
        case notInvolved // Gasless
        case exist
        case notExist
    }
    
    struct NativeTransferContext {
        let createAssociatedTokenAccountForReceiver: Bool
        let tokenProgramID: String
        let priorityFee: PriorityFee
    }
    
    @MainActor
    private(set) var receiverAccountStatus: ReceiverAccountStatus = .unknown
    
    @MainActor
    private(set) var nativeTransferContext: NativeTransferContext?
    
    private let payment: Web3SendingTokenToAddressPayment
    private let decimalAmount: Decimal
    private let amount: UInt64
    private let feePolicy: FeePolicy
    
    init(
        payment: Web3SendingTokenToAddressPayment,
        decimalAmount: Decimal,
        feePolicy: FeePolicy,
    ) throws {
        guard let amount = payment.token.nativeAmount(decimalAmount: decimalAmount) else {
            throw InitError.invalidAmount(decimalAmount)
        }
        let simulation: TransactionSimulation = .balanceChange(
            token: payment.token,
            amount: decimalAmount,
            from: payment.fromAddress.destination
        )
        let isFeeWaived = payment.toAddressLabel?.isFeeWaived() ?? false
        self.payment = payment
        self.decimalAmount = decimalAmount
        self.amount = amount.uint64Value
        self.feePolicy = feePolicy
        try super.init(
            wallet: payment.wallet,
            fromAddress: payment.fromAddress,
            toAddress: payment.toAddress,
            chain: payment.chain,
            simulationDisplay: .byLocal(simulation),
            isFeeWaived: isFeeWaived,
        )
    }
    
    override func reloadFee() async throws -> Fee {
        switch feePolicy {
        case .prefersGasless:
            do {
                let fees = try await RouteAPI.gaslessFees(
                    from: payment.fromAddress.destination,
                    to: payment.toAddress,
                    assetID: payment.token.assetID,
                    chainID: payment.token.chainID
                )
                let tokens = try await Self.tokens(
                    walletID: payment.wallet.walletID,
                    assetIDs: fees.map(\.assetID)
                )
                let options = fees.compactMap { fee in
                    if let token = tokens[fee.assetID] {
                        Web3DisplayFee(token: token, amount: fee.amount, gasless: true)
                    } else {
                        nil
                    }
                }
                if options.isEmpty {
                    throw FeeLoadingError.gaslessUnavailable
                }
                let fee = Fee(options: options, selectedIndex: 0)
                await MainActor.run {
                    self.receiverAccountStatus = .notInvolved
                    self.nativeTransferContext = nil
                    self.fee = fee
                    self.state = .ready
                }
                return fee
            } catch {
                Logger.web3.error(category: "SolanaTransfer", message: "Gasless unavailable: \(error)")
                return try await reloadNativeFee()
            }
        case .prefersGaslessTrade:
            do {
                let amount = decimalAmount.formatted(
                    tokenAmountFormat(precision: payment.token.precision)
                )
                let proposal = try await RouteAPI.gaslessPrepare(
                    from: payment.fromAddress.destination,
                    to: payment.toAddress,
                    assetID: payment.token.assetID,
                    amount: amount,
                    feeAssetID: payment.token.assetID,
                    feeAmount: nil,
                    chainID: payment.token.chainID
                )
                let option = Web3GaslessTradingFee(
                    token: payment.token,
                    proposal: proposal
                )
                let fee = Fee(options: [option], selectedIndex: 0)
                await MainActor.run {
                    self.receiverAccountStatus = .notInvolved
                    self.nativeTransferContext = nil
                    self.fee = fee
                    self.state = .ready
                }
                return fee
            } catch {
                Logger.web3.error(category: "SolanaTransfer", message: "Gasless unavailable: \(error)")
                return try await reloadNativeFee()
            }
        case .alwaysNative:
            return try await reloadNativeFee()
        }
    }
    
    override func start(pin: String) async throws {
        guard let fee = await self.fee?.selected else {
            throw SigningError.noFeeLoaded
        }
        if fee.gasless {
            Logger.web3.info(category: "SolanaTransfer(Gasless)", message: "Start")
            await MainActor.run {
                state = .signing
            }
            let chainID = payment.token.chainID
            let signedTransaction: String
            do {
                let proposal: GaslessTransactionProposal
                if let fee = fee as? Web3GaslessTradingFee {
                    proposal = fee.proposal
                } else {
                    let amount = decimalAmount.formatted(
                        tokenAmountFormat(precision: payment.token.precision)
                    )
                    let feeAmount = fee.amount.formatted(
                        tokenAmountFormat(precision: fee.token.precision)
                    )
                    proposal = try await RouteAPI.gaslessPrepare(
                        from: payment.fromAddress.destination,
                        to: payment.toAddress,
                        assetID: payment.token.assetID,
                        amount: amount,
                        feeAssetID: fee.token.assetID,
                        feeAmount: feeAmount,
                        chainID: chainID,
                    )
                }
                guard proposal.chainID == chainID else {
                    throw SigningError.gaslessChainMismatch
                }
                guard case let .solana(transaction) = proposal.payload else {
                    throw SigningError.gaslessPayloadMismatch
                }
                Logger.web3.info(category: "SolanaTransfer(Gasless)", message: "Will sign")
                let privateKey = try await wallet.solanaPrivateKey(pin: pin, address: fromAddress)
                signedTransaction = try transaction.sign(withPrivateKeyFrom: privateKey, recentBlockhash: nil)
            } catch {
                Logger.web3.error(category: "SolanaTransfer(Gasless)", message: "Failed to sign: \(error)")
                await MainActor.run {
                    state = .sendingFailed(error)
                }
                return
            }
            await MainActor.run {
                state = .sending
            }
            do {
                try await send(signedTransaction: signedTransaction, fee: fee)
            } catch {
                Logger.web3.error(category: "SolanaTransfer(Gasless)", message: "Failed to send: \(error)")
                await MainActor.run {
                    self.state = .sendingFailed(error)
                }
            }
        } else {
            guard let context = await nativeTransferContext else {
                assertionFailure("This shouldn't happen. Check when `state` becomes `ready`")
                return
            }
            await MainActor.run {
                state = .signing
            }
            let transaction = try Solana.Transaction(
                from: payment.fromAddress.destination,
                to: payment.toAddress,
                createAssociatedTokenAccountForReceiver: context.createAssociatedTokenAccountForReceiver,
                tokenProgramID: context.tokenProgramID,
                mint: payment.token.assetKey,
                amount: amount,
                decimals: UInt8(payment.token.precision),
                priorityFee: context.priorityFee,
                token: payment.token
            )
            let signedTransaction: String
            do {
                signedTransaction = try await sign(transaction: transaction, with: pin)
            } catch {
                Logger.web3.error(category: "SolanaTransfer", message: "Failed to sign: \(error)")
                await MainActor.run {
                    self.state = .signingFailed(error)
                }
                return
            }
            let fee = await MainActor.run {
                self.state = .sending
                return self.fee?.selected
            }
            do {
                try await send(signedTransaction: signedTransaction, fee: fee)
            } catch {
                Logger.web3.error(category: "SolanaTransfer", message: "Failed to send: \(error)")
                await MainActor.run {
                    self.state = .sendingFailed(error)
                }
            }
        }
    }
    
    override func respond(signature: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
    @MainActor func load(
        fee: Fee,
        receiverAccountStatus: ReceiverAccountStatus,
        nativeTransferContext: NativeTransferContext?
    ) {
        self.receiverAccountStatus = receiverAccountStatus
        self.nativeTransferContext = nativeTransferContext
        self.fee = fee
        self.state = .ready
    }
    
    private func reloadNativeFee() async throws -> Fee {
        let tokenProgramID = try await RouteAPI.solanaGetAccountInfo(pubkey: payment.token.assetKey).owner
        let receiverAccountExists: Bool
        let createAssociatedTokenAccountForReceiver: Bool
        if payment.sendingNativeToken {
            receiverAccountExists = try await RouteAPI.solanaAccountExists(pubkey: payment.toAddress)
            createAssociatedTokenAccountForReceiver = false
        } else {
            let ata = try Solana.tokenAssociatedAccount(
                walletAddress: payment.toAddress,
                mint: payment.token.assetKey,
                tokenProgramID: tokenProgramID
            )
            receiverAccountExists = try await RouteAPI.solanaAccountExists(pubkey: ata)
            createAssociatedTokenAccountForReceiver = !receiverAccountExists
        }
        let transaction = try Solana.Transaction(
            from: payment.fromAddress.destination,
            to: payment.toAddress,
            createAssociatedTokenAccountForReceiver: createAssociatedTokenAccountForReceiver,
            tokenProgramID: tokenProgramID,
            mint: payment.token.assetKey,
            amount: amount,
            decimals: UInt8(payment.token.precision),
            priorityFee: nil,
            token: payment.token
        )
        
        let baseFee = try baseFee(for: transaction)
        let priorityFee = try await RouteAPI.solanaPriorityFee(base64Transaction: transaction.rawTransaction)
        let fee = Fee.native(
            token: nativeFeeToken,
            amount: baseFee.amount + priorityFee.decimalCount
        )
        let nativeTransferContext = NativeTransferContext(
            createAssociatedTokenAccountForReceiver: createAssociatedTokenAccountForReceiver,
            tokenProgramID: tokenProgramID,
            priorityFee: priorityFee
        )
        
        await MainActor.run {
            self.receiverAccountStatus = receiverAccountExists ? .exist : .notExist
            self.nativeTransferContext = nativeTransferContext
            self.fee = fee
            self.state = .ready
        }
        return fee
    }
    
}
