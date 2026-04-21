import Foundation
import BigInt
import web3
import ReownWalletKit
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
    }
    
    fileprivate enum RequestError: Error {
        case invalidTransaction
        case mismatchedAddress
        case invalidFee
        case missingChainID
        case missingRawTx
        case invalidTransactionCount
    }
    
    private struct EVMFee {
        let gasLimit: BigUInt
        let maxFeePerGas: BigUInt
        let maxPriorityFeePerGas: BigUInt
    }
    
    @MainActor
    override var isResendingTransactionAvailable: Bool {
        evmFee != nil && account != nil
    }
    
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
    @MainActor private var transaction: EIP1559Transaction
    @MainActor private var account: EthereumAccount?
    
    fileprivate init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        toAddress: String,
        transaction: EIP1559Transaction,
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
        
        self.transaction = EIP1559Transaction(
            chainID: chainID,
            nonce: nil,
            maxPriorityFeePerGas: nil,
            maxFeePerGas: nil,
            gasLimit: nil,
            destination: transaction.to ?? EthereumAddress(""),
            amount: transaction.value ?? 0,
            data: transaction.data ?? Data()
        )
        self.mixinChainID = chain.chainID
        
        super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: transaction.to?.toChecksumAddress(),
            chain: chain,
            feeToken: feeToken,
            simulationDisplay: simulationDisplay,
            isFeeWaived: isFeeWaived,
        )
    }
    
    override func reloadFee() async throws -> Fee {
        let rawFee = try await RouteAPI.estimatedEthereumFee(
            mixinChainID: mixinChainID,
            from: fromAddress.destination,
            to: transaction.destination.toChecksumAddress(),
            value: "0x" + String(transaction.amount, radix: 16),
            data: transaction.data.isEmpty ? "" : "0x" + transaction.data.hexEncodedString(),
        )
        Logger.web3.info(category: "EVMTransfer", message: "Using limit: \(rawFee.gasLimit), mfpg: \(rawFee.maxFeePerGas), mpfpg: \(rawFee.maxPriorityFeePerGas)")
        guard
            let gasLimit = BigUInt(rawFee.gasLimit),
            let maxFeePerGas = BigUInt(rawFee.maxFeePerGas),
            let maxFeePerGasNumber = Decimal(string: maxFeePerGas.description, locale: .enUSPOSIX),
            let maxPriorityFeePerGas = BigUInt(rawFee.maxPriorityFeePerGas),
            let weiCount = Decimal(string: (gasLimit * maxFeePerGas).description, locale: .enUSPOSIX)
        else {
            throw RequestError.invalidFee
        }
        let evmFee: EVMFee
        let feePerGas: Decimal
        let tokenAmount: Decimal
        if await Web3Diagnostic.usesLowEVMFeeOnce {
            evmFee = EVMFee(
                gasLimit: gasLimit / 3,
                maxFeePerGas: maxFeePerGas / 3,
                maxPriorityFeePerGas: maxPriorityFeePerGas / 3
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
            self.state = .ready
        }
        return fee
    }
    
    override func simulateTransaction() async throws -> TransactionSimulation {
        guard let evmFee = await evmFee else {
            throw RequestError.invalidFee
        }
        let nonce = try await self.loadNonce()
        let pseudoTransaction = await EIP1559Transaction(
            chainID: transaction.chainID,
            nonce: nonce,
            maxPriorityFeePerGas: evmFee.maxPriorityFeePerGas,
            maxFeePerGas: evmFee.maxFeePerGas,
            gasLimit: evmFee.gasLimit,
            destination: transaction.destination,
            amount: transaction.amount,
            data: transaction.data
        )
        guard let rawTransaction = pseudoTransaction.raw?.hexEncodedString() else {
            throw RequestError.invalidTransaction
        }
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
            state = .signing
        }
        Logger.web3.info(category: "EVMTransfer", message: "Will sign")
        let account: EthereumAccount
        let updatedTransaction: EIP1559Transaction
        do {
            account = try await wallet.ethereumAccount(pin: pin, address: fromAddress)
            guard fromAddress.destination == account.address.toChecksumAddress() else {
                throw RequestError.mismatchedAddress
            }
            let nonce = try await self.loadNonce()
            updatedTransaction = await EIP1559Transaction(
                chainID: transaction.chainID,
                nonce: nonce,
                maxPriorityFeePerGas: evmFee.maxPriorityFeePerGas,
                maxFeePerGas: evmFee.maxFeePerGas,
                gasLimit: evmFee.gasLimit,
                destination: transaction.destination,
                amount: transaction.amount,
                data: transaction.data
            )
        } catch {
            Logger.web3.error(category: "EVMTransfer", message: "Failed to sign: \(error)")
            await MainActor.run {
                self.state = .signingFailed(error)
            }
            throw error
        }
        
        Logger.web3.info(category: "EVMTransfer", message: "Will send")
        await MainActor.run {
            self.transaction = updatedTransaction
            self.account = account
            self.state = .sending
        }
        try await self.send(transaction: updatedTransaction, with: account, fee: fee)
    }
    
    override func resendTransaction() {
        guard let fee, let account else {
            return
        }
        assert(!fee.selected.gasless)
        state = .sending
        Logger.web3.info(category: "EVMTransfer", message: "Will resend")
        Task.detached { [transaction] in
            Logger.web3.info(category: "EVMTransfer", message: "Will resend")
            try? await self.send(transaction: transaction, with: account, fee: fee.selected)
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
        transaction: EIP1559Transaction,
        with account: EthereumAccount,
        fee: Web3DisplayFee
    ) async throws {
        do {
            let transactionDescription = transaction.raw?.hexEncodedString()
                ?? transaction.jsonRepresentation
                ?? "(null)"
            Logger.web3.info(category: "EVMTransfer", message: "Will send tx: \(transactionDescription)")
            let hexEncodedSignedTransaction = try {
                let signedTx = try account.sign(transaction: transaction)
                guard let raw = signedTx.raw else {
                    throw RequestError.missingRawTx
                }
                return "0x" + raw.hexEncodedString()
            }()
            let rawTransaction = try await RouteAPI.postTransaction(
                chainID: mixinChainID,
                from: fromAddress.destination,
                rawTransaction: hexEncodedSignedTransaction,
                feeType: isFeeWaived ? .free : nil,
            )
            let pendingTransaction = Web3Transaction(
                rawTransaction: rawTransaction,
                fee: fee.amount,
                myAddress: fromAddress.destination,
            )
            Web3TransactionDAO.shared.save(transactions: [pendingTransaction]) { db in
                try rawTransaction.save(db)
            }
            let hash = rawTransaction.hash
            Logger.web3.info(category: "EVMTransfer", message: "Will respond hash: \(hash)")
            try await respond(hash: hash)
            Logger.web3.info(category: "EVMTransfer", message: "Txn sent")
            await MainActor.run {
                self.state = .success
                self.hasTransactionSent = true
                Web3Diagnostic.usesLowEVMFeeOnce = false
            }
        } catch {
            Logger.web3.error(category: "EVMTransfer", message: "Send: \(error)")
            await MainActor.run {
                self.state = .sendingFailed(error)
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
    
    private let payment: Web3SendingTokenToAddressPayment
    private let decimalAmount: Decimal
    private let simulation: TransactionSimulation
    private let feePolicy: FeePolicy
    private let eip7702AuthAddress = "0xe6cae83bde06e4c305530e199d7217f42808555b"
    
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
        let transaction: EIP1559Transaction
        if payment.sendingNativeToken {
            guard let value = BigUInt(amountString) else {
                throw InitError.invalidAmount(decimalAmount)
            }
            transaction = EIP1559Transaction(
                chainID: evmChainID,
                nonce: nil,
                maxPriorityFeePerGas: nil,
                maxFeePerGas: nil,
                gasLimit: nil,
                destination: EthereumAddress(payment.toAddress),
                amount: value,
                data: Data(),
            )
        } else {
            guard let receiver = EthereumAddress(payment.toAddress).asData(), receiver.count <= 32 else {
                throw InitError.invalidReceiver(payment.toAddress)
            }
            guard let amountData = BigUInt(amountString, radix: 10)?.serialize(), amountData.count <= 32 else {
                throw InitError.invalidAmount(decimalAmount)
            }
            let data = Data([0xa9, 0x05, 0x9c, 0xbb])
            + Data(repeating: 0, count: 32 - receiver.count)
            + receiver
            + Data(repeating: 0, count: 32 - amountData.count)
            + amountData
            transaction = EIP1559Transaction(
                chainID: evmChainID,
                nonce: nil,
                maxPriorityFeePerGas: nil,
                maxFeePerGas: nil,
                gasLimit: nil,
                destination: EthereumAddress(payment.token.assetKey),
                amount: 0,
                data: data
            )
        }
        let simulation: TransactionSimulation = .balanceChange(
            token: payment.token,
            amount: decimalAmount,
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
                    self.state = .ready
                }
                return fee
            } catch {
                Logger.web3.error(category: "EVMTransfer", message: "Gasless unavailable: \(error)")
                return try await super.reloadFee()
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
                    self.fee = fee
                    self.state = .ready
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
            state = .signing
        }
        let signedTransaction: SignedEVMGaslessTransactionProposal
        let nonce: String
        do {
            let account = try await wallet.ethereumAccount(pin: pin, address: fromAddress)
            guard fromAddress.destination == account.address.toChecksumAddress() else {
                throw RequestError.mismatchedAddress
            }
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
            Logger.web3.info(category: "EVMTransfer(Gasless)", message: "Will sign")
            let signedUserOperation = try {
                var message = payload.signing.userOperation.message
                if message.hasPrefix("0x") {
                    message.removeFirst(2)
                }
                guard let messageData = Data(hexEncodedString: message) else {
                    throw SigningError.invalidUserOperation
                }
                return try account.signGaslessPayload(message: messageData)
            }()
            let signedAuth: String? = try {
                guard let auth = payload.signing.eip7702Auth else {
                    return nil
                }
                guard auth.address.lowercased() == eip7702AuthAddress else {
                    throw SigningError.invalidEIP7702AuthAddress
                }
                var message = auth.message
                if message.hasPrefix("0x") {
                    message.removeFirst(2)
                }
                guard let messageData = Data(hexEncodedString: message) else {
                    throw SigningError.invalidEIP7702AuthMessage
                }
                return try account.signGaslessPayload(message: messageData)
            }()
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
                self.state = .signingFailed(error)
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
                fee: fee.amount,
                myAddress: fromAddress.destination,
            )
            Web3TransactionDAO.shared.save(transactions: [pendingTransaction]) { db in
                try rawTransaction.save(db)
            }
            Logger.web3.info(category: "EVMTransfer(Gasless)", message: "Txn sent")
            await MainActor.run {
                self.state = .success
                self.hasTransactionSent = true
            }
        } catch {
            Logger.web3.error(category: "EVMTransfer(Gasless)", message: "Send: \(error)")
            await MainActor.run {
                self.state = .sendingFailed(error)
            }
            throw error
        }
    }
    
    override func respond(hash: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
    @MainActor func load(fee: Fee) {
        self.fee = fee
        self.state = .ready
    }
    
}

// MARK: - Override Transactions
class EVMOverrideOperation: EVMTransferOperation {
    
    private enum InitError: Error {
        case missingNonce
    }
    
    private let nonce: Int
    
    init(
        wallet: Web3Wallet,
        fromAddress: Web3Address,
        toAddress: String,
        transaction: EIP1559Transaction,
        chain: Web3Chain,
        simulationDisplay: SimulationDisplay,
    ) throws {
        guard let nonce = transaction.nonce else {
            throw InitError.missingNonce
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
        transaction: EIP1559Transaction,
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
        transaction: EIP1559Transaction,
        chain: Web3Chain
    ) throws {
        let emptyTransaction = EIP1559Transaction(
            chainID: transaction.chainID,
            nonce: transaction.nonce,
            maxPriorityFeePerGas: nil,
            maxFeePerGas: nil,
            gasLimit: nil,
            destination: EthereumAddress(fromAddress.destination),
            amount: 0,
            data: Data(),
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
