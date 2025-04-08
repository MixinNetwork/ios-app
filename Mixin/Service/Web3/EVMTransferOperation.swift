import Foundation
import BigInt
import web3
import Web3Wallet
import MixinServices

class EVMTransferOperation: Web3TransferOperation {
    
    enum InitError: Error {
        case noFeeToken(String)
        case invalidAmount(Decimal)
        case invalidReceiver(String)
        case notEVMChain(String)
    }
    
    fileprivate enum BalanceChangeDerivation {
        case fromTransactionPreview
        case arbitrary(BalanceChange)
    }
    
    private enum RequestError: Error {
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
    
    let transactionPreview: EVMTransactionPreview
    
    fileprivate var transaction: EIP1559Transaction?
    fileprivate var account: EthereumAccount?
    
    private let chainID: Int
    private let mixinChainID: String
    private let balanceChange: BalanceChange
    
    private var evmFee: EVMFee?
    
    fileprivate init(
        fromAddress: String,
        transaction: EVMTransactionPreview,
        chain: Web3Chain,
        balanceChange balanceChangeDerivation: BalanceChangeDerivation
    ) throws {
        let chainID: Int
        switch chain.specification {
        case let .evm(id):
            chainID = id
        default:
            throw InitError.notEVMChain(chain.name)
        }
        guard let feeToken = try chain.feeToken() else {
            throw InitError.noFeeToken(chain.feeTokenAssetID)
        }
        let balanceChange: BalanceChange = switch balanceChangeDerivation {
        case .fromTransactionPreview:
            if let amount = transaction.decimalValue, amount != 0 {
                .detailed(token: feeToken, amount: amount)
            } else {
                .decodingFailed(rawTransaction: transaction.hexData ?? "")
            }
        case .arbitrary(let change):
            change
        }
        let canDecodeBalanceChange = switch balanceChange {
        case .decodingFailed:
            false
        case .detailed:
            true
        }
        self.transactionPreview = transaction
        self.chainID = chainID
        self.mixinChainID = chain.chainID
        self.balanceChange = balanceChange
        
        super.init(fromAddress: fromAddress,
                   toAddress: transaction.to.toChecksumAddress(),
                   chain: chain,
                   feeToken: feeToken,
                   canDecodeBalanceChange: canDecodeBalanceChange, 
                   isResendingTransactionAvailable: true)
    }
    
    override func loadBalanceChange() async throws -> BalanceChange {
        balanceChange
    }
    
    override func loadFee() async throws -> Fee {
        let rawFee = try await RouteAPI.estimatedEthereumFee(
            mixinChainID: mixinChainID,
            hexData: transactionPreview.hexData,
            from: fromAddress,
            to: transactionPreview.to.toChecksumAddress()
        )
        Logger.web3.info(category: "EVMTransfer", message: "Using limit: \(rawFee.gasLimit), mfpg: \(rawFee.maxFeePerGas), mpfpg: \(rawFee.maxPriorityFeePerGas)")
        guard
            let gasLimit = BigUInt(rawFee.gasLimit),
            let maxFeePerGas = BigUInt(rawFee.maxFeePerGas),
            let maxPriorityFeePerGas = BigUInt(rawFee.maxPriorityFeePerGas),
            let weiCount = Decimal(string: (gasLimit * maxFeePerGas).description, locale: .enUSPOSIX)
        else {
            throw RequestError.invalidFee
        }
        let evmFee = EVMFee(
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas
        )
        await MainActor.run {
            self.evmFee = evmFee
            self.state = .ready
        }
        let tokenCount = weiCount * .wei
        let fee = Fee(
            token: tokenCount,
            fiatMoney: tokenCount * feeToken.decimalUSDPrice * Currency.current.decimalRate
        )
        return fee
    }
    
    override func start(with pin: String) {
        guard let fee = evmFee else {
            assertionFailure("Missing fee, call `start(with:)` only after fee is arrived")
            return
        }
        state = .signing
        Task.detached { [chainID, mixinChainID, transactionPreview] in
            Logger.web3.info(category: "EVMTransfer", message: "Will sign")
            let account: EthereumAccount
            let transaction: EIP1559Transaction
            do {
                let priv = try await TIP.deriveEthereumPrivateKey(pin: pin)
                let keyStorage = InPlaceKeyStorage(raw: priv)
                account = try EthereumAccount(keyStorage: keyStorage)
                guard transactionPreview.from == account.address else {
                    throw RequestError.mismatchedAddress
                }
                let count = try await RouteAPI.ethereumLatestTransactionCount(
                    chainID: mixinChainID,
                    address: account.address.toChecksumAddress()
                )
                guard let nonce = BigInt(hex: count) else {
                    throw RequestError.invalidTransactionCount
                }
                transaction = EIP1559Transaction(
                    chainID: chainID,
                    nonce: nonce,
                    maxPriorityFeePerGas: fee.maxPriorityFeePerGas,
                    maxFeePerGas: fee.maxFeePerGas,
                    gasLimit: fee.gasLimit,
                    destination: transactionPreview.to,
                    amount: transactionPreview.value ?? 0,
                    data: transactionPreview.data
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
                self.state = .sending
            }
            await self.send(transaction: transaction, with: account)
        }
    }
    
    fileprivate func respond(hash: String) async throws {
        assertionFailure("Must override")
    }
    
    override func resendTransaction() {
        guard let transaction, let account else {
            return
        }
        state = .sending
        Logger.web3.info(category: "EVMTransfer", message: "Will resend")
        Task.detached {
            Logger.web3.info(category: "EVMTransfer", message: "Will resend")
            await self.send(transaction: transaction, with: account)
        }
    }
    
    private func send(transaction: EIP1559Transaction, with account: EthereumAccount) async {
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
                raw: hexEncodedSignedTransaction
            )
            let pendingTransaction = {
                let (assetID, amount) = switch balanceChange {
                case .decodingFailed:
                    ("", "")
                case let .detailed(token, decimalAmount):
                    (token.assetID, TokenAmountFormatter.string(from: decimalAmount))
                }
                return Web3Transaction(
                    transactionID: "",
                    transactionHash: rawTransaction.hash,
                    blockNumber: -1,
                    sender: account.publicKey,
                    receiver: transaction.destination.toChecksumAddress(),
                    outputHash: "",
                    chainID: mixinChainID,
                    assetID: assetID,
                    amount: amount,
                    transactionType: .known(.send),
                    status: .known(.pending),
                    transactionAt: rawTransaction.createdAt,
                    createdAt: rawTransaction.createdAt,
                    updatedAt: rawTransaction.createdAt
                )
            }()
            Web3RawTransactionDAO.shared.save(
                rawTransaction: rawTransaction,
                pendingTransaction: pendingTransaction
            )
            let hash = rawTransaction.hash
            Logger.web3.info(category: "TxnRequest", message: "Will respond hash: \(hash)")
            try await respond(hash: hash)
            Logger.web3.info(category: "EVMTransfer", message: "Txn sent")
            await MainActor.run {
                self.state = .success
                self.hasTransactionSent = true
            }
        } catch {
            Logger.web3.error(category: "EVMTransfer", message: "Send: \(error)")
            await MainActor.run {
                self.state = .sendingFailed(error)
            }
        }
    }
    
}

final class Web3TransferWithWalletConnectOperation: EVMTransferOperation {
    
    let session: WalletConnectSession
    let request: WalletConnectSign.Request
    
    init(
        fromAddress: String,
        transaction: EVMTransactionPreview,
        chain: Web3Chain,
        session: WalletConnectSession,
        request: WalletConnectSign.Request
    ) throws {
        self.session = session
        self.request = request
        try super.init(fromAddress: fromAddress,
                       transaction: transaction,
                       chain: chain,
                       balanceChange: .fromTransactionPreview)
    }
    
    override func respond(hash: String) async throws {
        let response = RPCResult.response(AnyCodable(hash))
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

final class EVMTransferWithBrowserWalletOperation: EVMTransferOperation {
    
    private let respondImpl: ((String) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    init(
        fromAddress: String,
        transaction: EVMTransactionPreview,
        chain: Web3Chain,
        respondWith respondImpl: @escaping ((String) async throws -> Void),
        rejectWith rejectImpl: @escaping (() -> Void)
    ) throws {
        self.respondImpl = respondImpl
        self.rejectImpl = rejectImpl
        try super.init(fromAddress: fromAddress,
                       transaction: transaction,
                       chain: chain,
                       balanceChange: .fromTransactionPreview)
    }
    
    override func respond(hash: String) async throws {
        try await respondImpl?(hash)
    }
    
    override func reject() {
        rejectImpl?()
    }
    
}

final class EVMTransferToAddressOperation: EVMTransferOperation {
    
    init(payment: Web3SendingTokenToAddressPayment, decimalAmount: Decimal) throws {
        guard let amount = payment.token.nativeAmount(decimalAmount: decimalAmount) else {
            throw InitError.invalidAmount(decimalAmount)
        }
        // No need to worry about the fractional part, the amount is guranteed to be integral
        let amountString = TokenAmountFormatter.string(from: amount as Decimal)
        let transaction: EVMTransactionPreview
        if payment.sendingNativeToken {
            guard let value = BigUInt(amountString) else {
                throw InitError.invalidAmount(decimalAmount)
            }
            transaction = EVMTransactionPreview(
                from: EthereumAddress(payment.fromAddress),
                to: EthereumAddress(payment.toAddress),
                value: value,
                data: nil,
                decimalValue: decimalAmount
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
            transaction = EVMTransactionPreview(
                from: EthereumAddress(payment.fromAddress),
                to: EthereumAddress(payment.token.assetKey),
                value: nil,
                data: data,
                decimalValue: nil // TODO: Better preview with decimal value
            )
        }
        let change: BalanceChange = .detailed(token: payment.token, amount: decimalAmount)
        try super.init(fromAddress: payment.fromAddress,
                       transaction: transaction,
                       chain: payment.chain,
                       balanceChange: .arbitrary(change))
    }
    
    override func respond(hash: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
}
