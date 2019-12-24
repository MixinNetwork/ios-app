import Foundation
import UIKit

public class UploaderQueue: JobQueue {
    
    public static let shared = UploaderQueue()
    
    internal init() {
        super.init(maxConcurrentOperationCount: 1)
    }
    
}
