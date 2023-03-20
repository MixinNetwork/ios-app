import Foundation
import BigInt
import web3

struct WalletConnectTransactionPreview: Decodable {
    
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
    let value: BigUInt
    let gas: BigUInt
    let data: Data
    
    let decimalValue: Decimal
    let decimalGas: Decimal
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let dataString = try container.decode(String.self, forKey: .data)
        guard let data = Data(hex: dataString) else {
            throw Error.invalidData
        }
        
        let hexValue = try container.decode(String.self, forKey: .value)
        guard let value = BigUInt(hex: hexValue) else {
            throw Error.invalidValue
        }
        let decimalValueString = value.description
        guard
            decimalValueString.count < 38,
            var decimalValue = Decimal(string: decimalValueString, locale: .enUSPOSIX)
        else {
            throw Error.valueTooLarge
        }
        decimalValue /= 1000000000000000000 // FIXME: Wei to decimal
        
        let hexGas = try container.decode(String.self, forKey: .gas)
        guard let gas = BigUInt(hex: hexGas) else {
            throw Error.invalidGas
        }
        let decimalGasString = gas.description
        guard
            decimalGasString.count < 38,
            var decimalGas = Decimal(string: decimalGasString, locale: .enUSPOSIX)
        else {
            throw Error.gasTooLarge
        }
        decimalGas /= 1000000000 // FIXME: Gwei to decimal
        
        self.from = try container.decode(EthereumAddress.self, forKey: .from)
        self.to = try container.decode(EthereumAddress.self, forKey: .to)
        self.value = value
        self.gas = gas
        self.data = data
        self.decimalValue = decimalValue
        self.decimalGas = decimalGas
    }
    
}
