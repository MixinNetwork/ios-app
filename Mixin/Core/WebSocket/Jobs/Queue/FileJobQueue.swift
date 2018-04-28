import Foundation
import UIKit

class FileJobQueue: JobQueue {

    static let shared = FileJobQueue()

    init() {
        super.init(maxConcurrentOperationCount: 1)
    }

}

