import Foundation
import MixinServices

final class RichWeb3RawTransaction: Web3RawTransaction {
    
    let simulateTransaction: TransactionSimulation?
    
    required init(from decoder: Decoder) throws {
        
        enum CodingKeys: String, CodingKey {
            case simulateTransaction = "simulate_tx"
        }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.simulateTransaction = try container.decodeIfPresent(
            TransactionSimulation.self,
            forKey: .simulateTransaction
        )
        try super.init(from: decoder)
    }
    
    private init(
        hash: String, chainID: String, account: String,
        nonce: String, raw: String,
        state: UnknownableEnum<Web3RawTransaction.State>,
        createdAt: String, updatedAt: String,
        simulateTransaction: TransactionSimulation?
    ) {
        self.simulateTransaction = simulateTransaction
        super.init(
            hash: hash,
            chainID: chainID,
            account: account,
            nonce: nonce,
            raw: raw,
            state: state,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    func replacingNonce(with nonce: String) -> RichWeb3RawTransaction {
        RichWeb3RawTransaction(
            hash: self.hash,
            chainID: self.chainID,
            account: self.account,
            nonce: nonce,
            raw: self.raw,
            state: self.state,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            simulateTransaction: self.simulateTransaction
        )
    }
    
}

extension Web3Transaction {
    
    convenience init(
        rawTransaction: RichWeb3RawTransaction,
        fee: Decimal?,
        myAddress: String,
    ) {
        self.init(
            rawTransaction: rawTransaction,
            simulation: rawTransaction.simulateTransaction,
            fee: fee,
            myAddress: myAddress,
        )
    }
    
}
