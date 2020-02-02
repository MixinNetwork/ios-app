import Foundation

public extension OperationQueue {

    convenience init(maxConcurrentOperationCount: Int) {
        self.init()
        self.maxConcurrentOperationCount = maxConcurrentOperationCount
    }

}
