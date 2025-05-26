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
    public let destination: String
    
    // Raw amount provided by string. For Ethereum this amount is
    // in atomic units, for other chains this is in decimal
    public let amount: Decimal
    
    public let memo: String?
    
    public init(
        string raw: String,
        assetIDFinder: (String) -> String? = TokenDAO.shared.assetID(assetKey:),
        resolveAmount: (String, Decimal) async throws -> Decimal = { (assetID, amount) in
            let precision = try await AssetAPI.assetPrecision(assetID: assetID).precision
            return ExternalTransfer.resolve(atomicAmount: amount, with: precision)
        },
    ) async throws {
        guard let components = URLComponents(string: raw) else {
            throw TransferLinkError.notTransferLink
        }
        guard let scheme = components.scheme?.lowercased() else {
            throw TransferLinkError.notTransferLink
        }
        guard let schemeAssetID = Self.supportedAssetIds[scheme] else {
            // Drop schemes which are not listed in `supportedAssetIds`
            throw TransferLinkError.notTransferLink
        }
        let queries = (components.queryItems ?? []).reduce(into: [:]) { queries, item in
            queries[item.name] = item.value
        }
        
        self.raw = raw
        
        let memo = queries["memo"]
        self.memo = if let decoded = memo?.removingPercentEncoding {
            decoded
        } else {
            memo
        }
        
        if Self.isLightningAddress(string: raw) {
            do {
                let payment = try await PaymentAPI.payments(lightningPayment: raw)
                if payment.status.knownCase == .paid {
                    throw TransferLinkError.alreadyPaid
                } else {
                    self.assetID = payment.asset.assetID
                    self.destination = payment.destination
                    self.amount = Decimal(string: payment.amount, locale: .enUSPOSIX) ?? 0
                }
            } catch {
                switch error {
                case TransferLinkError.alreadyPaid:
                    throw error
                default:
                    throw TransferLinkError.requestError(error)
                }
            }
        } else if scheme == "ethereum" {
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
            
            let arbitraryAmount: Decimal
            if let amount = queries["amount"], let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) {
                arbitraryAmount = decimalAmount
            } else {
                arbitraryAmount = 0
            }
            
            if let reqAsset = queries["req-asset"] {
                guard let assetID = assetIDFinder(reqAsset) else {
                    throw TransferLinkError.assetNotFound
                }
                self.assetID = assetID
                self.destination = targetAddress
                if let amount = parameters["uint256"], let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) {
                    self.amount = try await resolveAmount(assetID, decimalAmount)
                } else {
                    self.amount = arbitraryAmount
                }
            } else if let range = Range(match.range(at: 3), in: path) {
                // ERC-20 Tokens
                let functionName = String(path[range])
                guard functionName == "transfer", let address = parameters["address"] else {
                    throw TransferLinkError.invalidFormat
                }
                guard let assetID = assetIDFinder(targetAddress) else {
                    throw TransferLinkError.assetNotFound
                }
                self.assetID = assetID
                self.destination = address
                if let amount = parameters["uint256"], let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) {
                    self.amount = try await resolveAmount(assetID, decimalAmount)
                } else {
                    self.amount = arbitraryAmount
                }
            } else {
                // ETH the native token
                guard let assetID = Self.chainIds[chainID] else {
                    throw TransferLinkError.invalidFormat
                }
                self.assetID = assetID
                self.destination = targetAddress
                if let amount = parameters["value"], let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) {
                    self.amount = Self.resolve(atomicAmount: decimalAmount, with: 18)
                } else {
                    self.amount = arbitraryAmount
                }
            }
        } else {
            let assetID: String? = if scheme == "solana", let key = queries["spl-token"] {
                assetIDFinder(key)
            } else {
                schemeAssetID
            }
            guard let assetID else {
                throw TransferLinkError.assetNotFound
            }
            
            if let amount = queries["amount"] ?? queries["tx_amount"], !amount.contains("e") {
                guard let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) else {
                    throw TransferLinkError.invalidFormat
                }
                self.amount = decimalAmount
            } else {
                self.amount = 0
            }
            self.assetID = assetID
            self.destination = components.path
        }
    }
    
    private init(
        raw: String, assetID: String, destination: String, amount: Decimal,
        resolvedAmount: Decimal?, arbitraryAmount: Decimal?, memo: String?
    ) {
        self.raw = raw
        self.assetID = assetID
        self.destination = destination
        self.amount = amount
        self.memo = memo
    }
    
    public static func resolve(atomicAmount: Decimal, with exponent: Int) -> Decimal {
        let divisor: Decimal = pow(10, exponent)
        return atomicAmount / divisor
    }
    
    private static func isLightningAddress(string: String) -> Bool {
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
    
    public static func isWithdrawalLink(raw: String) -> Bool {
        guard let components = URLComponents(string: raw) else {
            return false
        }
        guard let scheme = components.scheme?.lowercased() else {
            return false
        }
        return Self.isLightningAddress(string: raw) || Self.supportedAssetIds[scheme] != nil
    }
}
