import Foundation
import GRDB

public final class Web3ChainDAO: Web3DAO {
    
    public static let shared = Web3ChainDAO()
    
    public func chain(chainID: String) -> Chain? {
        db.select(where: Chain.column(of: .chainId) == chainID)
    }
    
    public func chains(chainIDs: any Sequence<String>) -> [String: Chain] {
        let query: GRDB.SQL = "SELECT * FROM chains WHERE chain_id IN \(chainIDs)"
        let chains: [Chain] = db.select(with: query)
        return chains.reduce(into: [:]) { result, chain in
            result[chain.chainId] = chain
        }
    }
    
    public func save(_ chains: [Chain]) {
        guard !chains.isEmpty else {
            return
        }
        db.save(chains)
    }
    
}
