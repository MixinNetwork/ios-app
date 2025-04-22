import Foundation
import MixinServices

class Web3TransferOperation: SwapOperation.PaymentOperation {
    
    struct Fee {
        let token: Decimal
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
    let toAddress: String
    let chain: Web3Chain
    let feeToken: Web3TokenItem
    let isResendingTransactionAvailable: Bool
    
    @Published
    var state: State = .loading
    var hasTransactionSent = false
    
    init(
        walletID: String, fromAddress: String, toAddress: String,
        chain: Web3Chain, feeToken: Web3TokenItem,
        isResendingTransactionAvailable: Bool
    ) {
        self.walletID = walletID
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.chain = chain
        self.feeToken = feeToken
        self.isResendingTransactionAvailable = isResendingTransactionAvailable
    }
    
    func simulateTransaction() async throws -> TransactionSimulation {
        fatalError("Must override")
    }
    
    func loadFee() async throws -> Fee {
        fatalError("Must override")
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
    
    func resendTransaction() {
        
    }
    
}
