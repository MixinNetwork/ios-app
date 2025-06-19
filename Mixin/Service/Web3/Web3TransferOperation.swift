import Foundation
import MixinServices

class Web3TransferOperation: SwapOperation.PaymentOperation {
    
    struct Fee {
        let token: Web3TokenItem
        let amount: Decimal
        let fiatMoney: Decimal
    }
    
    enum State {
        case loading
        case ready
        case signing
        case signingFailed(Error)
        case sending
        case sendingFailed(Error)
        case success
    }
    
    let walletID: String
    let fromAddress: String
    let toAddress: String // Always the receiver, not the contract address
    let chain: Web3Chain
    let feeToken: Web3TokenItem
    let isResendingTransactionAvailable: Bool
    let hardcodedSimulation: TransactionSimulation?
    
    @MainActor @Published
    var state: State = .loading
    var hasTransactionSent = false
    
    init(
        walletID: String, fromAddress: String, toAddress: String,
        chain: Web3Chain, feeToken: Web3TokenItem,
        isResendingTransactionAvailable: Bool,
        hardcodedSimulation: TransactionSimulation?
    ) {
        self.walletID = walletID
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.chain = chain
        self.feeToken = feeToken
        self.isResendingTransactionAvailable = isResendingTransactionAvailable
        self.hardcodedSimulation = hardcodedSimulation
    }
    
    func loadFee() async throws -> Fee {
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
