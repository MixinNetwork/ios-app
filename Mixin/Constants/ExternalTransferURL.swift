import Foundation
import MixinServices

class ExternalTransferURL {
    
    private let supportedAssetChainIds: [String: String] = [
        "bitcoin:"   : "c6d0c728-2624-429b-8e0d-d9d19b6592fa",
        "ethereum:"  : "43d61dcd-e413-450d-80b8-101d5e903357",
        "litecoin:"  : "76c802a2-7c88-447f-a93e-c29c9e5dd9c8",
        "dash:"      : "6472e7e3-75fd-48b6-b1dc-28d294ee1476",
        "dogecoin:"  : "6770a1e5-6086-44d5-b60f-545f9d9e8ffd",
        "monero:"    : "05c5ac01-31f9-4a69-aa8a-ab796de1d041",
        "solana:"    : "64692c23-8971-4cf4-84a7-4dd1271dd887",
    ]
    
    private let ethereumChainIds: [String: String] = [
        "1": "43d61dcd-e413-450d-80b8-101d5e903357"
    ]

    var amount: String
    let assetId: String
    let destination: String
    let tag: String? = nil // no value for now
    let needsCheckPrecision: Bool
    
    init?(url: String) {
        guard let prefix = supportedAssetChainIds.keys.first(where: { url.hasPrefix($0) }) else {
            return nil
        }
        var string = url
        if !string[prefix.endIndex...].hasPrefix("//") {
            string.insert(contentsOf: "//", at: prefix.endIndex)
        }
        guard let url = URLComponents(string: string), let host = url.host else {
            return nil
        }
        let query = url.getKeyVals()
        if prefix == "ethereum:" {
            var targetAddress: String
            if let user = url.user {
                targetAddress = user
            } else {
                targetAddress = host
            }
            let payPrefix = "pay-"
            if targetAddress.hasPrefix(payPrefix) {
                targetAddress = String(targetAddress[payPrefix.endIndex...])
            }
            let number: String
            if let value = query["value"] {
                number = value
                let chainId = "1"
                if let id = ethereumChainIds[chainId] {
                    assetId = id
                } else {
                    return nil
                }
                destination = targetAddress
                needsCheckPrecision = false
            } else if url.path == "/transfer" {
                if let id = AssetDAO.shared.getAssetIdByAssetKey(targetAddress) {
                    assetId = id
                } else {
                    return nil
                }
                if let address = query["address"] {
                    destination = address
                } else {
                    return nil
                }
                if let value = query["amount"] {
                    if value.isScientificNotation() {
                        return nil
                    }
                    number = value
                    needsCheckPrecision = false
                } else if let value = query["uint256"] {
                    number = value
                    needsCheckPrecision = true
                } else {
                    return nil
                }
            } else {
                return nil
            }
            if needsCheckPrecision {
                amount = number
            } else if let ether = number.toEther() {
                amount = ether
            } else {
                return nil
            }
        } else {
            if prefix == "solana:", query["spl-token"] != nil {
                return nil
            }
            if let number = query["amount"] {
                amount = number
            } else if let number = query["tx_amount"] {
                amount = number
            } else {
                return nil
            }
            if amount.isScientificNotation() {
                return nil
            }
            if let id = supportedAssetChainIds[prefix] {
                assetId = id
            } else {
                return nil
            }
            destination = host
            needsCheckPrecision = false
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
        } else {
            return self
        }
    }
    
    func isScientificNotation() -> Bool {
        contains("e")
    }
    
}
