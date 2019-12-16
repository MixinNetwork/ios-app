import Foundation
import Alamofire
import UIKit
import Bugsnag

class BaseJob: Operation {

    internal var currentAccountId: String {
        return AccountAPI.shared.accountUserId
    }
    internal let jsonDecoder = JSONDecoder()
    internal let jsonEncoder = JSONEncoder()

    func getJobId() -> String {
        fatalError("Subclasses must implement `getJobId`.")
    }

    override func main() {
        guard AccountAPI.shared.didLogin, !isCancelled else {
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
        } while AccountAPI.shared.didLogin && !isCancelled
    }

    internal func checkNetworkAndWebSocket() {
        if requireNetwork() {
            while AccountAPI.shared.didLogin && !NetworkManager.shared.isReachable {
                Thread.sleep(forTimeInterval: 3)
            }
        }
        if requireWebSocket() {
            while AccountAPI.shared.didLogin && !WebSocketService.shared.isConnected {
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

