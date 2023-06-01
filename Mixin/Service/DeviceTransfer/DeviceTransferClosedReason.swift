import Foundation

enum DeviceTransferClosedReason {
    case transferFinished
    case importFinished
    case exception(DeviceTransferError)
}
