import Foundation
import MixinServices

enum Bitcoin {
    
    enum BitcoinError: Error {
        case nullResult
        case invalidResult
        case code(BitcoinErrorCode)
        case convertTxID
    }
    
    struct SignedTransaction {
        let transaction: String
        let changeOutput: Web3Output?
    }
    
    struct DecodedTransaction {
        
        struct Input {
            let txid: String
            let vout: UInt32
        }
        
        let inputs: [Input]
        let numberOfOutputs: Int
        
    }
    
    static func isValidAddress(address: String) -> Bool {
        address.withCString { address in
            bitcoin_is_valid_address(address)
        }
    }
    
    static func wif(privateKey: Data) throws -> String {
        try privateKey.withUnsafeBytes { privateKey in
            try withBitcoinStringPointer { address in
                bitcoin_wif_string(privateKey.baseAddress, privateKey.count, &address)
            }
        }
    }
    
    static func privateKey(wif: String) throws -> Data {
        try wif.withCString { wif in
            try withBitcoinDataPointer { bytes, count in
                bitcoin_private_key_bytes_from_wif(wif, &bytes, &count)
            }
        }
    }
    
    static func privateKey(mnemonics: String, path: String) throws -> Data {
        try mnemonics.withCString { mnemonics in
            try path.withCString { path in
                try withBitcoinDataPointer { bytes, count in
                    bitcoin_private_key_bytes_from_mnemonics(mnemonics, path, &bytes, &count)
                }
            }
        }
    }
    
    static func segwitAddress(privateKey: Data) throws -> String {
        try privateKey.withUnsafeBytes { privateKey in
            try withBitcoinStringPointer { address in
                bitcoin_segwit_address(privateKey.baseAddress, privateKey.count, &address)
            }
        }
    }
    
    static func sign(message: String, with privateKey: Data) throws -> String {
        try message.withCString { message in
            try privateKey.withUnsafeBytes { privateKey in
                try withBitcoinStringPointer { signature in
                    bitcoin_sign_message_compressed(
                        message,
                        privateKey.baseAddress,
                        privateKey.count,
                        &signature
                    )
                }
            }
        }
    }
    
    static func signedTransaction(
        outputs: [Web3Output],
        sendAddress: String,
        sendAmount: Decimal,
        fee: Decimal,
        receiveAddress: String,
        privateKey: Data,
    ) throws -> SignedTransaction {
        var utxoAmount: Decimal = 0
        let utxos = try outputs.map { output in
            guard
                let hash = Data(hexEncodedString: output.transactionHash),
                hash.count == 32,
                let vout = UInt32(exactly: output.outputIndex),
                let amount = Decimal(string: output.amount, locale: .enUSPOSIX)
            else {
                throw BitcoinError.convertTxID
            }
            utxoAmount += amount
            let txid = (
                hash[31], hash[30], hash[29], hash[28], hash[27],
                hash[26], hash[25], hash[24], hash[23], hash[22],
                hash[21], hash[20], hash[19], hash[18], hash[17],
                hash[16], hash[15], hash[14], hash[13], hash[12],
                hash[11], hash[10], hash[9], hash[8], hash[7],
                hash[6], hash[5], hash[4], hash[3], hash[2],
                hash[1], hash[0],
            )
            let value = NSDecimalNumber(decimal: amount / .satoshi).uint64Value
            return BitcoinUTXO(txid: txid, vout: vout, value: value)
        }
        let sendAmountInSatoshi = NSDecimalNumber(decimal: sendAmount / .satoshi).uint64Value
        let feeInSatoshi = NSDecimalNumber(decimal: fee / .satoshi).uint64Value
        let (transaction, txid) = try utxos.withUnsafeBufferPointer { utxos in
            try receiveAddress.withCString { receiveAddress in
                try privateKey.withUnsafeBytes { privateKey in
                    var txidPointer: UnsafePointer<CChar>?
                    let signedTransaction = try withBitcoinStringPointer { signedTransaction in
                        bitcoin_sign_p2wpkh_transaction(
                            utxos.baseAddress,
                            utxos.count,
                            receiveAddress,
                            sendAmountInSatoshi,
                            feeInSatoshi,
                            privateKey.baseAddress,
                            privateKey.count,
                            &signedTransaction,
                            &txidPointer,
                        )
                    }
                    guard let txidPointer else {
                        throw BitcoinError.nullResult
                    }
                    let txid = String(cString: txidPointer)
                    bitcoin_free_string(txidPointer)
                    return (signedTransaction, txid)
                }
            }
        }
        let changeOutput: Web3Output?
        let changeAmount = utxoAmount - sendAmount - fee
        if changeAmount > 0 {
            let now = Date().toUTCString()
            changeOutput = Web3Output(
                id: Web3Output.bitcoinOutputID(txid: txid, vout: 1),
                assetID: AssetID.btc,
                transactionHash: txid,
                outputIndex: 1,
                amount: TokenAmountFormatter.string(from: changeAmount),
                address: sendAddress,
                pubkeyHex: "",
                pubkeyType: "",
                status: .unspent,
                createdAt: now,
                updatedAt: now
            )
        } else {
            changeOutput = nil
        }
        return SignedTransaction(transaction: transaction, changeOutput: changeOutput)
    }
    
    static func decode(transaction: String) throws -> DecodedTransaction {
        try transaction.withCString { transaction in
            var inputsPtr: UnsafeMutablePointer<BitcoinUTXO>? = nil
            var inputsLen: Int = 0
            var outputsCount: Int = 0
            let result: BitcoinErrorCode = bitcoin_decode_p2wpkh_transaction(
                transaction,
                &inputsPtr,
                &inputsLen,
                &outputsCount
            )
            guard result == BitcoinErrorCodeSuccess, let inputsPtr else {
                throw BitcoinError.code(result)
            }
            let buffer = UnsafeBufferPointer(start: inputsPtr, count: inputsLen)
            let inputs = [BitcoinUTXO](buffer).map { utxo in
                let txidData = Data([
                    utxo.txid.31, utxo.txid.30, utxo.txid.29, utxo.txid.28,
                    utxo.txid.27, utxo.txid.26, utxo.txid.25, utxo.txid.24,
                    utxo.txid.23, utxo.txid.22, utxo.txid.21, utxo.txid.20,
                    utxo.txid.19, utxo.txid.18, utxo.txid.17, utxo.txid.16,
                    utxo.txid.15, utxo.txid.14, utxo.txid.13, utxo.txid.12,
                    utxo.txid.11, utxo.txid.10, utxo.txid.9, utxo.txid.8,
                    utxo.txid.7, utxo.txid.6, utxo.txid.5, utxo.txid.4,
                    utxo.txid.3, utxo.txid.2, utxo.txid.1, utxo.txid.0,
                ])
                let txid = txidData.hexEncodedString()
                return DecodedTransaction.Input(txid: txid, vout: utxo.vout)
            }
            bitcoin_free_utxos(inputsPtr, inputsLen)
            return DecodedTransaction(inputs: inputs, numberOfOutputs: outputsCount)
        }
    }
    
    fileprivate static func withBitcoinStringPointer(
        _ assignment: (inout UnsafePointer<CChar>?) -> BitcoinErrorCode
    ) throws -> String {
        var pointer: UnsafePointer<CChar>?
        let result = assignment(&pointer)
        guard result == BitcoinErrorCodeSuccess else {
            throw BitcoinError.code(result)
        }
        guard let pointer else {
            throw BitcoinError.nullResult
        }
        let string = String(cString: pointer)
        bitcoin_free_string(pointer)
        return string
    }
    
    fileprivate static func withBitcoinDataPointer(
        _ assignment: (
            inout UnsafePointer<UInt8>?,
            inout Int
        ) -> BitcoinErrorCode
    ) throws -> Data {
        var pointer: UnsafePointer<UInt8>?
        var count: Int = -1
        let result = assignment(&pointer, &count)
        guard result == BitcoinErrorCodeSuccess else {
            throw BitcoinError.code(result)
        }
        guard let pointer else {
            throw BitcoinError.nullResult
        }
        guard count != -1 else {
            throw BitcoinError.invalidResult
        }
        let data = Data(bytes: pointer, count: count)
        bitcoin_free_bytes(UnsafeMutablePointer(mutating: pointer), count)
        return data
    }
    
}

extension Bitcoin {
    
    struct P2WPKHFeeCalculator {
        
        enum CalculateError: Error {
            case invalidOutputAmount(String)
            case insufficientOutputs(feeAmount: Decimal)
        }
        
        struct Result {
            let feeAmount: Decimal
            let spendingOutputs: [Web3Output]
        }
        
        private let allOutputs: [Web3Output]
        private let rate: Decimal
        private let minimum: Decimal
        
        init(outputs: [Web3Output], rate: Decimal, minimum: Decimal) {
            self.allOutputs = outputs
            self.rate = rate
            self.minimum = minimum
        }
        
        func calculate(transferAmount: Decimal) throws -> Result {
            var spendingOutputs: [Web3Output] = []
            var utxoAmount: Decimal = 0
            var feeWithChange: Decimal = 0
            for output in allOutputs {
                guard let amount = Decimal(string: output.amount, locale: .enUSPOSIX) else {
                    throw CalculateError.invalidOutputAmount(output.amount)
                }
                spendingOutputs.append(output)
                utxoAmount += amount
                let vsizeWithChange = vSize(
                    numberOfInputs: spendingOutputs.count,
                    numberOfOutputs: 2
                )
                feeWithChange = max(minimum, vsizeWithChange * rate * .satoshi)
                if utxoAmount < transferAmount + feeWithChange {
                    continue
                } else if utxoAmount > transferAmount + feeWithChange {
                    return Result(feeAmount: feeWithChange, spendingOutputs: spendingOutputs)
                } else {
                    let vsizeNoChange = vSize(
                        numberOfInputs: spendingOutputs.count,
                        numberOfOutputs: 1
                    )
                    let feeAmount = max(minimum, vsizeNoChange * rate * .satoshi)
                    return Result(feeAmount: feeAmount, spendingOutputs: spendingOutputs)
                }
            }
            throw CalculateError.insufficientOutputs(feeAmount: feeWithChange)
        }
        
        private func vSize(
            numberOfInputs: Int,
            numberOfOutputs: Int
        ) -> Decimal {
            let inputSize = Decimal(numberOfInputs) * 68
            let outputSize = Decimal(numberOfOutputs) * 31
            let overhead: Decimal = 11
            return inputSize + outputSize + overhead
        }
        
    }
    
}
