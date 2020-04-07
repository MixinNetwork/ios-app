import Foundation
import MixinServices
import WCDBSwift

extension CircleDAO {
    
    static let circleDidChangeNotification = Notification.Name("one.mixin.messenger.circle.did_change")
    
    func insertOrReplace(circle: CircleResponse) {
        let circle = Circle(circleId: circle.circleId, name: circle.name, createdAt: circle.createdAt)
        MixinDatabase.shared.insertOrReplace(objects: [circle])
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.circleDidChangeNotification, object: self)
        }
    }
    
}
