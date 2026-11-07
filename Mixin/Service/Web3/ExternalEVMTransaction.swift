import Foundation
import MixinServices

struct ExternalEVMTransaction {
    
    enum Error: Swift.Error {
        case invalidValue
        case valueTooLarge
        case invalidGas
        case gasTooLarge
        case invalidData
        case noFromAddress
        case noToAddress
    }
    
    let from: EVM.Address
    let to: EVM.Address?
    let value: EVMQuantity?
    let gas: UInt64?
    let hexEncodedData: String?
    let data: Data?
    
    let decimalValue: Decimal?
    
    init(json: [String: Any]) throws {
        guard let from = json["from"] as? String else {
            throw Error.noFromAddress
        }
        let to = json["to"] as? String
        let data = json["data"] as? String
        let value = json["value"] as? String
        let gas = json["gas"] as? String
        let toAddress: EVM.Address? = if let to {
            try EVM.Address(to)
        } else {
            nil
        }
        try self.init(
            from: try EVM.Address(from),
            to: toAddress,
            hexData: data,
            hexValue: value,
            hexGas: gas,
        )
    }
    
    private init(
        from: EVM.Address,
        to: EVM.Address?,
        hexData: String?,
        hexValue: String?,
        hexGas: String?,
    ) throws {
        let data: Data?
        if let hexData {
            if let d = EVM.data(hex: hexData) {
                data = d
            } else {
                throw Error.invalidData
            }
        } else {
            data = nil
        }
        
        let value: EVMQuantity?
        let decimalValue: Decimal?
        if let hexValue {
            guard let v = EVMQuantity(hex: hexValue) else {
                throw Error.invalidValue
            }
            value = v
            let weiValueString = try v.decimalString()
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
        
        let gas: UInt64?
        if let hexGas {
            let digits = hexGas.hasPrefix("0x") ? String(hexGas.dropFirst(2)) : hexGas
            guard EVMQuantity(hex: hexGas) != nil else {
                throw Error.invalidGas
            }
            guard let g = UInt64(digits, radix: 16) else {
                throw Error.gasTooLarge
            }
            gas = g
        } else {
            gas = nil
        }
        
        self.from = from
        self.to = to
        self.value = value
        self.gas = gas
        self.hexEncodedData = data?.hexEncodedString()
        self.data = data
        self.decimalValue = decimalValue
    }
    
}

// `Decodable` should be enough, but `Encodable` is required by WalletConnect by mistake
extension ExternalEVMTransaction: Codable {
    
    enum CodingKeys: String, CodingKey {
        case from
        case to
        case value
        case gas
        case data
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(from, forKey: .from)
        try container.encodeIfPresent(to, forKey: .to)
        try container.encodeIfPresent(value?.hexQuantity(), forKey: .value)
        try container.encodeIfPresent(gas.map { "0x" + String($0, radix: 16) }, forKey: .gas)
        try container.encodeIfPresent(hexEncodedData.map { "0x" + $0 }, forKey: .data)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            from: try container.decode(EVM.Address.self, forKey: .from),
            to: try container.decodeIfPresent(EVM.Address.self, forKey: .to),
            hexData: try container.decodeIfPresent(String.self, forKey: .data),
            hexValue: try container.decodeIfPresent(String.self, forKey: .value),
            hexGas: try container.decodeIfPresent(String.self, forKey: .gas),
        )
    }
    
}
