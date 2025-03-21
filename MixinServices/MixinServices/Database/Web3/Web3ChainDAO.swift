import Foundation
import GRDB

public final class Web3ChainDAO: Web3DAO {
    
    public static let shared = Web3ChainDAO()
    
    public func save(_ chains: [Chain]) {
        guard !chains.isEmpty else {
            return
        }
        db.save(chains)
    }
    
}
