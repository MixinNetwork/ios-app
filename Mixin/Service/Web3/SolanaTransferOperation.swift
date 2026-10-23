import Foundation
import WalletConnectSign
import MixinServices

class SolanaTransferOperation: Web3TransferOperation {
    
    enum InitError: Error {
        case noFeeToken(String)
        case invalidAmount(Decimal)
        case buildTransaction
        case mismatchedFromAddress
    }
    
    enum BroadcastError: LocalizedError {
        
        case notFullySigned
        
        var errorDescription: String? {
            switch self {
            case .notFullySigned:
                "Cannot broadcast a partial signed tx"
            }
        }
        
    }
    
    fileprivate let lamportsPerSignature: UInt64 = 5000
    
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
    
    fileprivate func respond(signature: String, transactionHash: String?) async throws {
        assertionFailure("Must override")
    }
    
    fileprivate func baseFee(for transaction: Solana.Transaction) throws -> Web3DisplayFee {
        let amount = try transaction.fee(lamportsPerSignature: lamportsPerSignature)
        let fee = Web3DisplayFee(token: nativeFeeToken, amount: amount, gasless: false)
        return fee
    }
    
    fileprivate func sign(
        transaction: Solana.Transaction,
        with pin: String,
    ) async throws -> Solana.SignedTransaction {
        Logger.web3.info(category: "SolanaTransfer", message: "Start")
        let privateKey = try await wallet.solanaPrivateKey(pin: pin, address: fromAddress)
        let blockhash: Data?
        if transaction.requiresRecentBlockhash {
            let recentBlockhash = try await RouteAPI.solanaLatestBlockhash()
            guard let data = Data(base58EncodedString: recentBlockhash) else {
                throw SigningError.invalidBlockhash
            }
            blockhash = data
        } else {
            blockhash = nil
        }
        Logger.web3.info(category: "SolanaTransfer", message: "Will sign")
        return try transaction.sign(
            withPrivateKeyFrom: privateKey,
            recentBlockhash: blockhash
        )
    }
    
    fileprivate func send(
        signedTransaction: Solana.SignedTransaction,
        fee: Web3DisplayFee?,
    ) async throws {
        Logger.web3.info(category: "SolanaTransfer", message: "Will send tx")
        let rawTransaction = try await RouteAPI.postTransaction(
            chainID: ChainID.solana,
            from: fromAddress.destination,
            rawTransaction: signedTransaction.rawTransaction,
            feeType: isFeeWaived ? .free : nil,
        )
        let pendingTransaction = Web3Transaction(
            rawTransaction: rawTransaction,
            fee: fee,
            myAddress: fromAddress.destination
        )
        Web3TransactionDAO.shared.save(transactions: [pendingTransaction]) { db in
            try rawTransaction.save(db)
        }
        let hash = rawTransaction.hash
        // The signing account's signature can differ from the broadcast transaction's ID.
        try await respond(signature: signedTransaction.signature, transactionHash: hash)
        Logger.web3.info(category: "SolanaTransfer", message: "Txn sent, hash: \(hash)")
        await MainActor.run {
            self.updateState(.success)
        }
    }
    
}

class ArbitraryTransactionSolanaTransferOperation: SolanaTransferOperation {
    
    fileprivate let transaction: Solana.Transaction
    
    private let broadcastsTransaction: Bool
    
    @MainActor init(
        wallet: Web3Wallet,
        transaction: Solana.Transaction,
        fromAddress: Web3Address,
        toAddress: String,
        chain: Web3Chain,
        broadcastsTransaction: Bool,
    ) throws {
        guard transaction.requiresSigner(address: fromAddress.destination) else {
            throw InitError.mismatchedFromAddress
        }
        self.transaction = transaction
        self.broadcastsTransaction = broadcastsTransaction
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: toAddress,
            chain: chain,
            simulationDisplay: .byRemote,
            isFeeWaived: false
        )
        self.updateState(.ready)
    }
    
    override func reloadFee() async throws -> Fee {
        let amount: Decimal
        if fromAddress.destination == transaction.feePayer {
            amount = try transaction.fee(lamportsPerSignature: lamportsPerSignature) + transaction.priorityFee()
        } else {
            amount = 0
        }
        let fee = Web3DisplayFee(token: nativeFeeToken, amount: amount, gasless: false)
        return Fee(options: [fee], selectedIndex: 0)
    }
    
    override func simulateTransaction() async throws -> TransactionSimulation {
        try await RouteAPI.simulateSolanaTransaction(
            from: fromAddress.destination,
            rawTransaction: transaction.rawTransaction
        )
    }
    
    override func start(pin: String) async throws {
        await MainActor.run {
            updateState(.signing)
        }
        let signedTransaction: Solana.SignedTransaction
        do {
            signedTransaction = try await sign(transaction: transaction, with: pin)
        } catch {
            Logger.web3.error(category: "SolanaTransfer", message: "Failed to sign: \(error)")
            await MainActor.run {
                self.updateState(.signingFailed(error))
            }
            throw error
        }
        if broadcastsTransaction {
            if signedTransaction.isFullySigned {
                let fee = await MainActor.run {
                    self.updateState(.sending)
                    return self.fee?.selected
                }
                do {
                    try await send(signedTransaction: signedTransaction, fee: fee)
                } catch {
                    Logger.web3.error(category: "SolanaTransfer", message: "Failed to send: \(error)")
                    await MainActor.run {
                        self.updateState(.sendingFailed(error))
                    }
                    throw error
                }
            } else {
                let error: BroadcastError = .notFullySigned
                Logger.web3.error(category: "SolanaTransfer", message: "Trying to broadcast a partial signed tx")
                await MainActor.run {
                    self.updateState(.sendingFailed(error))
                }
                throw error
            }
        } else {
            do {
                // Return partial signatures so the proposer can collect the remaining signers.
                try await respond(signature: signedTransaction.signature, transactionHash: nil)
                await MainActor.run {
                    self.updateState(.success)
                }
            } catch {
                Logger.web3.error(category: "SolanaTransfer", message: "Failed to respond: \(error)")
                await MainActor.run {
                    self.updateState(.sendingFailed(error))
                }
                throw error
            }
        }
    }
    
    override func respond(signature: String, transactionHash: String?) async throws {
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
            chain: chain,
            broadcastsTransaction: false,
        )
    }
    
    override func respond(signature: String, transactionHash: String?) async throws {
        let response = RPCResult.response(AnyCodable(["signature": signature]))
        try await Sign.instance.respond(
            topic: request.topic,
            requestId: request.id,
            response: response
        )
    }
    
    override func reject() {
        Task {
            let error = JSONRPCError(code: 0, message: "User rejected")
            try await Sign.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: .error(error)
            )
        }
    }
    
}

final class SolanaTransferWithCustomRespondingOperation: ArbitraryTransactionSolanaTransferOperation {
    
    private let respondImpl: ((_ signerSignature: String, _ transactionHash: String?) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    @MainActor init(
        wallet: Web3Wallet,
        transaction: Solana.Transaction,
        fromAddress: Web3Address,
        chain: Web3Chain,
        broadcastsTransaction: Bool,
        respondWith respondImpl: ((_ signerSignature: String, _ transactionHash: String?) async throws -> Void)?,
        rejectWith rejectImpl: (() -> Void)?
    ) throws {
        self.respondImpl = respondImpl
        self.rejectImpl = rejectImpl
        try super.init(
            wallet: wallet,
            transaction: transaction,
            fromAddress: fromAddress,
            toAddress: "",
            chain: chain,
            broadcastsTransaction: broadcastsTransaction,
        )
    }
    
    override func respond(signature: String, transactionHash: String?) async throws {
        try await respondImpl?(signature, transactionHash)
    }
    
    override func reject() {
        rejectImpl?()
    }
    
}

final class SolanaTransferToAddressOperation: SolanaTransferOperation {
    
    struct NativeTransferContext {
        let createAssociatedTokenAccountForReceiver: Bool
        let tokenProgramID: String
        let priorityFee: PriorityFee
    }
    
    @MainActor
    private(set) var receiverAccountExists: Bool?
    
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
        let simulation: TransactionSimulation = .byLocal(
            token: payment.token,
            amount: -decimalAmount,
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
                let receiverAccountExists: Bool
                if payment.sendingNativeToken {
                    receiverAccountExists = try await RouteAPI.solanaAccountExists(
                        pubkey: payment.toAddress
                    )
                } else {
                    let tokenProgramID = try await RouteAPI
                        .solanaGetAccountInfo(pubkey: payment.token.assetKey)
                        .owner
                    let ata = try Solana.tokenAssociatedAccount(
                        walletAddress: payment.toAddress,
                        mint: payment.token.assetKey,
                        tokenProgramID: tokenProgramID
                    )
                    receiverAccountExists = try await RouteAPI.solanaAccountExists(pubkey: ata)
                }
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
                    self.receiverAccountExists = receiverAccountExists
                    self.nativeTransferContext = nil
                    self.fee = fee
                    self.updateState(.ready)
                }
                return fee
            } catch {
                Logger.web3.error(category: "SolanaTransfer", message: "Gasless unavailable: \(error)")
                return try await reloadNativeFee()
            }
        case .prefersGaslessTrade:
            do {
                let receiverAccountExists: Bool
                if payment.sendingNativeToken {
                    receiverAccountExists = try await RouteAPI.solanaAccountExists(
                        pubkey: payment.toAddress
                    )
                } else {
                    let tokenProgramID = try await RouteAPI
                        .solanaGetAccountInfo(pubkey: payment.token.assetKey)
                        .owner
                    let ata = try Solana.tokenAssociatedAccount(
                        walletAddress: payment.toAddress,
                        mint: payment.token.assetKey,
                        tokenProgramID: tokenProgramID
                    )
                    receiverAccountExists = try await RouteAPI.solanaAccountExists(pubkey: ata)
                }
                let amount = decimalAmount.formatted(
                    payment.token.canonicalFormatStyle
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
                    self.receiverAccountExists = receiverAccountExists
                    self.nativeTransferContext = nil
                    self.fee = fee
                    self.updateState(.ready)
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
                updateState(.signing)
            }
            let chainID = payment.token.chainID
            let signedTransaction: Solana.SignedTransaction
            do {
                let proposal: GaslessTransactionProposal
                if let fee = fee as? Web3GaslessTradingFee {
                    proposal = fee.proposal
                } else {
                    let amount = decimalAmount.formatted(
                        payment.token.canonicalFormatStyle
                    )
                    let feeAmount = fee.amount.formatted(
                        fee.token.canonicalFormatStyle
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
                    updateState(.signingFailed(error))
                }
                throw error
            }
            await MainActor.run {
                updateState(.sending)
            }
            do {
                try await send(signedTransaction: signedTransaction, fee: fee)
            } catch {
                Logger.web3.error(category: "SolanaTransfer(Gasless)", message: "Failed to send: \(error)")
                await MainActor.run {
                    self.updateState(.sendingFailed(error))
                }
                throw error
            }
        } else {
            guard let context = await nativeTransferContext else {
                assertionFailure("This shouldn't happen. Check when `state` becomes `ready`")
                return
            }
            await MainActor.run {
                updateState(.signing)
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
            let signedTransaction: Solana.SignedTransaction
            do {
                signedTransaction = try await sign(transaction: transaction, with: pin)
            } catch {
                Logger.web3.error(category: "SolanaTransfer", message: "Failed to sign: \(error)")
                await MainActor.run {
                    self.updateState(.signingFailed(error))
                }
                throw error
            }
            let fee = await MainActor.run {
                self.updateState(.sending)
                return self.fee?.selected
            }
            do {
                try await send(signedTransaction: signedTransaction, fee: fee)
            } catch {
                Logger.web3.error(category: "SolanaTransfer", message: "Failed to send: \(error)")
                await MainActor.run {
                    self.updateState(.sendingFailed(error))
                }
                throw error
            }
        }
    }
    
    override func respond(signature: String, transactionHash: String?) async throws {
        
    }
    
    override func reject() {
        
    }
    
    @MainActor func load(
        fee: Fee,
        receiverAccountExists: Bool?,
        nativeTransferContext: NativeTransferContext?
    ) {
        self.receiverAccountExists = receiverAccountExists
        self.nativeTransferContext = nativeTransferContext
        self.fee = fee
        self.updateState(.ready)
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
            self.receiverAccountExists = receiverAccountExists
            self.nativeTransferContext = nativeTransferContext
            self.fee = fee
            self.updateState(.ready)
        }
        return fee
    }
    
}
