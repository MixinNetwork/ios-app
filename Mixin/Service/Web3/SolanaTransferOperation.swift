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
    
    private enum SigningError: Error {
        case invalidTransaction
        case invalidBlockhash
        case noFeeToken(String)
    }
    
    let transaction: Solana.Transaction
    let client: SolanaRPCClient
    
    init(
        fromAddress: String,
        toAddress: String,
        transaction: Solana.Transaction,
        chain: Web3Chain
    ) throws {
        guard let feeToken = try chain.feeToken() else {
            throw InitError.noFeeToken(chain.feeTokenAssetID)
        }
        self.transaction = transaction
        self.client = SolanaRPCClient(url: chain.rpcServerURL)
        super.init(fromAddress: fromAddress,
                   toAddress: toAddress,
                   rawTransaction: transaction.rawTransaction,
                   chain: chain,
                   feeToken: feeToken,
                   canDecodeBalanceChange: transaction.change != nil)
    }
    
    override func loadFee(completion: @escaping (Fee) -> Void) {
        Task {
            do {
                let lamportsPerSignature = try await client.getRecentBlockhash().lamportsPerSignature
                guard let tokenCount = transaction.fee(lamportsPerSignature: lamportsPerSignature) else {
                    return
                }
                let fiatMoneyCount = tokenCount * feeToken.decimalUSDPrice * Currency.current.decimalRate
                let fee = Fee(token: tokenCount, fiatMoney: fiatMoneyCount)
                await MainActor.run {
                    completion(fee)
                }
            } catch {
                Logger.web3.debug(category: "SolanaTransfer", message: "Load fee: \(error)")
            }
        }
    }
    
    override func loadBalanceChange(completion: @escaping (BalanceChange?) -> Void) {
        guard let change = transaction.change else {
            completion(nil)
            return
        }
        Web3API.tokens(address: change.assetKey) { result in
            switch result {
            case .success(let tokens):
                if let token = tokens.first {
                    completion(BalanceChange(token: token, amount: change.amount))
                } else {
                    fallthrough
                }
            case .failure:
                completion(nil)
            }
        }
    }
    
    override func start(with pin: String) {
        state = .signing
        Task.detached { [client, transaction] in
            let signedTransaction: String
            do {
                Logger.web3.info(category: "SolanaTransfer", message: "Start")
                let priv = try await TIP.deriveSolanaPrivateKey(pin: pin)
                let recentBlockhash = try await client.getRecentBlockhash().blockhash
                Logger.web3.info(category: "SolanaTransfer", message: "Using blockhash: \(recentBlockhash)")
                guard let blockhash = Data(base58EncodedString: recentBlockhash) else {
                    throw SigningError.invalidBlockhash
                }
                Logger.web3.info(category: "SolanaTransfer", message: "Will sign")
                signedTransaction = try transaction.sign(withPrivateKeyFrom: priv, recentBlockhash: blockhash)
            } catch {
                Logger.web3.error(category: "SolanaTransfer", message: "Failed to sign: \(error)")
                await MainActor.run {
                    self.state = .signingFailed(error)
                }
                return
            }
            Logger.web3.info(category: "SolanaTransfer", message: "Will send")
            await MainActor.run {
                self.state = .sending
            }
            try await self.send(signedTransaction: signedTransaction)
        }
    }
    
    func respond(signature: String) async throws {
        assertionFailure("Must override")
    }
    
    private func send(signedTransaction: String) async throws {
        do {
            Logger.web3.info(category: "SolanaTransfer", message: "Will send tx: \(signedTransaction)")
            let signature = try await client.sendTransaction(signedTransaction: signedTransaction)
            try await respond(signature: signature)
            Logger.web3.info(category: "SolanaTransfer", message: "Txn sent")
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

final class SolanaTransferWithWalletConnectOperation: SolanaTransferOperation {
    
    let session: WalletConnectSession
    let request: WalletConnectSign.Request
    
    init(
        fromAddress: String,
        transaction: Solana.Transaction,
        chain: Web3Chain,
        session: WalletConnectSession,
        request: WalletConnectSign.Request
    ) throws {
        self.session = session
        self.request = request
        try super.init(fromAddress: fromAddress, 
                       toAddress: "", // FIXME: Decode txn
                       transaction: transaction,
                       chain: chain)
    }
    
    override func respond(signature: String) async throws {
        let response = RPCResult.response(AnyCodable(["signature": signature]))
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

final class SolanaTransferWithBrowserWalletOperation: SolanaTransferOperation {
    
    private let respondImpl: ((String) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    init(
        fromAddress: String,
        transaction: Solana.Transaction,
        chain: Web3Chain,
        respondWith respondImpl: @escaping ((String) async throws -> Void),
        rejectWith rejectImpl: @escaping (() -> Void)
    ) throws {
        self.respondImpl = respondImpl
        self.rejectImpl = rejectImpl
        try super.init(fromAddress: fromAddress,
                       toAddress: "", // FIXME: Decode txn
                       transaction: transaction,
                       chain: chain)
    }
    
    override func respond(signature: String) async throws {
        try await respondImpl?(signature)
    }
    
    override func reject() {
        rejectImpl?()
    }
    
}

final class SolanaTransferToAddressOperation: SolanaTransferOperation {
    
    init(payment: Web3SendingTokenToAddressPayment, decimalAmount: Decimal) throws {
        let decimalAmountNumber = decimalAmount as NSDecimalNumber
        let amount = decimalAmountNumber.multiplying(byPowerOf10: payment.token.decimalValuePower)
        guard amount == amount.rounding(accordingToBehavior: NSDecimalNumberHandler.extractIntegralPart) else {
            throw InitError.invalidAmount(decimalAmount)
        }
        let transaction = Solana.Transaction(from: payment.fromAddress,
                                             to: payment.toAddress,
                                             amount: decimalAmount,
                                             token: payment.token)
        guard let transaction else {
            throw InitError.buildTransaction
        }
        try super.init(fromAddress: payment.fromAddress,
                       toAddress: payment.toAddress,
                       transaction: transaction,
                       chain: payment.chain)
    }
    
    override func respond(signature: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
}
