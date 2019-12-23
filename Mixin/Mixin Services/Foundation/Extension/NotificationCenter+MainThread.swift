import UIKit

public extension NotificationCenter {

    func postOnMain(name: NSNotification.Name, object: Any? = nil) {
        if Thread.isMainThread {
            post(name: name, object: object)
        } else {
            DispatchQueue.main.async {
                self.post(name: name, object: object)
            }
        }
    }

    func afterPostOnMain(deadline: DispatchTime = .now() + 0.2, name: NSNotification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            self.post(name: name, object: object, userInfo: userInfo)
        }
    }

}
