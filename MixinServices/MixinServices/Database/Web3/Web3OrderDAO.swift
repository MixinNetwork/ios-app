import Foundation
import GRDB

public final class Web3OrderDAO: Web3DAO {
    
    public static let shared = Web3OrderDAO()
    
    public static let didSaveNotification = Notification.Name("one.mixin.service.Web3OrderDAO.Save")
    public static let ordersUserInfoKey = "o"
    
    public func order(id: String) -> SwapOrder? {
        db.select(with: "SELECT * FROM orders WHERE order_id = ?", arguments: [id])
    }
    
    public func orderExists(orderID: String) -> Bool {
        db.recordExists(in: SwapOrder.self, where: SwapOrder.column(of: .orderID) == orderID)
    }
    
    public func save(orders: [SwapOrder]) {
        db.save(orders) { _ in
            NotificationCenter.default.post(
                onMainThread: Self.didSaveNotification,
                object: self,
                userInfo: [Self.ordersUserInfoKey: orders]
            )
        }
    }
    
}
