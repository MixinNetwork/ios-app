import UIKit

class DataMessageViewModel: CardMessageViewModel, ProgressInspectableMessageViewModel {

    var progress: Double?
    
    var mediaStatus: String? {
        get {
            return message.mediaStatus
        }
        set {
            if newValue != MediaStatus.PENDING.rawValue {
                progress = nil
            }
            message.mediaStatus = newValue
        }
    }
    
    override var size: CGSize {
        return CGSize(width: 280, height: 72)
    }
    
}
