import Foundation
import UIKit

class UploaderQueue: JobQueue {

    static let shared = UploaderQueue()

    init() {
        super.init(maxConcurrentOperationCount: 1)
    }

}

