import Foundation
import MixinServices

final class Web3GaslessTradingFee: Web3DisplayFee {
    
    let proposal: GaslessTransactionProposal
    
    init(
        token: Web3TokenItem,
        proposal: GaslessTransactionProposal,
    ) {
        self.proposal = proposal
        super.init(token: token, amount: 0, gasless: true)
    }
    
}
