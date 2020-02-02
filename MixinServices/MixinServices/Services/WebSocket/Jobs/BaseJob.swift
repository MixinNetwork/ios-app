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
                
                guard let err = error as? APIError, err.isClientError || err.isServerError else {
                    return
                }
                Thread.sleep(forTimeInterval: 2)
            }
        } while LoginManager.shared.isLoggedIn && !isCancelled
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
        if requireNetwork() {
            while LoginManager.shared.isLoggedIn && !NetworkManager.shared.isReachable {
                Thread.sleep(forTimeInterval: 3)
            }
        }
        if requireWebSocket() {
            while LoginManager.shared.isLoggedIn && !WebSocketService.shared.isConnected {
                Thread.sleep(forTimeInterval: 3)
            }
        }
    }
    
}
