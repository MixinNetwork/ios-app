import Foundation

enum DeviceTransferClosedReason {
    case finished
    case exception(DeviceTransferError)
}
