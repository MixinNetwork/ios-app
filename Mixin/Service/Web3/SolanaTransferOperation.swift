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
    
    let client: SolanaRPCClient
    
    fileprivate init(
        fromAddress: String,
        toAddress: String,
        chain: Web3Chain,
        canDecodeBalanceChange: Bool
    ) throws {
        guard let feeToken = try chain.feeToken() else {
            throw InitError.noFeeToken(chain.feeTokenAssetID)
        }
        self.client = SolanaRPCClient(url: chain.rpcServerURL)
        Logger.web3.info(category: "SolanaTransfer", message: "Using RPC: \(chain.rpcServerURL)")
        super.init(fromAddress: fromAddress,
                   toAddress: toAddress,
                   chain: chain,
                   feeToken: feeToken,
                   canDecodeBalanceChange: canDecodeBalanceChange,
                   isResendingTransactionAvailable: false)
    }
    
    func respond(signature: String) async throws {
        assertionFailure("Must override")
    }
    
    func baseFee(for transaction: Solana.Transaction) throws -> Fee {
        let lamportsPerSignature: UInt64 = 5000
        let tokenCount = try transaction.fee(lamportsPerSignature: lamportsPerSignature)
        let fiatMoneyCount = tokenCount * feeToken.decimalUSDPrice * Currency.current.decimalRate
        let fee = Fee(token: tokenCount, fiatMoney: fiatMoneyCount)
        return fee
    }
    
    func signAndSend(transaction: Solana.Transaction, with pin: String) async throws {
        let signedTransaction: String
        do {
            Logger.web3.info(category: "SolanaTransfer", message: "Start")
            let priv = try await TIP.deriveSolanaPrivateKey(pin: pin)
            let recentBlockhash = try await client.getLatestBlockhash()
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
        await MainActor.run {
            self.state = .sending
        }
        do {
            Logger.web3.info(category: "SolanaTransfer", message: "Will send tx: \(signedTransaction)")
            let signature = try await client.sendTransaction(signedTransaction: signedTransaction)
            try await respond(signature: signature)
            Logger.web3.info(category: "SolanaTransfer", message: "Txn sent, sig: \(signature)")
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

class ArbitraryTransactionSolanaTransferOperation: SolanaTransferOperation {
    
    fileprivate let transaction: Solana.Transaction
    
    init(
        transaction: Solana.Transaction,
        fromAddress: String,
        toAddress: String,
        chain: Web3Chain
    ) throws {
        self.transaction = transaction
        try super.init(fromAddress: fromAddress,
                       toAddress: toAddress,
                       chain: chain,
                       canDecodeBalanceChange: transaction.change != nil)
        self.state = .ready
    }
    
    override func loadBalanceChange() async throws -> BalanceChange {
        if let change = transaction.change,
           let token = try await Web3API.tokens(address: change.assetKey).first
        {
            .detailed(token: token, amount: change.amount)
        } else {
            .decodingFailed(rawTransaction: transaction.rawTransaction)
        }
    }
    
    override func loadFee() async throws -> Fee {
        // TODO: This could be wrong. Needs to add up the priority fee if the txn includes
        try baseFee(for: transaction)
    }
    
    override func start(with pin: String) {
        state = .signing
        Task.detached { [transaction] in
            try await self.signAndSend(transaction: transaction, with: pin)
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
    
    init(
        transaction: Solana.Transaction,
        fromAddress: String,
        chain: Web3Chain,
        session: WalletConnectSession,
        request: WalletConnectSign.Request
    ) throws {
        self.session = session
        self.request = request
        try super.init(transaction: transaction,
                       fromAddress: fromAddress,
                       toAddress: "", // FIXME: Decode txn
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

final class SolanaTransferWithCustomRespondingOperation: ArbitraryTransactionSolanaTransferOperation {
    
    private let respondImpl: ((String) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    init(
        transaction: Solana.Transaction,
        fromAddress: String,
        chain: Web3Chain,
        respondWith respondImpl: ((String) async throws -> Void)? = nil,
        rejectWith rejectImpl: (() -> Void)? = nil
    ) throws {
        self.respondImpl = respondImpl
        self.rejectImpl = rejectImpl
        try super.init(transaction: transaction, 
                       fromAddress: fromAddress,
                       toAddress: "",
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
    
    private let payment: Web3SendingTokenToAddressPayment
    private let decimalAmount: Decimal
    private let amount: UInt64
    
    private var createAssociatedTokenAccountForReceiver: Bool?
    private var priorityFee: PriorityFee?
    
    init(payment: Web3SendingTokenToAddressPayment, decimalAmount: Decimal) throws {
        guard let amount = payment.token.nativeAmount(decimalAmount: decimalAmount) else {
            throw InitError.invalidAmount(decimalAmount)
        }
        self.payment = payment
        self.decimalAmount = decimalAmount
        self.amount = amount.uint64Value
        try super.init(fromAddress: payment.fromAddress,
                       toAddress: payment.toAddress,
                       chain: payment.chain,
                       canDecodeBalanceChange: true)
    }
    
    override func loadBalanceChange() async throws -> BalanceChange {
        .detailed(token: payment.token, amount: decimalAmount)
    }
    
    override func loadFee() async throws -> Fee {
        let ata = try Solana.tokenAssociatedAccount(owner: payment.toAddress, mint: payment.token.assetKey)
        let receiverAccountExists = try await client.accountExists(pubkey: ata)
        let createAccount = !receiverAccountExists
        let transaction = try Solana.Transaction(
            from: payment.fromAddress,
            to: payment.toAddress,
            createAssociatedTokenAccountForReceiver: createAccount,
            amount: amount,
            priorityFee: nil,
            token: payment.token,
            change: .init(amount: decimalAmount, assetKey: payment.token.assetKey)
        )
        let baseFee = try baseFee(for: transaction)
        let priorityFee = try await Web3API.priorityFee(transaction: transaction.rawTransaction)
        await MainActor.run {
            self.createAssociatedTokenAccountForReceiver = createAccount
            self.priorityFee = priorityFee
            self.state = .ready
        }
        let tokenCount = baseFee.token + priorityFee.decimalCount
        let fiatMoneyCount = tokenCount * feeToken.decimalUSDPrice * Currency.current.decimalRate
        return Fee(token: tokenCount, fiatMoney: fiatMoneyCount)
    }
    
    override func start(with pin: String) {
        guard let createAccount = createAssociatedTokenAccountForReceiver, let priorityFee else {
            assertionFailure("This shouldn't happen. Check when `state` becomes `ready`")
            return
        }
        state = .signing
        Task.detached { [payment, amount, decimalAmount, priorityFee] in
            let transaction = try Solana.Transaction(
                from: payment.fromAddress,
                to: payment.toAddress,
                createAssociatedTokenAccountForReceiver: createAccount,
                amount: amount, 
                priorityFee: priorityFee,
                token: payment.token,
                change: .init(amount: decimalAmount, assetKey: payment.token.assetKey)
            )
            try await self.signAndSend(transaction: transaction, with: pin)
        }
    }
    
    override func respond(signature: String) async throws {
        
    }
    
    override func reject() {
        
    }
    
}
