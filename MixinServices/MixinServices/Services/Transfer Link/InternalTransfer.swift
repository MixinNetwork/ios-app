import Foundation

public struct InternalTransfer {
    
    private static let supportedSchemes: Set<String> = [
        "https", "mixin",
        "bitcoin", "bitcoincash", "bitcoinsv", "ethereum", "litecoin",
        "dash", "ripple", "zcash", "horizen", "monero", "binancecoin",
        "stellar", "dogecoin", "mobilecoin"
    ]
    
    // All `ID`s are guranteed to be a valid UUID string, though one may refers to
    // an invalid object. The validation of the referred object could be done by
    // some API access later.
    // `traceID` will be auto generated if absent.
    public let recipientID: String
    public let assetID: String
    public let traceID: String
    
    // `amount` is guaranteed to be a generic decimal number string
    public let amount: String
    
    public let memo: String?
    
    public init(string raw: String) throws {
        guard let components = URLComponents(string: raw) else {
            throw TransferLinkError.notTransferLink
        }
        guard let scheme = components.scheme, Self.supportedSchemes.contains(scheme) else {
            throw TransferLinkError.notTransferLink
        }
        guard let queryItems = components.queryItems else {
            throw TransferLinkError.notTransferLink
        }
        let queries = queryItems.reduce(into: [:]) { queries, item in
            queries[item.name] = item.value
        }
        guard let recipientID = queries["recipient"], let assetID = queries["asset"] else {
            throw TransferLinkError.notTransferLink
        }
        guard
            UUID.isValidUUIDString(recipientID),
            UUID.isValidUUIDString(assetID),
            let amount = queries["amount"],
            !amount.isEmpty,
            amount.isGenericNumber,
            AmountFormatter.isValid(amount)
        else {
            throw TransferLinkError.invalidFormat
        }
        let traceID = {
            if let id = queries["trace"], UUID.isValidUUIDString(id) {
                return id
            } else {
                return UUID().uuidString
            }
        }()
        let memo: String? = {
            let memo = queries["memo"]
            if let decoded = memo?.removingPercentEncoding {
                return decoded
            } else {
                return memo
            }
        }()
        
        self.recipientID = recipientID.lowercased()
        self.assetID = assetID.lowercased()
        self.traceID = traceID.lowercased()
        self.amount = amount
        self.memo = memo
    }
    
}
