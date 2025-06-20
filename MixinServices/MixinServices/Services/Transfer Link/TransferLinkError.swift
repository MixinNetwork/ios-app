import Foundation

public enum TransferLinkError: Error {
    case notTransferLink
    case invalidFormat
    case assetNotFound
    case alreadyPaid
    case requestError(Error)
    case mismatchedAmount
}
