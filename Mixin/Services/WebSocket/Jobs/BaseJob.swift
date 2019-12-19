import Foundation
import Alamofire
import UIKit

class BaseJob: Operation {

    internal var currentAccountId: String {
        return myUserId
    }
    internal let jsonDecoder = JSONDecoder()
    internal let jsonEncoder = JSONEncoder()

    func getJobId() -> String {
        fatalError("Subclasses must implement `getJobId`.")
    }

    override func main() {
        guard isLoggedIn, !isCancelled else {
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
        } while isLoggedIn && !isCancelled
    }

    internal func checkNetworkAndWebSocket() {
        if requireNetwork() {
            while isLoggedIn && !NetworkManager.shared.isReachable {
                Thread.sleep(forTimeInterval: 3)
            }
        }
        if requireWebSocket() {
            while isLoggedIn && !WebSocketService.shared.isConnected {
                Thread.sleep(forTimeInterval: 3)
            }
        }
    }

    func run() throws {

    }

    func requireWebSocket() -> Bool {
        return false
    }

    func requireNetwork() -> Bool {
        return true
    }
}

