import Foundation
import MixinServices

class Web3TransferOperation {
    
    enum State {
        case pending
        case signing
        case signingFailed(Error)
        case sending
        case sendingFailed(Error)
        case success
    }
    
    struct Fee {
        let token: Decimal
        let fiatMoney: Decimal
    }
    
    struct BalanceChange {
        let token: Web3TransferableToken
        let amount: Decimal
    }
    
    let fromAddress: String
    let toAddress: String
    let rawTransaction: String
    let chain: Web3Chain
    let feeToken: TokenItem
    let canDecodeBalanceChange: Bool
    
    @Published
    var state: State = .pending
    var hasTransactionSent = false
    
    init(
        fromAddress: String, toAddress: String, rawTransaction: String,
        chain: Web3Chain, feeToken: TokenItem, canDecodeBalanceChange: Bool
    ) {
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.rawTransaction = rawTransaction
        self.chain = chain
        self.feeToken = feeToken
        self.canDecodeBalanceChange = canDecodeBalanceChange
    }
    
    @MainActor
    func loadFee(completion: @escaping (Fee) -> Void) {
        
    }
    
    func loadBalanceChange(completion: @escaping (BalanceChange?) -> Void) {
        
    }
    
    func start(with pin: String) {
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
    
    @objc func resendTransaction(_ sender: Any) {
        assertionFailure("Must override")
    }
    
}
