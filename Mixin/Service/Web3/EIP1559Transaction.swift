import Foundation
import BigInt
import web3

struct EIP1559Transaction: Equatable, Codable {
    
    let chainID: Int
    let nonce: Int?
    let maxPriorityFeePerGas: BigUInt?
    let maxFeePerGas: BigUInt?
    let gasLimit: BigUInt?
    let destination: EthereumAddress
    let amount: BigUInt
    let data: Data
    let accessList: [Data] // The type is wrong, not working, may cost more gas.
    
    var rlpEncodingFields: [Any?] {
        [
            chainID, nonce, maxPriorityFeePerGas, maxFeePerGas,
            gasLimit, destination, amount, data, accessList
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
        chainID: Int, nonce: Int?, maxPriorityFeePerGas: BigUInt?,
        maxFeePerGas: BigUInt?, gasLimit: BigUInt?,
        destination: EthereumAddress, amount: BigUInt, data: Data
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
    
    init?(rawTransaction: String) {
        guard rawTransaction.hasPrefix("0x02") else {
            return nil
        }
        guard let tx = Data(hexEncodedString: rawTransaction.dropFirst(4)) else {
            return nil
        }
        do {
            guard case let .list(fields) = try RLPDecoder.decode(tx) else {
                return nil
            }
            guard fields.count > 7 else {
                return nil
            }
            let chainID = try fields[0].asInt()
            let nonce = try fields[1].asInt()
            let maxPriorityFeePerGas = try fields[2].asBigUInt()
            let maxFeePerGas = try fields[3].asBigUInt()
            let gasLimit = try fields[4].asBigUInt()
            let destination = try fields[5].asAddress()
            let amount = try fields[6].asBigUInt()
            let data = try fields[7].asData()
            self.init(
                chainID: chainID,
                nonce: nonce,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                maxFeePerGas: maxFeePerGas,
                gasLimit: gasLimit,
                destination: destination,
                amount: amount,
                data: data
            )
        } catch {
            return nil
        }
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
        var r = raw[raw.startIndex.advanced(by: 0)..<raw.startIndex.advanced(by: 32)]
        while r.first == 0x00 {
            r.removeFirst()
        }
        
        var s = raw[raw.startIndex.advanced(by: 32)..<raw.startIndex.advanced(by: 64)]
        while s.first == 0x00 {
            s.removeFirst()
        }
        
        self.transaction = transaction
        self.r = r
        self.s = s
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
