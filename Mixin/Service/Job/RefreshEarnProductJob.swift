import Foundation
import MixinServices

final class RefreshEarnProductJob: AsynchronousJob {
    
    enum UserInfoKey {
        static let products = "p"
    }
    
    static let earnProductsDidUpdateNotification = Notification.Name("one.mixin.messenger.RefreshEarnProduct.Update")
    
    private let notificationQueue: DispatchQueue
    
    init(notificationQueue: DispatchQueue) {
        self.notificationQueue = notificationQueue
        super.init()
    }
    
    override func getJobId() -> String {
        "refresh-earn-products"
    }
    
    override func execute() -> Bool {
        EarnAPI.productions(queue: notificationQueue) { result in
            switch result {
            case .success(let products):
                PropertiesDAO.shared.set(jsonObject: products, forKey: .earnProducts)
                NotificationCenter.default.post(
                    name: Self.earnProductsDidUpdateNotification,
                    object: self,
                    userInfo: [UserInfoKey.products: products]
                )
            case .failure(let error):
                Logger.general.debug(category: "RefreshEarnProductJob", message: "\(error)")
            }
            self.finishJob()
        }
        return true
    }
    
}
