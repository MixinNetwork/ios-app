import Foundation
import WalletConnectSign
import MixinServices

class EVMTransferOperation: Web3TransferOperation {
    
    final class EVMDisplayFee: Web3DisplayFee {
        
        let feePerGas: Decimal // In Gwei
        
        init(
            token: Web3TokenItem,
            amount: Decimal,
            feePerGas: Decimal,
            gasless: Bool,
        ) {
            self.feePerGas = feePerGas
            super.init(token: token, amount: amount, gasless: gasless)
        }
        
    }
    
    enum InitError: Error {
        case noFeeToken(String)
        case invalidAmount(Decimal)
        case invalidReceiver(String)
        case notEVMChain(String)
        case mismatchedFromAddress
    }
    
    fileprivate enum RequestError: Error {
        case mismatchedAddress
        case invalidFee
        case missingChainID
        case invalidTransactionCount
    }
    
    private struct EVMFee {
        let gasLimit: UInt64
        let maxFeePerGas: EVMQuantity
        let maxPriorityFeePerGas: EVMQuantity
    }
    
    @MainActor
    override var isResendingTransactionAvailable: Bool {
        signedTransaction != nil
    }
    
    @MainActor fileprivate var signedTransaction: (raw: Data, fee: Web3DisplayFee)?
    
    private let mixinChainID: String
    
    private lazy var gweiRoundingHandler = NSDecimalNumberHandler(
        roundingMode: .up,
        scale: 2,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    
    @MainActor private var evmFee: EVMFee?
    @MainActor private var transaction: EVM.Transaction
    @MainActor private var broadcastTransactionHash: String?
    
    fileprivate init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        toAddress: String,
        transaction: EVM.Transaction,
        chain: Web3Chain,
        simulationDisplay: SimulationDisplay,
        isFeeWaived: Bool,
    ) throws {
        switch chain.specification {
        case .evm:
            break
        default:
            throw InitError.notEVMChain(chain.name)
        }
        
        guard let feeToken = try chain.feeToken(walletID: wallet.walletID) else {
            throw InitError.noFeeToken(chain.feeTokenAssetID)
        }
        self.transaction = transaction
        self.mixinChainID = chain.chainID
        
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
    
    fileprivate init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        transaction: ExternalEVMTransaction,
        chain: Web3Chain,
        simulationDisplay: SimulationDisplay,
        isFeeWaived: Bool,
    ) throws {
        guard transaction.from == (try EVM.Address(fromAddress.destination)) else {
            throw InitError.mismatchedFromAddress
        }
        let chainID: Int
        switch chain.specification {
        case let .evm(id):
            chainID = id
        default:
            throw InitError.notEVMChain(chain.name)
        }
        guard let feeToken = try chain.feeToken(walletID: wallet.walletID) else {
            throw InitError.noFeeToken(chain.feeTokenAssetID)
        }
        
        self.transaction = try EVM.Transaction(
            chainID: chainID,
            nonce: 0,
            maxPriorityFeePerGas: 0,
            maxFeePerGas: 0,
            gasLimit: 0,
            destination: transaction.to,
            amount: transaction.value ?? 0,
            data: transaction.data ?? Data(),
        )
        self.mixinChainID = chain.chainID
        
        super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: transaction.to?.checksumString,
            chain: chain,
            feeToken: feeToken,
            simulationDisplay: simulationDisplay,
            isFeeWaived: isFeeWaived,
        )
    }
    
    override func reloadFee() async throws -> Fee {
        let parameters = try await transaction.feeEstimationParameters()
        let rawFee = try await RouteAPI.estimatedEthereumFee(
            mixinChainID: mixinChainID,
            from: fromAddress.destination,
            to: parameters.to,
            value: parameters.value,
            data: parameters.data,
        )
        Logger.web3.info(category: "EVMTransfer", message: "Using limit: \(rawFee.gasLimit), mfpg: \(rawFee.maxFeePerGas), mpfpg: \(rawFee.maxPriorityFeePerGas)")
        guard
            let gasLimit = UInt64(rawFee.gasLimit),
            let maxFeePerGas = EVMQuantity(rawFee.maxFeePerGas),
            let maxFeePerGasNumber = Decimal(string: try maxFeePerGas.decimalString(), locale: .enUSPOSIX),
            let maxPriorityFeePerGas = EVMQuantity(rawFee.maxPriorityFeePerGas),
            let weiCount = Decimal(
                string: try EVMQuantity(gasLimit).multiplied(by: maxFeePerGas).decimalString(),
                locale: .enUSPOSIX,
            )
        else {
            throw RequestError.invalidFee
        }
        let evmFee: EVMFee
        let feePerGas: Decimal
        let tokenAmount: Decimal
        if await Web3Diagnostic.usesLowEVMFeeOnce {
            evmFee = EVMFee(
                gasLimit: gasLimit / 3,
                maxFeePerGas: try maxFeePerGas.divided(by: 3),
                maxPriorityFeePerGas: try maxPriorityFeePerGas.divided(by: 3)
            )
            feePerGas = maxFeePerGasNumber * .gwei / 3
            tokenAmount = weiCount * .wei / 3
        } else {
            evmFee = EVMFee(
                gasLimit: gasLimit,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas
            )
            feePerGas = maxFeePerGasNumber * .gwei
            tokenAmount = weiCount * .wei
        }
        let nativeFee = EVMDisplayFee(
            token: nativeFeeToken,
            amount: tokenAmount,
            feePerGas: NSDecimalNumber(decimal: feePerGas)
                .rounding(accordingToBehavior: gweiRoundingHandler)
                .decimalValue,
            gasless: false,
        )
        let fee = Fee(options: [nativeFee], selectedIndex: 0)
        await MainActor.run {
            self.evmFee = evmFee
            self.fee = fee
            self.updateState(.ready)
        }
        return fee
    }
    
    override func simulateTransaction() async throws -> TransactionSimulation {
        guard let evmFee = await evmFee else {
            throw RequestError.invalidFee
        }
        let nonce = try await self.loadNonce()
        let pseudoTransaction = try await transaction.updating(
            nonce: nonce,
            maxPriorityFeePerGas: evmFee.maxPriorityFeePerGas,
            maxFeePerGas: evmFee.maxFeePerGas,
            gasLimit: evmFee.gasLimit,
        )
        let rawTransaction = try pseudoTransaction.encoded().hexEncodedString()
        return try await RouteAPI.simulateEthereumTransaction(
            chainID: mixinChainID,
            from: fromAddress.destination,
            rawTransaction: "0x" + rawTransaction
        )
    }
    
    override func start(pin: String) async throws {
        guard let evmFee = await evmFee, let fee = await fee?.selected else {
            assertionFailure("Missing fee, call `start(with:)` only after fee is ready")
            return
        }
        assert(!fee.gasless)
        await MainActor.run {
            signedTransaction = nil
            broadcastTransactionHash = nil
            updateState(.signing)
        }
        Logger.web3.info(category: "EVMTransfer", message: "Will sign")
        let updatedTransaction: EVM.Transaction
        let raw: Data
        do {
            let nonce = try await self.loadNonce()
            updatedTransaction = try await transaction.updating(
                nonce: nonce,
                maxPriorityFeePerGas: evmFee.maxPriorityFeePerGas,
                maxFeePerGas: evmFee.maxFeePerGas,
                gasLimit: evmFee.gasLimit,
            )
            let privateKey = try await wallet.evmPrivateKey(pin: pin, address: fromAddress)
            guard try EVM.address(privateKey: privateKey) == EVM.Address(fromAddress.destination) else {
                throw RequestError.mismatchedAddress
            }
            raw = try updatedTransaction.sign(privateKey: privateKey)
        } catch {
            Logger.web3.error(category: "EVMTransfer", message: "Failed to sign: \(error)")
            await MainActor.run {
                self.updateState(.signingFailed(error))
            }
            throw error
        }
        
        Logger.web3.info(category: "EVMTransfer", message: "Will send")
        await MainActor.run {
            self.transaction = updatedTransaction
            self.signedTransaction = (raw: raw, fee: fee)
            self.updateState(.sending)
        }
        try await self.send(signedTransaction: raw, fee: fee)
    }
    
    override func resendTransaction() {
        guard let signedTransaction else {
            return
        }
        updateState(.sending)
        Logger.web3.info(category: "EVMTransfer", message: "Will resend")
        Task.detached {
            try? await self.send(signedTransaction: signedTransaction.raw, fee: signedTransaction.fee)
        }
    }
    
    fileprivate func respond(hash: String) async throws {
        assertionFailure("Must override")
    }
    
    fileprivate func loadNonce() async throws -> Int {
        let latestTransactionCount = try await {
            let count = try await RouteAPI.ethereumLatestTransactionCount(
                chainID: mixinChainID,
                address: fromAddress.destination
            )
            if let count = Int(count, radix: 16) {
                return count
            } else {
                throw RequestError.invalidTransactionCount
            }
        }()
        
        let nonce: Int
        let maxNonce = Web3RawTransactionDAO.shared.maxNonce(
            walletID: wallet.walletID,
            chainID: mixinChainID
        )
        if let maxNonce, let n = Int(maxNonce, radix: 10), n >= latestTransactionCount {
            nonce = n + 1
            Logger.general.debug(category: "EVMTransfer", message: "Using local value \(nonce) as nonce")
        } else {
            nonce = latestTransactionCount
            Logger.general.debug(category: "EVMTransfer", message: "Using remote value \(nonce) as nonce")
        }
        
        return nonce
    }
    
    private func send(
        signedTransaction: Data,
        fee: Web3DisplayFee,
    ) async throws {
        do {
            let hash: String
            if let broadcastTransactionHash = await broadcastTransactionHash {
                hash = broadcastTransactionHash
            } else {
                Logger.web3.info(category: "EVMTransfer", message: "Will send tx")
                let rawTransaction = try await RouteAPI.postTransaction(
                    chainID: mixinChainID,
                    from: fromAddress.destination,
                    rawTransaction: "0x" + signedTransaction.hexEncodedString(),
                    feeType: isFeeWaived ? .free : nil,
                )
                let pendingTransaction = Web3Transaction(
                    rawTransaction: rawTransaction,
                    fee: fee,
                    myAddress: fromAddress.destination,
                )
                Web3TransactionDAO.shared.save(transactions: [pendingTransaction]) { db in
                    try rawTransaction.save(db)
                }
                hash = rawTransaction.hash
                await MainActor.run {
                    self.broadcastTransactionHash = hash
                }
            }
            Logger.web3.info(category: "EVMTransfer", message: "Will respond hash: \(hash)")
            try await respond(hash: hash)
            Logger.web3.info(category: "EVMTransfer", message: "Txn sent")
            await MainActor.run {
                self.signedTransaction = nil
                self.updateState(.success)
                Web3Diagnostic.usesLowEVMFeeOnce = false
            }
        } catch {
            Logger.web3.error(category: "EVMTransfer", message: "Send: \(error)")
            await MainActor.run {
                self.updateState(.sendingFailed(error))
            }
            throw error
        }
    }
    
}

// MARK: - External transactions
final class Web3TransferWithWalletConnectOperation: EVMTransferOperation {
    
    let session: WalletConnectSession
    let request: WalletConnectSign.Request
    
    init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        transaction: ExternalEVMTransaction,
        chain: Web3Chain,
        session: WalletConnectSession,
        request: WalletConnectSign.Request
    ) throws {
        self.session = session
        self.request = request
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            transaction: transaction,
            chain: chain,
            simulationDisplay: .byRemote,
            isFeeWaived: false,
        )
    }
    
    override func respond(hash: String) async throws {
        let response = RPCResult.response(AnyCodable(hash))
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

final class EVMTransferWithBrowserWalletOperation: EVMTransferOperation {
    
    private let respondImpl: ((String) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        transaction: ExternalEVMTransaction,
        chain: Web3Chain,
        respondWith respondImpl: @escaping ((String) async throws -> Void),
        rejectWith rejectImpl: @escaping (() -> Void)
    ) throws {
        self.respondImpl = respondImpl
        self.rejectImpl = rejectImpl
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            transaction: transaction,
            chain: chain,
            simulationDisplay: .byRemote,
            isFeeWaived: false,
        )
    }
    
    override func respond(hash: String) async throws {
        try await respondImpl?(hash)
    }
    
    override func reject() {
        rejectImpl?()
    }
    
}

// MARK: - User Initiated Transactions
final class EVMTransferToAddressOperation: EVMTransferOperation {
    
    enum GaslessValidationError: LocalizedError {
        
        case invalidTransaction
        
        var errorDescription: String? {
            R.string.localizable.invalid_gasless_transaction()
        }
        
    }
    
    private let payment: Web3SendingTokenToAddressPayment
    private let decimalAmount: Decimal
    private let simulation: TransactionSimulation
    private let feePolicy: FeePolicy
    
    init(
        evmChainID: Int,
        payment: Web3SendingTokenToAddressPayment,
        decimalAmount: Decimal,
        feePolicy: FeePolicy,
    ) throws {
        guard let amount = payment.token.nativeAmount(decimalAmount: decimalAmount) else {
            throw InitError.invalidAmount(decimalAmount)
        }
        // No need to worry about the fractional part, the amount is guranteed to be integral
        let amountString = TokenAmountFormatter.string(from: amount as Decimal)
        let transaction: EVM.Transaction
        if payment.sendingNativeToken {
            guard let value = EVMQuantity(amountString) else {
                throw InitError.invalidAmount(decimalAmount)
            }
            transaction = try EVM.Transaction(
                chainID: evmChainID,
                nonce: 0,
                maxPriorityFeePerGas: 0,
                maxFeePerGas: 0,
                gasLimit: 0,
                destination: try EVM.Address(payment.toAddress),
                amount: value,
                data: Data(),
            )
        } else {
            guard let receiver = try? EVM.Address(payment.toAddress) else {
                throw InitError.invalidReceiver(payment.toAddress)
            }
            let receiverData = receiver.data
            guard let amountData = EVMQuantity(amountString)?.bigEndian else {
                throw InitError.invalidAmount(decimalAmount)
            }
            let data = Data([0xa9, 0x05, 0x9c, 0xbb])
            + Data(repeating: 0, count: 32 - receiverData.count)
            + receiverData
            + Data(repeating: 0, count: 32 - amountData.count)
            + amountData
            transaction = try EVM.Transaction(
                chainID: evmChainID,
                nonce: 0,
                maxPriorityFeePerGas: 0,
                maxFeePerGas: 0,
                gasLimit: 0,
                destination: try EVM.Address(payment.token.assetKey),
                amount: 0,
                data: data,
            )
        }
        let simulation: TransactionSimulation = .byLocal(
            token: payment.token,
            amount: -decimalAmount,
            from: payment.fromAddress.destination,
        )
        let isFeeWaived = payment.toAddressLabel?.isFeeWaived() ?? false
        
        self.payment = payment
        self.decimalAmount = decimalAmount
        self.simulation = simulation
        self.feePolicy = feePolicy
        try super.init(
            wallet: payment.wallet,
            fromAddress: payment.fromAddress,
            toAddress: payment.toAddress,
            transaction: transaction,
            chain: payment.chain,
            simulationDisplay: .byLocal(simulation),
            isFeeWaived: isFeeWaived,
        )
    }
    
    override func reloadFee() async throws -> Web3TransferOperation.Fee {
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
                    self.fee = fee
                    self.updateState(.ready)
                }
                return fee
            } catch {
                Logger.web3.error(category: "EVMTransfer", message: "Gasless unavailable: \(error)")
                return try await super.reloadFee()
            }
        case .prefersGaslessTrade:
            do {
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
                    self.fee = fee
                    self.updateState(.ready)
                }
                return fee
            } catch {
                Logger.web3.error(category: "EVMTransfer", message: "Gasless unavailable: \(error)")
                return try await super.reloadFee()
            }
        case .alwaysNative:
            return try await super.reloadFee()
        }
    }
    
    override func start(pin: String) async throws {
        guard let fee = await fee?.selected else {
            assertionFailure("Missing fee, call `start(with:)` only after fee is ready")
            return
        }
        guard fee.gasless else {
            try await super.start(pin: pin)
            return
        }
        Logger.web3.info(category: "EVMTransfer(Gasless)", message: "Start")
        let chainID = payment.chain.chainID
        await MainActor.run {
            self.signedTransaction = nil
            updateState(.signing)
        }
        let signedTransaction: SignedEVMGaslessTransactionProposal
        let nonce: String
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
                    from: fromAddress.destination,
                    to: payment.toAddress,
                    assetID: payment.token.assetID,
                    amount: amount,
                    feeAssetID: fee.token.assetID,
                    feeAmount: feeAmount,
                    chainID: chainID
                )
            }
            guard proposal.chainID == chainID else {
                throw SigningError.gaslessChainMismatch
            }
            guard case let .evm(payload) = proposal.payload else {
                throw SigningError.gaslessPayloadMismatch
            }
            let privateKey = try await wallet.evmPrivateKey(pin: pin, address: fromAddress)
            guard try EVM.address(privateKey: privateKey) == EVM.Address(fromAddress.destination) else {
                throw RequestError.mismatchedAddress
            }
            Logger.web3.info(category: "EVMTransfer(Gasless)", message: "Will sign")
            let digests: (userOperation: Data, authorization: Data?)
            do {
                guard case let .evm(evmChainID) = payment.chain.specification,
                      payment.token.chainID == chainID,
                      fee.token.chainID == chainID else {
                    throw EVM.Error.invalidTransaction
                }
                let feeTokenAddress = try EVM.Address(fee.token.assetKey)
                let amount = try EVM.gaslessTransferAmount(
                    decimalAmount,
                    precision: payment.sendingNativeToken ? 18 : payment.token.precision,
                )
                let feeAmount = try EVM.gaslessTransferAmount(
                    fee.amount,
                    precision: feeTokenAddress.isZero ? 18 : fee.token.precision,
                )
                digests = try EVM.validateGaslessTransfer(
                    payload,
                    chainID: evmChainID,
                    sender: EVM.Address(fromAddress.destination),
                    recipient: EVM.Address(payment.toAddress),
                    token: payment.sendingNativeToken ? nil : EVM.Address(payment.token.assetKey),
                    amount: amount,
                    feeToken: feeTokenAddress.isZero ? nil : feeTokenAddress,
                    feeAmount: feeAmount,
                )
            } catch {
                throw GaslessValidationError.invalidTransaction
            }
            let signedUserOperation = try EVM.signHash(digests.userOperation, privateKey: privateKey)
            let signedAuth = try digests.authorization.map { digest in
                try EVM.signHash(digest, privateKey: privateKey)
            }
            signedTransaction = SignedEVMGaslessTransactionProposal(
                chainID: chainID,
                payload: payload,
                userOperationSignature: signedUserOperation,
                eip7702AuthSignature: signedAuth
            )
            nonce = payload.userOperation.nonce
        } catch {
            Logger.web3.error(category: "EVMTransfer(Gasless)", message: "Failed to sign: \(error)")
            await MainActor.run {
                self.updateState(.signingFailed(error))
            }
            throw error
        }
        do {
            Logger.web3.info(category: "EVMTransfer(Gasless)", message: "Will send tx")
            let sponsorTxID = try await RouteAPI.gaslessSubmit(transaction: signedTransaction)
            Logger.web3.info(category: "EVMTransfer(Gasless)", message: "Sponsor txid: \(sponsorTxID)")
            let now = Date().toUTCString()
            let rawTransaction: Web3RawTransaction = .gaslessSponsorTransaction(
                sponsorTxID: sponsorTxID,
                chainID: chainID,
                account: fromAddress.destination,
                nonce: nonce,
                state: .pending,
                createdAt: now,
                updatedAt: now
            )
            let pendingTransaction = Web3Transaction(
                rawTransaction: rawTransaction,
                simulation: simulation,
                fee: fee,
                myAddress: fromAddress.destination,
            )
            Web3TransactionDAO.shared.save(transactions: [pendingTransaction]) { db in
                try rawTransaction.save(db)
            }
            Logger.web3.info(category: "EVMTransfer(Gasless)", message: "Txn sent")
            await MainActor.run {
                self.updateState(.success)
            }
        } catch {
            Logger.web3.error(category: "EVMTransfer(Gasless)", message: "Send: \(error)")
            await MainActor.run {
                self.updateState(.sendingFailed(error))
            }
            throw error
        }
    }
    
    override func respond(hash: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
    @MainActor func load(fee: Fee) {
        guard fee.selected.gasless else {
            // Native tx requires `evmFee`
            return
        }
        self.fee = fee
        self.updateState(.ready)
    }
    
}

// MARK: - Override Transactions
class EVMOverrideOperation: EVMTransferOperation {
    
    private let nonce: Int
    
    init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        toAddress: String,
        transaction: EVM.Transaction,
        chain: Web3Chain,
        simulationDisplay: SimulationDisplay,
    ) throws {
        guard let nonce = Int(exactly: try transaction.nonce()) else {
            throw RequestError.invalidTransactionCount
        }
        self.nonce = nonce
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: toAddress,
            transaction: transaction,
            chain: chain,
            simulationDisplay: simulationDisplay,
            isFeeWaived: false,
        )
    }
    
    override func respond(hash: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
    override func loadNonce() async throws -> Int {
        nonce
    }
    
}

final class EVMSpeedUpOperation: EVMOverrideOperation {
    
    init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        transaction: EVM.Transaction,
        chain: Web3Chain,
    ) throws {
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: "",
            transaction: transaction,
            chain: chain,
            simulationDisplay: .byRemote
        )
    }
    
}

final class EVMCancelOperation: EVMOverrideOperation {
    
    init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        transaction: EVM.Transaction,
        chain: Web3Chain
    ) throws {
        let emptyTransaction = try transaction.cancelling(
            to: try EVM.Address(fromAddress.destination),
        )
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: "",
            transaction: emptyTransaction,
            chain: chain,
            simulationDisplay: .hidden
        )
    }
    
}
