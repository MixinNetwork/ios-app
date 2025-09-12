import Foundation

public struct ExternalTransfer {
    
    public enum Identifier {
        case assetID(String)
        case assetKey(String)
    }
    
    private static let supportedAssetIDs = [
        "bitcoin"   : AssetID.btc,
        "ethereum"  : AssetID.eth,
        "litecoin"  : AssetID.ltc,
        "dash"      : AssetID.dash,
        "dogecoin"  : AssetID.doge,
        "monero"    : AssetID.xmr,
        "solana"    : AssetID.sol,
    ]
    
    private static let chainIDs = [
        "1"   : ChainID.ethereum,
        "137" : ChainID.polygon,
    ]
    
    public let chainID: String
    public let tokenID: Identifier
    public let destination: String
    public let memo: String?
    
    private let atomicAmount: Decimal?
    private let decimalAmount: Decimal?
    
    public init(string raw: String) throws {
        guard let components = URLComponents(string: raw) else {
            throw TransferLinkError.notTransferLink
        }
        guard let scheme = components.scheme?.lowercased() else {
            throw TransferLinkError.notTransferLink
        }
        guard let schemeAssetID = Self.supportedAssetIDs[scheme] else {
            // Drop schemes which are not listed in `supportedAssetIds`
            throw TransferLinkError.notTransferLink
        }
        let queries: [String: String]
        if let queryItems = components.queryItems {
            queries = queryItems.reduce(into: [:]) { queries, item in
                queries[item.name] = item.value
            }
        } else {
            queries = [:]
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
            let evmChainID: String
            if let range = Range(match.range(at: 2), in: path) {
                evmChainID = String(path[range])
            } else {
                evmChainID = "1"
            }
            
            let arbitraryAmount: Decimal?
            if let amount = queries["amount"], let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) {
                arbitraryAmount = decimalAmount
            } else {
                arbitraryAmount = nil
            }
            
            guard let chainID = Self.chainIDs[evmChainID] else {
                throw TransferLinkError.invalidFormat
            }
            self.chainID = chainID
            if let reqAsset = queries["req-asset"] {
                self.tokenID = .assetKey(reqAsset)
                self.atomicAmount = if let amount = parameters["uint256"] {
                    Decimal(string: amount, locale: .enUSPOSIX)
                } else{
                    nil
                }
                self.decimalAmount = arbitraryAmount
                self.destination = targetAddress
            } else if let range = Range(match.range(at: 3), in: path) {
                // ERC-20 Tokens
                let functionName = String(path[range])
                guard functionName == "transfer", let receiverAddress = parameters["address"] else {
                    throw TransferLinkError.invalidFormat
                }
                self.tokenID = .assetKey(targetAddress)
                self.atomicAmount = if let amount = parameters["uint256"] {
                    Decimal(string: amount, locale: .enUSPOSIX)
                } else{
                    nil
                }
                self.decimalAmount = arbitraryAmount
                self.destination = receiverAddress
            } else {
                // Native token
                self.tokenID = .assetID(chainID)
                let atomicAmount: Decimal? = if let amount = parameters["value"] {
                    Decimal(string: amount, locale: .enUSPOSIX)
                } else{
                    nil
                }
                let decimalAmount: Decimal? = if let atomicAmount {
                    Self.resolve(atomicAmount: atomicAmount, with: 18)
                } else {
                    nil
                }
                self.atomicAmount = atomicAmount
                self.decimalAmount = arbitraryAmount ?? decimalAmount
                self.destination = targetAddress
            }
        } else {
            self.chainID = schemeAssetID
            if scheme == "solana", let key = queries["spl-token"] {
                self.tokenID = .assetKey(key)
            } else {
                self.tokenID = .assetID(schemeAssetID)
            }
            self.destination = components.path
            self.atomicAmount = nil
            self.decimalAmount = if let amount = queries["amount"] ?? queries["tx_amount"], !amount.contains("e") {
                Decimal(string: amount, locale: .enUSPOSIX)
            } else {
                nil
            }
        }
        self.memo = {
            let memo = queries["memo"]
            if let decoded = memo?.removingPercentEncoding {
                return decoded
            } else {
                return memo
            }
        }()
    }
    
    public init(payment: LightningPaymentResponse) throws {
        guard payment.status.knownCase != .paid else {
            throw TransferLinkError.alreadyPaid
        }
        self.chainID = ChainID.lightning
        self.tokenID = .assetID(payment.asset.assetID)
        self.atomicAmount = nil
        self.decimalAmount = Decimal(string: payment.amount, locale: .enUSPOSIX)
        self.destination = payment.destination
        self.memo = nil
    }
    
    public func decimalAmount(precision: () async throws -> Int) async throws -> Decimal? {
        var amount = decimalAmount
        if let atomicAmount {
            let precision = try await precision()
            let resolvedAmount = ExternalTransfer.resolve(atomicAmount: atomicAmount, with: precision)
            if let amount {
                guard amount == resolvedAmount else {
                    throw TransferLinkError.mismatchedAmount
                }
            } else {
                amount = resolvedAmount
            }
        }
        return amount
    }
    
}

extension ExternalTransfer {
    
    public static func isDecodable(raw: String) -> Bool {
        if isLightningAddress(string: raw) {
            true
        } else if let scheme = URLComponents(string: raw)?.scheme?.lowercased() {
            supportedAssetIDs[scheme] != nil
        } else {
            false
        }
    }
    
    public static func isLightningAddress(string: String) -> Bool {
        let lowercased = string.lowercased()
        if lowercased.hasPrefix("bitcoin") {
            guard let queryItems = URLComponents(string: string)?.queryItems else {
                return false
            }
            for item in queryItems {
                guard let value = item.value, !value.isEmpty else {
                    continue
                }
                if item.name == "lightning" || item.name == "lno" {
                    return true
                } else {
                    continue
                }
            }
            return false
        } else if ["lnbc", "lno", "lnurl", "lightning:"].contains(where: lowercased.hasPrefix(_:)) {
            return true
        } else {
            return false
        }
    }
    
    private static func resolve(atomicAmount: Decimal, with exponent: Int) -> Decimal {
        let divisor: Decimal = pow(10, exponent)
        return atomicAmount / divisor
    }
    
}
