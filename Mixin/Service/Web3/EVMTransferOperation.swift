import Foundation
import BigInt
import web3
import Web3Wallet
import MixinServices

class EVMTransferOperation: Web3TransferOperation {
    
    class EVMDisplayFee: DisplayFee {
        
        let feePerGas: Decimal // In Gwei
        
        init(feePerGas: Decimal, tokenAmount: Decimal, fiatMoneyAmount: Decimal) {
            self.feePerGas = feePerGas
            super.init(tokenAmount: tokenAmount, fiatMoneyAmount: fiatMoneyAmount)
        }
        
    }
    
    enum InitError: Error {
        case noFeeToken(String)
        case invalidAmount(Decimal)
        case invalidReceiver(String)
        case notEVMChain(String)
    }
    
    private enum RequestError: Error {
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
    @MainActor private var fee: DisplayFee?
    @MainActor private var transaction: EIP1559Transaction
    @MainActor private var account: EthereumAccount?
    
    fileprivate init(
        wallet: MixinServices.Web3Wallet,
        fromAddress: Web3Address,
        toAddress: String,
        transaction: EIP1559Transaction,
        chain: Web3Chain,
        hardcodedSimulation: TransactionSimulation?,
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
            isResendingTransactionAvailable: true,
            hardcodedSimulation: hardcodedSimulation,
        )
    }
    
    fileprivate init(
        wallet: MixinServices.Web3Wallet,
        fromAddress: Web3Address,
        transaction: ExternalEVMTransaction,
        chain: Web3Chain,
        hardcodedSimulation: TransactionSimulation?,
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
            destination: transaction.to,
            amount: transaction.value ?? 0,
            data: transaction.data
        )
        self.mixinChainID = chain.chainID
        
        super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: transaction.to.toChecksumAddress(),
            chain: chain,
            feeToken: feeToken,
            isResendingTransactionAvailable: true,
            hardcodedSimulation: hardcodedSimulation,
        )
    }
    
    override func loadFee() async throws -> DisplayFee {
        let rawFee = try await RouteAPI.estimatedEthereumFee(
            mixinChainID: mixinChainID,
            hexData: transaction.data?.hexEncodedString(),
            from: fromAddress.destination,
            to: transaction.destination.toChecksumAddress()
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
        let fee = EVMDisplayFee(
            feePerGas: NSDecimalNumber(decimal: feePerGas)
                .rounding(accordingToBehavior: gweiRoundingHandler)
                .decimalValue,
            tokenAmount: tokenAmount,
            fiatMoneyAmount: tokenAmount * feeToken.decimalUSDPrice * Currency.current.decimalRate
        )
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
        guard let evmFee = await evmFee, let fee = await fee else {
            assertionFailure("Missing fee, call `start(with:)` only after fee is arrived")
            return
        }
        await MainActor.run {
            state = .signing
        }
        Logger.web3.info(category: "EVMTransfer", message: "Will sign")
        let account: EthereumAccount
        let updatedTransaction: EIP1559Transaction
        do {
            let privateKey: Data
            switch wallet.category.knownCase {
            case .classic:
                privateKey = try await TIP.deriveEthereumPrivateKey(pin: pin)
            case .importedMnemonic:
                guard let pathString = fromAddress.path else {
                    throw SigningError.missingDerivationPath
                }
                let encryptedMnemonics = AppGroupKeychain.importedMnemonics(walletID: wallet.walletID)
                guard let encryptedMnemonics else {
                    throw SigningError.missingPrivateKey
                }
                let key = try await TIP.importedWalletEncryptionKey(pin: pin)
                let mnemonics = try encryptedMnemonics.decrypt(with: key)
                let path = try DerivationPath(string: pathString)
                privateKey = try mnemonics.deriveForEVM(path: path).privateKey
            case .importedPrivateKey:
                let encryptedPrivateKey = AppGroupKeychain.importedPrivateKey(walletID: wallet.walletID)
                guard let encryptedPrivateKey else {
                    throw SigningError.missingPrivateKey
                }
                let key = try await TIP.importedWalletEncryptionKey(pin: pin)
                privateKey = try encryptedPrivateKey.decrypt(with: key)
            case .none:
                throw SigningError.unknownCategory
            }
            let keyStorage = InPlaceKeyStorage(raw: privateKey)
            account = try EthereumAccount(keyStorage: keyStorage)
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
            return
        }
        
        Logger.web3.info(category: "EVMTransfer", message: "Will send")
        await MainActor.run {
            self.transaction = updatedTransaction
            self.account = account
            self.state = .sending
        }
        await self.send(transaction: updatedTransaction, with: account, fee: fee)
    }
    
    override func resendTransaction() {
        guard let fee, let account else {
            return
        }
        state = .sending
        Logger.web3.info(category: "EVMTransfer", message: "Will resend")
        Task.detached { [transaction] in
            Logger.web3.info(category: "EVMTransfer", message: "Will resend")
            await self.send(transaction: transaction, with: account, fee: fee)
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
    
    private func send(transaction: EIP1559Transaction, with account: EthereumAccount, fee: DisplayFee) async {
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
                rawTransaction: hexEncodedSignedTransaction
            )
            let pendingTransaction = Web3Transaction(rawTransaction: rawTransaction, fee: fee.tokenAmount)
            Web3TransactionDAO.shared.save(transactions: [pendingTransaction]) { db in
                try rawTransaction.save(db)
            }
            let hash = rawTransaction.hash
            Logger.web3.info(category: "TxnRequest", message: "Will respond hash: \(hash)")
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
        }
    }
    
}

// MARK: - External transactions
final class Web3TransferWithWalletConnectOperation: EVMTransferOperation {
    
    let session: WalletConnectSession
    let request: WalletConnectSign.Request
    
    init(
        wallet: MixinServices.Web3Wallet,
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
            hardcodedSimulation: nil,
        )
    }
    
    override func respond(hash: String) async throws {
        let response = RPCResult.response(AnyCodable(hash))
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

final class EVMTransferWithBrowserWalletOperation: EVMTransferOperation {
    
    private let respondImpl: ((String) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    init(
        wallet: MixinServices.Web3Wallet,
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
            hardcodedSimulation: nil,
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
    
    init(
        evmChainID: Int,
        payment: Web3SendingTokenToAddressPayment,
        decimalAmount: Decimal
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
                data: nil
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
            amount: decimalAmount
        )
        try super.init(
            wallet: payment.wallet,
            fromAddress: payment.fromAddress,
            toAddress: payment.toAddress,
            transaction: transaction,
            chain: payment.chain,
            hardcodedSimulation: simulation
        )
    }
    
    override func respond(hash: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
}

// MARK: - Override Transactions
class EVMOverrideOperation: EVMTransferOperation {
    
    private enum InitError: Error {
        case missingNonce
    }
    
    private let nonce: Int
    
    override init(
        wallet: MixinServices.Web3Wallet,
        fromAddress: Web3Address,
        toAddress: String,
        transaction: EIP1559Transaction,
        chain: Web3Chain,
        hardcodedSimulation: TransactionSimulation?,
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
            hardcodedSimulation: hardcodedSimulation
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
        wallet: MixinServices.Web3Wallet,
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
            hardcodedSimulation: nil
        )
    }
    
}

final class EVMCancelOperation: EVMOverrideOperation {
    
    init(
        wallet: MixinServices.Web3Wallet,
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
            data: nil
        )
        try super.init(
            wallet: wallet,
            fromAddress: fromAddress,
            toAddress: "",
            transaction: emptyTransaction,
            chain: chain,
            hardcodedSimulation: .empty
        )
    }
    
}
