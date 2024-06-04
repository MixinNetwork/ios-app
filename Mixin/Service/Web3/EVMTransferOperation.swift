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
    
    private struct EVMFee {
        let gasLimit: BigUInt
        let gasPrice: BigUInt // Wei
    }
    
    private enum RequestError: Error {
        case mismatchedAddress
        case invalidFee(String)
    }
    
    let transactionPreview: EVMTransactionPreview
    
    fileprivate let client: EthereumHttpClient
    
    fileprivate var transaction: EthereumTransaction?
    fileprivate var account: EthereumAccount?
    
    private let balanceChange: BalanceChange
    
    private var evmFee: EVMFee?
    
    fileprivate init(
        fromAddress: String,
        transaction: EVMTransactionPreview,
        chain: Web3Chain,
        balanceChange balanceChangeDerivation: BalanceChangeDerivation
    ) throws {
        assert(!Thread.isMainThread)
        let client = try {
            let network: EthereumNetwork = switch chain {
            case .ethereum:
                    .mainnet
            default:
                switch chain.specification {
                case let .evm(id):
                        .custom("\(id)")
                default:
                    throw InitError.notEVMChain(chain.name)
                }
            }
            return EthereumHttpClient(url: chain.rpcServerURL, network: network)
        }()
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
        self.client = client
        self.balanceChange = balanceChange
        
        super.init(fromAddress: fromAddress,
                   toAddress: transaction.to.toChecksumAddress(),
                   chain: chain,
                   feeToken: feeToken,
                   canDecodeBalanceChange: canDecodeBalanceChange)
    }
    
    override func loadBalanceChange() async throws -> BalanceChange {
        balanceChange
    }
    
    override func loadFee() async throws -> Fee? {
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
        Logger.web3.info(category: "EVMTransfer", message: "Using limit: \(gasLimit.description), price: \(gasPrice.description)")
        
        let weiFee = (gasLimit * gasPrice).description
        guard let decimalWeiFee = Decimal(string: weiFee, locale: .enUSPOSIX) else {
            throw RequestError.invalidFee(weiFee)
        }
        let tokenCount = decimalWeiFee * .wei
        let fiatMoneyCount = tokenCount * feeToken.decimalUSDPrice * Currency.current.decimalRate
        let fee = Fee(token: tokenCount, fiatMoney: fiatMoneyCount)
        Logger.web3.info(category: "EVMTransfer", message: "Using limit: \(gasLimit.description), price: \(gasPrice.description)")
        let evmFee = EVMFee(gasLimit: gasLimit, gasPrice: gasPrice)
        await MainActor.run {
            self.evmFee = evmFee
            self.state = .ready
        }
        return fee
    }
    
    override func start(with pin: String) {
        guard let fee = evmFee else {
            assertionFailure("Missing fee, call `start(with:)` only after fee is arrived")
            return
        }
        state = .signing
        Task.detached { [chain, client, transactionPreview] in
            Logger.web3.info(category: "EVMTransfer", message: "Will sign")
            let account: EthereumAccount
            let transaction: EthereumTransaction
            do {
                let priv = try await TIP.deriveEthereumPrivateKey(pin: pin)
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
                                                  chainId: -1)
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
    
    override func resendTransaction(_ sender: Any) {
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
    
    private func send(transaction: EthereumTransaction, with account: EthereumAccount) async {
        do {
            let transactionDescription = transaction.raw?.hexEncodedString()
                ?? transaction.jsonRepresentation
                ?? "(null)"
            Logger.web3.info(category: "EVMTransfer", message: "Will send tx: \(transactionDescription)")
            let hash = try await client.eth_sendRawTransaction(transaction, withAccount: account)
            Logger.web3.info(category: "TxnRequest", message: "Will respond hash: \(hash)")
            try await respond(hash: hash)
            Logger.web3.info(category: "EVMTransfer", message: "Txn sent")
            await MainActor.run {
                self.state = .success
                self.hasTransactionSent = true
            }
        } catch {
            Logger.web3.error(category: "EVMTransfer", message: "Failed to send: \(error)")
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
        let decimalAmountNumber = decimalAmount as NSDecimalNumber
        let amount = decimalAmountNumber.multiplying(byPowerOf10: payment.token.decimalValuePower)
        guard amount == amount.rounding(accordingToBehavior: NSDecimalNumberHandler.extractIntegralPart) else {
            throw InitError.invalidAmount(decimalAmount)
        }
        let amountString = Token.amountString(from: amount as Decimal)
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
