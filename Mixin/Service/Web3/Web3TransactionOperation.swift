import Foundation
import BigInt
import web3
import Web3Wallet
import MixinServices

class Web3TransactionOperation {
    
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
        let feeValue: String
        let feeCost: String
        
        init?(gasLimit: BigUInt, gasPrice: BigUInt, tokenPrice: Decimal) {
            guard let weiFee = Decimal(string: (gasLimit * gasPrice).description, locale: .enUSPOSIX) else {
                return nil
            }
            let decimalFee = weiFee * .wei
            let cost = decimalFee * tokenPrice
            
            self.gasLimit = gasLimit
            self.gasPrice = gasPrice
            self.feeValue = CurrencyFormatter.localizedString(from: decimalFee, format: .networkFee, sign: .never, symbol: nil)
            if cost >= 0.01 {
                self.feeCost = CurrencyFormatter.localizedString(from: cost, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            } else {
                self.feeCost = "<" + CurrencyFormatter.localizedString(from: 0.01, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            }
        }
        
    }
    
    private enum RequestError: Error {
        case mismatchedAddress
        case invalidFee
    }
    
    let address: String
    let proposer: Web3Proposer
    let transactionPreview: Web3TransactionPreview
    let chain: WalletConnectService.Chain
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
        address: String,
        proposer: Web3Proposer,
        transaction: Web3TransactionPreview,
        chain: WalletConnectService.Chain,
        chainToken: TokenItem
    ) {
        self.address = address
        self.proposer = proposer
        self.transactionPreview = transaction
        self.chain = chain
        self.chainToken = chainToken
        self.client = chain.makeEthereumClient()
        self.canDecodeValue = (transaction.decimalValue ?? 0) != 0
    }
    
    @MainActor
    func loadGas(completion: @escaping (Fee) -> Void) {
        let tokenPrice = chainToken.decimalUSDPrice * Currency.current.decimalRate
        Task { [address, client, transactionPreview, weak self] in
            do {
                let dappGasLimit = transactionPreview.gas
                let transaction = EthereumTransaction(from: EthereumAddress(address),
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
                let fee = Fee(gasLimit: gasLimit,
                              gasPrice: gasPrice,
                              tokenPrice: tokenPrice)
                guard let fee else {
                    Logger.web3.error(category: "TxnRequest", message: "Invalid limit: \(gasLimit.description), price: \(gasPrice.description)")
                    throw RequestError.invalidFee
                }
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

final class Web3TransactionWithWalletConnectOperation: Web3TransactionOperation {
    
    let session: WalletConnectSession
    let request: WalletConnectSign.Request
    
    init(
        address: String,
        proposer: Web3Proposer,
        transaction: Web3TransactionPreview,
        chain: WalletConnectService.Chain,
        chainToken: TokenItem,
        session: WalletConnectSession,
        request: WalletConnectSign.Request
    ) {
        self.session = session
        self.request = request
        super.init(address: address,
                   proposer: proposer,
                   transaction: transaction,
                   chain: chain,
                   chainToken: chainToken)
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

final class Web3TransactionWithBrowserWalletOperation: Web3TransactionOperation {
    
    private let respondImpl: ((String) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    init(
        address: String,
        proposer: Web3Proposer,
        transaction: Web3TransactionPreview,
        chain: WalletConnectService.Chain,
        chainToken: TokenItem,
        respondWith respondImpl: @escaping ((String) async throws -> Void),
        rejectWith rejectImpl: @escaping (() -> Void)
    ) {
        self.respondImpl = respondImpl
        self.rejectImpl = rejectImpl
        super.init(address: address,
                   proposer: proposer,
                   transaction: transaction,
                   chain: chain,
                   chainToken: chainToken)
    }
    
    override func respond(hash: String) async throws {
        try await respondImpl?(hash)
    }
    
    override func reject() {
        rejectImpl?()
    }
    
}
