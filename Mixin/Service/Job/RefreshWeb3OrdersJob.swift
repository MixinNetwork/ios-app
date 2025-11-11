import Foundation
import MixinServices

public final class RefreshWeb3OrdersJob: AsynchronousJob {
    
    override public func getJobId() -> String {
        "refresh-web3-orders"
    }
    
    public override func execute() -> Bool {
        RouteAPI.limitOrders(category: .all, limit: 100, offset: nil) { result in
            switch result {
            case let .success(orders):
                Web3OrderDAO.shared.save(orders: orders)
            case let .failure(error):
                Logger.general.debug(category: "RefreshWeb3Orders", message: "\(error)")
            }
            self.finishJob()
        }
        return true
    }
    
}
