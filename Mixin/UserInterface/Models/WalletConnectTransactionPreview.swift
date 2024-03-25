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
    let hexData: String?
    let data: Data?
    
    let decimalValue: Decimal?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let hexData = try container.decodeIfPresent(String.self, forKey: .data)
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
        if let hexValue = try? container.decode(String.self, forKey: .value), let v = BigUInt(hex: hexValue) {
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
        
        let hexGas = try container.decode(String.self, forKey: .gas)
        guard let gas = BigUInt(hex: hexGas) else {
            throw Error.invalidGas
        }
        
        self.from = try container.decode(EthereumAddress.self, forKey: .from)
        self.to = try container.decode(EthereumAddress.self, forKey: .to)
        self.value = value
        self.gas = gas
        self.hexData = hexData
        self.data = data
        self.decimalValue = decimalValue
    }
    
}
