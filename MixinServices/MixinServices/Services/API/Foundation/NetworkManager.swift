import Foundation
import Alamofire

public enum ReachabilityManger {
    
    public static let reachabilityDidChangeNotification = NSNotification.Name("one.mixin.services.ReachabilityManger.ReachabilityDidChange")
    
    private static let manager = NetworkReachabilityManager()
    
    public static var isReachable: Bool {
        manager?.isReachable ?? false
    }
    
    public static var isReachableOnEthernetOrWiFi: Bool {
        manager?.isReachableOnEthernetOrWiFi ?? false
    }
    
    public static func startListening() {
        manager?.startListening(onQueue: .main, onUpdatePerforming: { (status) in
            NotificationCenter.default.post(name: Self.reachabilityDidChangeNotification, object: nil)
        })
    }
    
    public static func stopListening() {
        manager?.stopListening()
    }
    
}
