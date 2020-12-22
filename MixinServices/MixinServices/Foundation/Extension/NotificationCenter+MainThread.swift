import UIKit

public extension NotificationCenter {
    
    func post(onMainThread name: NSNotification.Name, object: Any?, userInfo: [AnyHashable : Any]? = nil) {
        if Thread.isMainThread {
            post(name: name, object: object, userInfo: userInfo)
        } else {
            DispatchQueue.main.async {
                self.post(name: name, object: object, userInfo: userInfo)
            }
        }
    }
    
}
