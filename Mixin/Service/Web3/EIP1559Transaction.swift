import Foundation
import BigInt
import web3

struct EIP1559Transaction: Equatable, Codable {
    
    let chainID: Int
    let nonce: BigInt?
    let maxPriorityFeePerGas: BigUInt?
    let maxFeePerGas: BigUInt?
    let gasLimit: BigUInt?
    let destination: EthereumAddress
    let amount: BigUInt
    let data: Data?
    let accessList: [Data] // Not in used currently, the type could be wrong
    
    var rlpEncodingFields: [Any?] {
        [
            chainID, nonce, maxPriorityFeePerGas, maxFeePerGas,
            gasLimit, destination, amount, data ?? Data(),
            accessList
        ]
    }
    
    var raw: Data? {
        if let encoded = RLP.encode(rlpEncodingFields) {
            [0x02] + encoded
        } else {
            nil
        }
    }
    
    init(
        chainID: Int, nonce: BigInt? = nil, maxPriorityFeePerGas: BigUInt? = nil,
        maxFeePerGas: BigUInt? = nil, gasLimit: BigUInt? = nil,
        destination: EthereumAddress, amount: BigUInt, data: Data? = nil
    ) {
        self.chainID = chainID
        self.nonce = nonce
        self.maxPriorityFeePerGas = maxPriorityFeePerGas
        self.maxFeePerGas = maxFeePerGas
        self.gasLimit = gasLimit
        self.destination = destination
        self.amount = amount
        self.data = data
        self.accessList = []
    }
    
}

struct SignedEIP1559Transaction {
    
    let transaction: EIP1559Transaction
    let r: Data
    let s: Data
    let yParity: Int
    
    init(
        transaction: EIP1559Transaction,
        signature raw: Data
    ) {
        self.transaction = transaction
        self.r = raw[raw.startIndex.advanced(by: 0)..<raw.startIndex.advanced(by: 32)]
        self.s = raw[raw.startIndex.advanced(by: 32)..<raw.startIndex.advanced(by: 64)]
        self.yParity = Int(raw[raw.startIndex.advanced(by: 64)])
    }
    
    var raw: Data? {
        let fields = transaction.rlpEncodingFields + [yParity, r, s]
        return if let encoded = RLP.encode(fields) {
            [0x02] + encoded
        } else {
            nil
        }
    }
    
    var hash: Data? {
        raw?.web3.keccak256
    }
    
}

enum EthereumSignerError: Error {
    case emptyRawTransaction
    case unknownError
}

extension EthereumAccountProtocol {
    
    func sign(transaction: EIP1559Transaction) throws -> SignedEIP1559Transaction {
        guard let raw = transaction.raw else {
            throw EthereumSignerError.emptyRawTransaction
        }
        guard let signature = try? sign(data: raw) else {
            throw EthereumSignerError.unknownError
        }
        return SignedEIP1559Transaction(transaction: transaction, signature: signature)
    }
    
}
