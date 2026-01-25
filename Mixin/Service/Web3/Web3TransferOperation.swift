import Foundation
import MixinServices

class Web3TransferOperation {
    
    enum State {
        case loading
        case unavailable(reason: String)
        case ready
        case signing
        case signingFailed(Error)
        case sending
        case sendingFailed(Error)
        case success
    }
    
    enum SigningError: Error {
        case invalidTransaction
        case invalidBlockhash
        case noFeeToken(String)
    }
    
    let wallet: Web3Wallet
    let fromAddress: Web3Address
    let toAddress: String? // Always the receiver, not the contract address
    let chain: Web3Chain
    let feeToken: Web3TokenItem
    let isResendingTransactionAvailable: Bool
    let hardcodedSimulation: TransactionSimulation?
    let isFeeWaived: Bool
    
    @MainActor @Published
    var state: State = .loading
    
    @MainActor
    var fee: Web3DisplayFee?
    
    var hasTransactionSent = false
    
    init(
        wallet: Web3Wallet, fromAddress: Web3Address, toAddress: String?,
        chain: Web3Chain, feeToken: Web3TokenItem,
        isResendingTransactionAvailable: Bool,
        hardcodedSimulation: TransactionSimulation?, isFeeWaived: Bool
    ) {
        self.wallet = wallet
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.chain = chain
        self.feeToken = feeToken
        self.isResendingTransactionAvailable = isResendingTransactionAvailable
        self.hardcodedSimulation = hardcodedSimulation
        self.isFeeWaived = isFeeWaived
    }
    
    func loadFee() async throws -> Web3DisplayFee {
        fatalError("Must override")
    }
    
    func simulateTransaction() async throws -> TransactionSimulation {
        if let hardcodedSimulation {
            return hardcodedSimulation
        } else {
            fatalError("Simulate txn if not hardcoded")
        }
    }
    
    func start(pin: String) async throws {
        assertionFailure("Must override")
    }
    
    func reject() {
        assertionFailure("Must override")
    }
    
    func rejectTransactionIfNotSent() {
        guard !hasTransactionSent else {
            return
        }
        Logger.web3.info(category: "Web3Transfer", message: "Rejected by dismissing")
        reject()
    }
    
    @MainActor func resendTransaction() {
        
    }
    
}
