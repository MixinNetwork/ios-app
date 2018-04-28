import Foundation
import SocketRocket
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
        guard AccountAPI.shared.didLogin else {
            return
        }
        if canCancel() && isCancelled {
            return
        }
        
        do {
            try run()
        } catch {
            #if DEBUG
                print("======BaseJob...error:\(error)...\(getJobId())")
            #endif
            checkNetworkAndWebSocket()

            guard canTryAgain(error: error) else {
                return
            }

            Thread.sleep(forTimeInterval: 2)
            main()
        }
    }

    internal func checkNetworkAndWebSocket() {
        if requireNetwork() {
            while AccountAPI.shared.didLogin && !NetworkManager.shared.isReachable {
                Thread.sleep(forTimeInterval: 3)
            }
        }
        if requireWebSocket() {
            while AccountAPI.shared.didLogin && !WebSocketService.shared.connected {
                Thread.sleep(forTimeInterval: 3)
            }
        }
    }

    func run() throws {

    }

    internal func canTryAgain(error: Error) -> Bool {
        let err = (error as? JobError) ?? JobError.instance(code: error.errorCode)
        guard shouldRetry(error: err) else {
            return false
        }
        return true
    }

    func shouldRetry(error: JobError) -> Bool {
        switch error {
        case .networkError, .timeoutError, .serverError(_):
            return true
        case .clientError(_):
            return false
        }
    }

    func requireWebSocket() -> Bool {
        return false
    }

    func requireNetwork() -> Bool {
        return true
    }

    func canCancel() -> Bool {
        return true
    }
}

enum JobError: Error {
    case networkError
    case serverError(code: Int)
    case clientError(code: Int)
    case timeoutError

    static func instance(code: Int) -> JobError {
        switch code {
        case 400..<500:
            return .clientError(code: code)
        case 500..<600:
            return .serverError(code: code)
        default:
            return .networkError
        }
    }
}
