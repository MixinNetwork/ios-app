import GRDB

public final class ChainDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let chainId = "cid"
    }
    
    public static let shared = ChainDAO()
    
    public static let chainsDidChangeNotification = NSNotification.Name("one.mixin.services.ChainDAO.chainsDidChange")
    
    public func chainExists(chainId: String) -> Bool {
        db.recordExists(in: Chain.self, where: Chain.column(of: .chainId) == chainId)
    }
    
    public func save(_ chains: [Chain]) {
        guard !chains.isEmpty else {
            return
        }
        db.save(chains) { _ in
            let center = NotificationCenter.default
            if chains.count == 1 {
                center.post(onMainThread: Self.chainsDidChangeNotification,
                            object: self,
                            userInfo: [Self.UserInfoKey.chainId: chains[0].chainId])
            } else {
                center.post(onMainThread: Self.chainsDidChangeNotification,
                            object: nil)
            }
        }
    }
    
    public func chain(chainId: String) -> Chain? {
        db.select(where: Chain.column(of: .chainId) == chainId)
    }
    
}
