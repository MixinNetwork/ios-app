import Foundation

public struct ExternalTransfer {
    
    private static let supportedAssetIds = [
        "bitcoin"   : AssetID.btc,
        "ethereum"  : AssetID.eth,
        "litecoin"  : AssetID.ltc,
        "dash"      : AssetID.dash,
        "dogecoin"  : AssetID.doge,
        "monero"    : AssetID.xmr,
        "solana"    : AssetID.sol,
    ]
    
    private static let chainIds = [
        "1"   : ChainID.ethereum,
        "137" : ChainID.polygon,
    ]
    
    public let raw: String
    public let assetID: String
    public var destination: String
    
    // Raw amount provided by string. For Ethereum this amount is
    // in atomic units, for other chains this is in decimal
    public var amount: Decimal
    
    // Decimal amount resolved with decimal value of atomic unit.
    // Will be nil for ERC-20 tokens due to lack of the atomic value.
    public var resolvedAmount: Decimal?
    
    // Some non-standard ethereum URLs specify an amount in decimal.
    public let arbitraryAmount: Decimal?
    
    public let memo: String?
    
    public let isLightining: Bool
    
    public init(
        string raw: String,
        assetIDFinder: (String) -> String? = TokenDAO.shared.assetID(assetKey:)
    ) throws {
        guard !raw.isLightningAddress else {
            self.raw = raw
            self.assetID = AssetID.lighting
            self.destination = raw
            self.amount = 0
            self.resolvedAmount = 0
            self.arbitraryAmount = nil
            self.memo = nil
            self.isLightining = true
            return
        }
        guard let components = URLComponents(string: raw) else {
            throw TransferLinkError.notTransferLink
        }
        guard let scheme = components.scheme, let queryItems = components.queryItems else {
            throw TransferLinkError.notTransferLink
        }
        guard let schemeAssetID = Self.supportedAssetIds[scheme] else {
            // Drop schemes which are not listed in `supportedAssetIds`
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
                    self.resolvedAmount = arbitraryAmount
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
                    self.resolvedAmount = arbitraryAmount
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
                    self.resolvedAmount = arbitraryAmount
                } else {
                    throw TransferLinkError.invalidFormat
                }
                self.assetID = assetID
                self.destination = targetAddress
            }
            
            self.raw = raw
            self.arbitraryAmount = arbitraryAmount
            self.memo = nil
        } else {
            let assetID: String? = if scheme == "solana", let key = queries["spl-token"] {
                assetIDFinder(key)
            } else {
                schemeAssetID
            }
            guard let assetID else {
                throw TransferLinkError.assetNotFound
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
            self.resolvedAmount = decimalAmount
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
        self.isLightining = false
    }
    
    public static func resolve(atomicAmount: Decimal, with exponent: Int) -> Decimal {
        let divisor: Decimal = pow(10, exponent)
        return atomicAmount / divisor
    }
    
}

fileprivate extension String {
    
    var isLightningAddress: Bool {
        let lowerAddress = self.lowercased()
        if lowerAddress.hasPrefix("bitcoin") {
            guard let components = URLComponents(string: self) else {
                return false
            }
            guard let queryItems = components.queryItems else {
                return false
            }
            let queries = queryItems.reduce(into: [:]) { queries, item in
                queries[item.name] = item.value
            }
            
            guard !queries["lightning"].isNilOrEmpty || !queries["lno"].isNilOrEmpty else {
                return false
            }
            return true
        } else if ["lnbc", "lno", "lnurl", "lightning:"].contains(where: lowerAddress.hasPrefix(_:)) {
            return true
        }
        return false
    }
}
