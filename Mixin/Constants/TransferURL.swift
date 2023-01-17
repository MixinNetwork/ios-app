import Foundation
import MixinServices

enum TransferURL {
    
    private static let mixinTransferSupportedAssets = ["bitcoin:", "bitcoincash:", "bitcoinsv:", "ethereum:", "litecoin:", "dash:", "ripple:", "zcash:", "horizen:", "monero:", "binancecoin:", "stellar:", "dogecoin:", "mobilecoin:"]
    
    private static let externalTransferEthereumChainIds: [String: String] = [
        "1": "43d61dcd-e413-450d-80b8-101d5e903357"
    ]
    
    private static let externalTransferSupportedAssetChainIds: [String: String] = [
        "bitcoin:"   : "c6d0c728-2624-429b-8e0d-d9d19b6592fa",
        "ethereum:"  : "43d61dcd-e413-450d-80b8-101d5e903357",
        "litecoin:"  : "76c802a2-7c88-447f-a93e-c29c9e5dd9c8",
        "dash:"      : "6472e7e3-75fd-48b6-b1dc-28d294ee1476",
        "dogecoin:"  : "6770a1e5-6086-44d5-b60f-545f9d9e8ffd",
        "monero:"    : "05c5ac01-31f9-4a69-aa8a-ab796de1d041",
        "solana:"    : "64692c23-8971-4cf4-84a7-4dd1271dd887",
    ]
    
    case mixin(queries: [String: String])
    case external(amount: String, assetId: String, destination: String, needsCheckPrecision: Bool, tag: String?)
    
    init?(string: String) {
        if Self.mixinTransferSupportedAssets.contains(where: string.lowercased().hasPrefix),
           let queries = URLComponents(string: string)?.getKeyVals(),
           let recipientId = queries["recipient"]?.lowercased(), let assetId = queries["asset"]?.lowercased(),
           !recipientId.isEmpty && UUID(uuidString: recipientId) != nil && !assetId.isEmpty && UUID(uuidString: assetId) != nil {
            self = .mixin(queries: queries)
        } else {
            guard let chain = Self.externalTransferSupportedAssetChainIds.keys.first(where: string.hasPrefix) else {
                return nil
            }
            var transferString = string
            if !transferString[chain.endIndex...].hasPrefix("//") {
                transferString.insert(contentsOf: "//", at: chain.endIndex)
            }
            guard let components = URLComponents(string: transferString), let host = components.host else {
                return nil
            }
            let amount: String
            let assetId: String
            let destination: String
            let needsCheckPrecision: Bool
            let queries = components.getKeyVals()
            if chain == "ethereum:" {
                var targetAddress: String
                if let user = components.user {
                    targetAddress = user
                } else {
                    targetAddress = host
                }
                let payPrefix = "pay-"
                if targetAddress.hasPrefix(payPrefix) {
                    targetAddress = String(targetAddress[payPrefix.endIndex...])
                }
                if let value = queries["value"] {
                    if let ether = value.toEther() {
                        amount = ether
                    } else {
                        return nil
                    }
                    let chainId = "1"
                    if let id = Self.externalTransferEthereumChainIds[chainId] {
                        assetId = id
                    } else {
                        return nil
                    }
                    destination = targetAddress
                    needsCheckPrecision = false
                } else if components.path == "/transfer" {
                    if let id = AssetDAO.shared.getAssetIdByAssetKey(targetAddress) {
                        assetId = id
                    } else {
                        return nil
                    }
                    if let address = queries["address"] {
                        destination = address
                    } else {
                        return nil
                    }
                    if let value = queries["amount"] {
                        if value.isScientificNotation() {
                            return nil
                        }
                        amount = value
                        needsCheckPrecision = false
                    } else if let value = queries["uint256"] {
                        amount = value
                        needsCheckPrecision = true
                    } else {
                        return nil
                    }
                } else if let requestedAmount = queries["amount"] {
                    amount = requestedAmount
                    let chainId = "1"
                    if let id = Self.externalTransferEthereumChainIds[chainId] {
                        assetId = id
                    } else {
                        return nil
                    }
                    destination = targetAddress
                    needsCheckPrecision = false
                } else {
                    return nil
                }
            } else {
                if chain == "solana:", queries["spl-token"] != nil {
                    return nil
                }
                if let number = queries["amount"] {
                    amount = number
                } else if let number = queries["tx_amount"] {
                    amount = number
                } else {
                    return nil
                }
                if amount.isScientificNotation() {
                    return nil
                }
                if let id = Self.externalTransferSupportedAssetChainIds[chain] {
                    assetId = id
                } else {
                    return nil
                }
                destination = host
                needsCheckPrecision = false
            }
            self = .external(amount: amount, assetId: assetId, destination: destination, needsCheckPrecision: needsCheckPrecision, tag: nil)
        }
    }
    
}

fileprivate extension String {
    
    func toEther() -> String? {
        if isScientificNotation() {
            let components = split(separator: "e")
            if components.count == 2, let coefficient = Decimal(string: String(components[0])), let exponent = Int(components[1]) {
                let result = coefficient * pow(Decimal(10), exponent) / pow(Decimal(10), 18)
                return "\(result)"
            } else {
                return nil
            }
        } else if let value = Decimal(string: self) {
            return "\(value / pow(Decimal(10), 18))"
        } else {
            return nil
        }
    }
    
    func isScientificNotation() -> Bool {
        contains("e")
    }
    
}
