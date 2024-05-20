import MixinServices

extension Web3AccountTransaction {
    
    public var localizedTransactionType: String {
        switch TransactionType(rawValue: operationType) {
        case .receive:
            R.string.localizable.receive()
        case .send:
            R.string.localizable.send()
        default:
            operationType.capitalized
        }
    }
    
}
