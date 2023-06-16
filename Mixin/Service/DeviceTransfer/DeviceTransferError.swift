import Foundation

enum DeviceTransferError: Error {
    case remoteComplete
    case mismatchedConnection
    case encrypt(Error)
    case mismatchedHMAC(local: Data, remote: Data)
    case connectionFailed(Error)
    case receiveFile(Error)
    case importing(DeviceTransferMessageProcessor.ProcessingError)
}
