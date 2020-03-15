import Foundation
import UIKit

public class ConcurrentJobQueue: JobQueue {

    public static let shared = ConcurrentJobQueue()

    init() {
        super.init(maxConcurrentOperationCount: 6)
    }

}
