import Foundation
import BigInt
import web3

struct WalletConnectTransactionPreview: Codable {
    
    enum Error: Swift.Error {
        case invalidValue
        case valueTooLarge
        case invalidGas
        case gasTooLarge
        case invalidData
    }
    
    enum CodingKeys: String, CodingKey {
        case from
        case to
        case value
        case gas
        case data
    }
    
    let from: EthereumAddress
    let to: EthereumAddress
    let value: BigUInt?
    let gas: BigUInt
    let hexData: String
    let data: Data
    
    let decimalValue: Decimal?
    let decimalGas: Decimal
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let hexData = try container.decode(String.self, forKey: .data)
        guard let data = Data(hex: hexData) else {
            throw Error.invalidData
        }
        
        let value: BigUInt?
        let decimalValue: Decimal?
        if let hexValue = try? container.decode(String.self, forKey: .value), let v = BigUInt(hex: hexValue) {
            value = v
            let weiValueString = v.description
            guard
                weiValueString.count < 38,
                var weiValue = Decimal(string: weiValueString, locale: .enUSPOSIX)
            else {
                throw Error.valueTooLarge
            }
            decimalValue = weiValue * .wei
        } else {
            value = 0
            decimalValue = nil
        }
        
        let hexGas = try container.decode(String.self, forKey: .gas)
        guard let gas = BigUInt(hex: hexGas) else {
            throw Error.invalidGas
        }
        let gweiGasString = gas.description
        guard
            gweiGasString.count < 38,
            var gweiGas = Decimal(string: gweiGasString, locale: .enUSPOSIX)
        else {
            throw Error.gasTooLarge
        }
        let decimalGas = gweiGas * .gwei
        
        self.from = try container.decode(EthereumAddress.self, forKey: .from)
        self.to = try container.decode(EthereumAddress.self, forKey: .to)
        self.value = value
        self.gas = gas
        self.hexData = hexData
        self.data = data
        self.decimalValue = decimalValue
        self.decimalGas = decimalGas
    }
    
}
