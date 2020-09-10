import Foundation
import Alamofire
import UIKit

open class BaseJob: Operation {
    
    public var currentAccountId: String {
        return myUserId
    }
    
    open func getJobId() -> String {
        fatalError("Subclasses must implement `getJobId`.")
    }
    
    override open func main() {
        guard LoginManager.shared.isLoggedIn, !isCancelled else {
            return
        }
        repeat {
            do {
                try run()
                return
            } catch {
                guard !isCancelled else {
                    return
                }
                
                checkNetworkAndWebSocket()
                
                guard let err = error as? MixinAPIError, err.worthRetrying else {
                    return
                }
            }
        } while LoginManager.shared.isLoggedIn && !MixinService.isStopProcessMessages && !isCancelled
    }
    
    open func run() throws {
        
    }
    
    open func requireWebSocket() -> Bool {
        return false
    }
    
    open func requireNetwork() -> Bool {
        return true
    }
    
    public func checkNetworkAndWebSocket() {
        if requireNetwork() && requireWebSocket() {
            repeat {
                Thread.sleep(forTimeInterval: 2)
            } while LoginManager.shared.isLoggedIn && (!ReachabilityManger.shared.isReachable || !WebSocketService.shared.isConnected)
        } else if requireNetwork() {
            repeat {
                Thread.sleep(forTimeInterval: 2)
            } while LoginManager.shared.isLoggedIn && !ReachabilityManger.shared.isReachable
        } else if requireWebSocket() {
            repeat {
                Thread.sleep(forTimeInterval: 2)
            } while LoginManager.shared.isLoggedIn && !WebSocketService.shared.isConnected
        }
    }
    
}
