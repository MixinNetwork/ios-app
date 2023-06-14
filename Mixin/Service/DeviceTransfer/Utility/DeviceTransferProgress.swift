import Foundation

struct DeviceTransferProgress {
    
    // NSProgress rounds `fractionCompleted` as binary, which may not be as
    // expected from the view of decimal progress
    // e.g. when `totalUnitCount` is `.max / 100`, and `completedUnitCount`
    // is `(.max / 100) - 1`, the `fractionCompleted` will be 1.0, which may
    // be considered as finished, or leads to misunderstanding
    
    var totalUnitCount: Int64
    var completedUnitCount: Int64
    
    var fractionCompleted: Float {
        if totalUnitCount == 0 {
            return 0
        } else {
            // Currently provides 4 digits for precision, that is 0.01% ~ 100.0%
            return Float(completedUnitCount * 10000 / totalUnitCount) / 10000
        }
    }
    
    init(totalUnitCount: Int64 = 0, completedUnitCount: Int64 = 0) {
        self.totalUnitCount = 0
        self.completedUnitCount = 0
    }
    
}

extension DeviceTransferProgress: CustomStringConvertible {
    
    var description: String {
        "<DeviceTransferProgress: \(completedUnitCount)/\(totalUnitCount)>"
    }
    
}
