import Foundation

public struct ExternalTransfer {
    
    private static let supportedAssetIds = [
        "bitcoin"   : "c6d0c728-2624-429b-8e0d-d9d19b6592fa",
        "ethereum"  : "43d61dcd-e413-450d-80b8-101d5e903357",
        "litecoin"  : "76c802a2-7c88-447f-a93e-c29c9e5dd9c8",
        "dash"      : "6472e7e3-75fd-48b6-b1dc-28d294ee1476",
        "dogecoin"  : "6770a1e5-6086-44d5-b60f-545f9d9e8ffd",
        "monero"    : "05c5ac01-31f9-4a69-aa8a-ab796de1d041",
        "solana"    : "64692c23-8971-4cf4-84a7-4dd1271dd887",
    ]
    
    private static let chainIds = [
        "1"   : "43d61dcd-e413-450d-80b8-101d5e903357",
        "137" : "b7938396-3f94-4e0a-9179-d3440718156f",
    ]
    
    public let raw: String
    public let assetID: String
    public let destination: String
    
    // Raw amount provided by string. For Ethereum this amount is
    // in atomic units, for other chains this is in decimal
    public let amount: Decimal
    
    // Decimal amount resolved with decimal value of atomic unit.
    // Will be nil for ERC-20 tokens due to lack of the atomic value.
    public let resolvedAmount: String?
    
    // Some non-standard ethereum URLs specify an amount in decimal.
    public let arbitraryAmount: String?
    
    public let memo: String?
    
    public init(string raw: String, assetIDFinder: (String) -> String? = AssetDAO.shared.getAssetIdByAssetKey(_:)) throws {
        guard let components = URLComponents(string: raw) else {
            throw TransferLinkError.notTransferLink
        }
        guard let scheme = components.scheme, let queryItems = components.queryItems else {
            throw TransferLinkError.notTransferLink
        }
        let queries = queryItems.reduce(into: [:]) { queries, item in
            queries[item.name] = item.value
        }
        if scheme == "ethereum" {
            // https://eips.ethereum.org/EIPS/eip-681
            // schema_prefix target_address [ "@" chain_id ] [ "/" function_name ] [ "?" parameters ]
            
            let pathRegex = try NSRegularExpression(pattern: #"^(?:pay-)?([^@\/]+)(?:@([^\/]+))?(?:\/(.+))?"#)
            let parameters = queries
            let path = components.path
            let range = NSRange(path.startIndex..<path.endIndex, in: path)
            guard let match = pathRegex.firstMatch(in: path, range: range), match.numberOfRanges == 4 else {
                throw TransferLinkError.invalidFormat
            }
            
            let targetAddress: String
            if let range = Range(match.range(at: 1), in: path) {
                targetAddress = String(path[range])
            } else {
                throw TransferLinkError.invalidFormat
            }
            
            // https://eips.ethereum.org/EIPS/eip-681
            // `chain_id` is optional and contains the decimal chain ID, such that transactions
            // on various test- and private networks can be requested. If no `chain_id` is
            // present, the client’s current network setting remains effective.
            let chainID: String
            if let range = Range(match.range(at: 2), in: path) {
                chainID = String(path[range])
            } else {
                chainID = "1"
            }
            
            let arbitraryAmount: Decimal?
            if let amount = queries["amount"], let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) {
                arbitraryAmount = decimalAmount
            } else {
                arbitraryAmount = nil
            }
            
            if let reqAsset = queries["req-asset"] {
                guard let assetID = assetIDFinder(reqAsset) else {
                    throw TransferLinkError.assetNotFound
                }
                if let amount = parameters["uint256"], let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) {
                    self.amount = decimalAmount
                    self.resolvedAmount = nil
                } else if let arbitraryAmount {
                    self.amount = arbitraryAmount
                    self.resolvedAmount = arbitraryAmount.description
                } else {
                    throw TransferLinkError.invalidFormat
                }
                self.assetID = assetID
                self.destination = targetAddress
            } else if let range = Range(match.range(at: 3), in: path) {
                // ERC-20 Tokens
                let functionName = String(path[range])
                guard functionName == "transfer", let address = parameters["address"] else {
                    throw TransferLinkError.invalidFormat
                }
                guard let assetID = assetIDFinder(targetAddress) else {
                    throw TransferLinkError.assetNotFound
                }
                if let amount = parameters["uint256"], let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) {
                    self.amount = decimalAmount
                    self.resolvedAmount = nil
                } else if let arbitraryAmount {
                    self.amount = arbitraryAmount
                    self.resolvedAmount = arbitraryAmount.description
                } else {
                    throw TransferLinkError.invalidFormat
                }
                self.assetID = assetID
                self.destination = address
            } else {
                // ETH the native token
                guard let assetID = Self.chainIds[chainID] else {
                    throw TransferLinkError.invalidFormat
                }
                if let amount = parameters["value"], let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) {
                    self.amount = decimalAmount
                    self.resolvedAmount = Self.resolve(atomicAmount: decimalAmount, with: 18)
                } else if let arbitraryAmount {
                    self.amount = arbitraryAmount
                    self.resolvedAmount = arbitraryAmount.description
                } else {
                    throw TransferLinkError.invalidFormat
                }
                self.assetID = assetID
                self.destination = targetAddress
            }
            
            self.raw = raw
            self.arbitraryAmount = arbitraryAmount?.description
            self.memo = nil
        } else {
            guard let assetID = Self.supportedAssetIds[scheme] else {
                throw TransferLinkError.notTransferLink
            }
            if scheme == "solana", queries["spl-token"] != nil {
                throw TransferLinkError.invalidFormat
            }
            guard let amount = queries["amount"] ?? queries["tx_amount"], !amount.contains("e") else {
                throw TransferLinkError.invalidFormat
            }
            guard let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) else {
                throw TransferLinkError.invalidFormat
            }
            self.raw = raw
            self.assetID = assetID
            self.destination = components.path
            self.amount = decimalAmount
            self.resolvedAmount = decimalAmount.description
            self.arbitraryAmount = nil
            self.memo = {
                let memo = queries["memo"]
                if let decoded = memo?.removingPercentEncoding {
                    return decoded
                } else {
                    return memo
                }
            }()
        }
    }
    
    public static func resolve(atomicAmount: Decimal, with exponent: Int) -> String {
        let divisor: Decimal = pow(10, exponent)
        return (atomicAmount / divisor).description
    }
    
}
