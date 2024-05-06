import Foundation
import BigInt
import web3
import Web3Wallet
import MixinServices

class Web3TransferOperation {
    
    enum InitError: Error {
        case noChainToken(String)
        case invalidAmount(Decimal)
        case invalidReceiver(String)
    }
    
    enum State {
        case pending
        case signing
        case signingFailed(Error)
        case sending
        case sendingFailed(Error)
        case success
    }
    
    struct Fee {
        let gasLimit: BigUInt
        let gasPrice: BigUInt // Wei
    }
    
    private enum RequestError: Error {
        case mismatchedAddress
        case invalidFee
    }
    
    let fromAddress: String
    let transactionPreview: Web3TransactionPreview
    let chain: Web3Chain
    let chainToken: TokenItem
    let canDecodeValue: Bool
    
    fileprivate let client: EthereumHttpClient
    
    @Published
    fileprivate(set) var state: State = .pending
    
    fileprivate var transaction: EthereumTransaction?
    fileprivate var account: EthereumAccount?
    fileprivate var hasTransactionSent = false
    
    private var fee: Fee?
    
    fileprivate init(
        fromAddress: String,
        transaction: Web3TransactionPreview,
        chain: Web3Chain
    ) throws {
        assert(!Thread.isMainThread)
        let chainToken: TokenItem?
        if let token = TokenDAO.shared.tokenItem(with: chain.mixinChainID) {
            chainToken = token
        } else {
            let token = try SafeAPI.assets(id: chain.mixinChainID).get()
            chainToken = TokenDAO.shared.saveAndFetch(token: token)
        }
        guard let chainToken else {
            throw InitError.noChainToken(chain.mixinChainID)
        }
        
        self.fromAddress = fromAddress
        self.transactionPreview = transaction
        self.chain = chain
        self.chainToken = chainToken
        self.client = chain.makeEthereumClient()
        self.canDecodeValue = (transaction.decimalValue ?? 0) != 0
    }
    
    @MainActor
    func loadGas(completion: @escaping (Fee) -> Void) {
        Task { [fromAddress, client, transactionPreview, weak self] in
            do {
                let dappGasLimit = transactionPreview.gas
                let transaction = EthereumTransaction(from: EthereumAddress(fromAddress),
                                                      to: transactionPreview.to,
                                                      value: transactionPreview.value ?? 0,
                                                      data: transactionPreview.data,
                                                      nonce: nil,
                                                      gasPrice: nil,
                                                      gasLimit: nil,
                                                      chainId: nil)
                let rpcGasLimit = try await client.eth_estimateGas(transaction)
                let gasLimit: BigUInt = {
                    let value = if let dappGasLimit {
                        max(dappGasLimit, rpcGasLimit)
                    } else {
                        rpcGasLimit
                    }
                    return value + value / 2 // 1.5x gasLimit
                }()
                var gasPrice = try await client.eth_gasPrice()
                gasPrice += gasPrice / 5 // 1.2x gasPrice
                let fee = Fee(gasLimit: gasLimit, gasPrice: gasPrice)
                Logger.web3.info(category: "TxnRequest", message: "Using limit: \(gasLimit.description), price: \(gasPrice.description)")
                await MainActor.run {
                    guard let self else {
                        return
                    }
                    self.fee = fee
                    completion(fee)
                }
            } catch {
                Logger.web3.info(category: "TxnRequest", message: "Failed to load gas: \(error)")
                try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
                self?.loadGas(completion: completion)
            }
        }
    }
    
    func start(with pin: String) {
        guard let fee = fee else {
            return
        }
        state = .signing
        Task.detached { [chain, client, transactionPreview] in
            Logger.web3.info(category: "TxnRequest", message: "Will sign")
            let account: EthereumAccount
            let transaction: EthereumTransaction
            do {
                let priv = try await TIP.web3WalletPrivateKey(pin: pin)
                let keyStorage = InPlaceKeyStorage(raw: priv)
                account = try EthereumAccount(keyStorage: keyStorage)
                guard transactionPreview.from == account.address else {
                    throw RequestError.mismatchedAddress
                }
                let nonce = try await client.eth_getTransactionCount(address: account.address, block: .Pending)
                transaction = EthereumTransaction(from: account.address,
                                                  to: transactionPreview.to,
                                                  value: transactionPreview.value ?? 0,
                                                  data: transactionPreview.data,
                                                  nonce: nonce,
                                                  gasPrice: fee.gasPrice,
                                                  gasLimit: fee.gasLimit,
                                                  chainId: chain.id)
            } catch {
                Logger.web3.error(category: "TxnRequest", message: "Failed to sign: \(error)")
                await MainActor.run {
                    self.state = .signingFailed(error)
                }
                return
            }
            
            Logger.web3.info(category: "TxnRequest", message: "Will send")
            await MainActor.run {
                self.state = .sending
            }
            await self.send(transaction: transaction, with: account)
        }
    }
    
    func reject() {
        assertionFailure("Must override")
    }
    
    func rejectTransactionIfNotSent() {
        guard !hasTransactionSent else {
            return
        }
        Logger.web3.info(category: "TxnRequest", message: "Rejected by dismissing")
        reject()
    }
    
    @objc func resendTransaction(_ sender: Any) {
        guard let transaction, let account else {
            return
        }
        state = .sending
        Logger.web3.info(category: "TxnRequest", message: "Will resend")
        Task.detached {
            Logger.web3.info(category: "TxnRequest", message: "Will resend")
            await self.send(transaction: transaction, with: account)
        }
    }
    
    fileprivate func respond(hash: String) async throws {
        assertionFailure("Must override")
    }
    
    private func send(transaction: EthereumTransaction, with account: EthereumAccount) async {
        do {
            let transactionDescription = transaction.raw?.hexEncodedString()
                ?? transaction.jsonRepresentation
                ?? "(null)"
            Logger.web3.info(category: "TxnRequest", message: "Will send tx: \(transactionDescription)")
            let hash = try await client.eth_sendRawTransaction(transaction, withAccount: account)
            Logger.web3.info(category: "TxnRequest", message: "Will respond hash: \(hash)")
            try await respond(hash: hash)
            Logger.web3.info(category: "TxnRequest", message: "Txn sent")
            await MainActor.run {
                self.state = .success
            }
        } catch {
            Logger.web3.error(category: "TxnRequest", message: "Failed to send: \(error)")
            await MainActor.run {
                self.state = .sendingFailed(error)
            }
        }
    }
    
}

final class Web3TransferWithWalletConnectOperation: Web3TransferOperation {
    
    let session: WalletConnectSession
    let request: WalletConnectSign.Request
    
    init(
        fromAddress: String,
        transaction: Web3TransactionPreview,
        chain: Web3Chain,
        session: WalletConnectSession,
        request: WalletConnectSign.Request
    ) throws {
        self.session = session
        self.request = request
        try super.init(fromAddress: fromAddress,
                       transaction: transaction,
                       chain: chain)
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

final class Web3TransferWithBrowserWalletOperation: Web3TransferOperation {
    
    private let respondImpl: ((String) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    init(
        fromAddress: String,
        transaction: Web3TransactionPreview,
        chain: Web3Chain,
        respondWith respondImpl: @escaping ((String) async throws -> Void),
        rejectWith rejectImpl: @escaping (() -> Void)
    ) throws {
        self.respondImpl = respondImpl
        self.rejectImpl = rejectImpl
        try super.init(fromAddress: fromAddress,
                       transaction: transaction,
                       chain: chain)
    }
    
    override func respond(hash: String) async throws {
        try await respondImpl?(hash)
    }
    
    override func reject() {
        rejectImpl?()
    }
    
}

final class Web3TransferToAddressOperation: Web3TransferOperation {
    
    init(payment: Web3SendingTokenToAddressPayment, decimalAmount: Decimal) throws {
        let decimalAmountNumber = decimalAmount as NSDecimalNumber
        let amount = decimalAmountNumber.multiplying(byPowerOf10: payment.token.decimalValuePower)
        guard amount == amount.rounding(accordingToBehavior: NSDecimalNumberHandler.extractIntegralPart) else {
            throw InitError.invalidAmount(decimalAmount)
        }
        let amountString = Token.amountString(from: amount as Decimal)
        let transaction: Web3TransactionPreview
        if payment.sendingNativeToken {
            guard let value = BigUInt(amountString) else {
                throw InitError.invalidAmount(decimalAmount)
            }
            transaction = Web3TransactionPreview(
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
            transaction = Web3TransactionPreview(
                from: EthereumAddress(payment.fromAddress),
                to: EthereumAddress(payment.token.assetKey),
                value: nil,
                data: data,
                decimalValue: nil // TODO: Better preview with decimal value
            )
        }
        try super.init(fromAddress: payment.fromAddress,
                       transaction: transaction,
                       chain: payment.chain)
    }
    
    override func respond(hash: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
}
