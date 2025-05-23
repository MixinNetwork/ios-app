import Foundation

public enum TransferLinkError: Error {
    case notTransferLink
    case invalidFormat
    case missingAssetKey
    case assetNotFound
    case alreadyPaid
    case requestError(Error)
}
