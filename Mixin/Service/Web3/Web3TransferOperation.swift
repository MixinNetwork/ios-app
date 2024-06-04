import Foundation
import MixinServices

class Web3TransferOperation {
    
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
    
    enum BalanceChange {
        case decodingFailed(rawTransaction: String)
        case detailed(token: Web3TransferableToken, amount: Decimal)
    }
    
    let fromAddress: String
    let toAddress: String
    let chain: Web3Chain
    let feeToken: TokenItem
    let canDecodeBalanceChange: Bool
    
    @Published
    var state: State = .loading
    var hasTransactionSent = false
    
    init(
        fromAddress: String, toAddress: String, chain: Web3Chain,
        feeToken: TokenItem, canDecodeBalanceChange: Bool
    ) {
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.chain = chain
        self.feeToken = feeToken
        self.canDecodeBalanceChange = canDecodeBalanceChange
    }
    
    func loadBalanceChange() async throws -> BalanceChange {
        fatalError("Must override")
    }
    
    func loadFee() async throws -> Fee? {
        fatalError("Must override")
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
