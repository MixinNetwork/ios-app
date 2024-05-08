import MixinServices

extension Web3Transaction {
    
    public var localizedTransactionType: String {
        switch Web3Transaction.Web3TransactionType(rawValue: operationType) {
        case .receive:
            R.string.localizable.receive()
        case .send:
            R.string.localizable.send()
        default:
            operationType.capitalized
        }
    }
    
}
