import Foundation
import BigInt
import web3
import MixinServices

struct Web3TransactionPreview {
    
    enum Error: Swift.Error {
        case invalidValue
        case valueTooLarge
        case invalidGas
        case gasTooLarge
        case invalidData
        case noFromAddress
        case noToAddress
    }
    
    let from: EthereumAddress
    let to: EthereumAddress
    let value: BigUInt?
    let gas: BigUInt?
    let hexData: String?
    let data: Data?
    
    let decimalValue: Decimal?
    
    init(from: EthereumAddress, to: EthereumAddress, value: BigUInt?, data: Data?, decimalValue: Decimal?) {
        self.from = from
        self.to = to
        self.value = value
        self.gas = nil
        self.hexData = data?.hexEncodedString()
        self.data = data
        self.decimalValue = decimalValue
    }
    
    init(json: [String: Any]) throws {
        guard let from = json["from"] as? String else {
            throw Error.noFromAddress
        }
        guard let to = json["to"] as? String else {
            throw Error.noToAddress
        }
        let data = json["data"] as? String
        let value = json["value"] as? String
        let gas = json["gas"] as? String
        try self.init(from: EthereumAddress(from),
                      to: EthereumAddress(to),
                      hexData: data,
                      hexValue: value,
                      hexGas: gas)
    }
    
    private init(
        from: EthereumAddress,
        to: EthereumAddress,
        hexData: String?,
        hexValue: String?,
        hexGas: String?
    ) throws {
        let data: Data?
        if let hexData {
            if let d = Data(hex: hexData) {
                data = d
            } else {
                throw Error.invalidData
            }
        } else {
            data = nil
        }
        
        let value: BigUInt?
        let decimalValue: Decimal?
        if let hexValue, let v = BigUInt(hex: hexValue) {
            value = v
            let weiValueString = v.description
            guard
                weiValueString.count < 38,
                let weiValue = Decimal(string: weiValueString, locale: .enUSPOSIX)
            else {
                throw Error.valueTooLarge
            }
            decimalValue = weiValue * .wei
        } else {
            value = nil
            decimalValue = nil
        }
        
        let gas: BigUInt?
        if let hexGas {
            if let g = BigUInt(hex: hexGas) {
                gas = g
            } else {
                throw Error.invalidGas
            }
        } else {
            gas = nil
        }
        
        self.from = from
        self.to = to
        self.value = value
        self.gas = gas
        self.hexData = hexData
        self.data = data
        self.decimalValue = decimalValue
    }
    
}

extension Web3TransactionPreview: Codable {
    
    enum CodingKeys: String, CodingKey {
        case from
        case to
        case value
        case gas
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(from: try container.decode(EthereumAddress.self, forKey: .from),
                      to: try container.decode(EthereumAddress.self, forKey: .to),
                      hexData: try container.decodeIfPresent(String.self, forKey: .data),
                      hexValue: try container.decodeIfPresent(String.self, forKey: .value),
                      hexGas: try container.decodeIfPresent(String.self, forKey: .gas))
    }
    
}
