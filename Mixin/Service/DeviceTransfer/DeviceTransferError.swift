import Foundation

enum DeviceTransferError: Error {
    case remoteComplete
    case mismatchedConnection
    case checksumError(local: UInt64, remote: UInt64)
    case failed(Error)
}
