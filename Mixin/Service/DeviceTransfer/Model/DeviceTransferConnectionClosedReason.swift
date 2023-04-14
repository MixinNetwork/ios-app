import Foundation

enum DeviceTransferConnectionClosedReason {
    
    case mismatchedUserId
    case mismatchedCode
    case exception(Error)
    case completed
    
}
