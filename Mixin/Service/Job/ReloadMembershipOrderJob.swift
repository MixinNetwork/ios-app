import Foundation
import MixinServices

final class ReloadMembershipOrderJob: AsynchronousJob {
    
    override func getJobId() -> String {
        "reload-membership-order"
    }
    
    override func execute() -> Bool {
        SafeAPI.membershipOrders { result in
            switch result {
            case .success(let orders):
                MembershipOrderDAO.shared.save(orders: orders)
            case .failure(let error):
                Logger.general.debug(category: "ReloadMembershipOrder", message: "\(error)")
            }
            self.finishJob()
        }
        return true
    }
    
}
