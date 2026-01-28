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
        let vsize: Int
        let changeOutput: Web3Output?
    }
    
    struct DecodedTransaction {
        
        struct Input {
            
            let txid: String
            let vout: UInt32
            let outputID: String
            
            fileprivate init(txid: String, vout: UInt32) {
                self.txid = txid
                self.vout = vout
                self.outputID = Web3Output.bitcoinOutputID(txid: txid, vout: vout)
            }
            
        }
        
        struct Output {
            let address: String
            let value: UInt64
        }
        
        let inputs: [Input]
        let outputs: [Output]
        
    }
    
    static let spendingDust: Decimal = 1000 * .satoshi
    static let changeDust = Decimal(BITCOIN_P2WPKH_DUST) * .satoshi
    static let privateKeyLength = BITCOIN_PRIVATE_KEY_LENGTH
    
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
                output.decimalAmount > 0
            else {
                throw BitcoinError.convertTxID
            }
            utxoAmount += output.decimalAmount
            let txid = (
                hash[31], hash[30], hash[29], hash[28], hash[27],
                hash[26], hash[25], hash[24], hash[23], hash[22],
                hash[21], hash[20], hash[19], hash[18], hash[17],
                hash[16], hash[15], hash[14], hash[13], hash[12],
                hash[11], hash[10], hash[9], hash[8], hash[7],
                hash[6], hash[5], hash[4], hash[3], hash[2],
                hash[1], hash[0],
            )
            let value = NSDecimalNumber(decimal: output.decimalAmount / .satoshi).uint64Value
            return BitcoinUTXO(txid: txid, vout: vout, value: value)
        }
        let sendAmountInSatoshi = NSDecimalNumber(decimal: sendAmount / .satoshi).uint64Value
        let feeInSatoshi = NSDecimalNumber(decimal: fee / .satoshi).uint64Value
        let (transaction, vsize, txid, change) = try utxos.withUnsafeBufferPointer { utxos in
            try receiveAddress.withCString { receiveAddress in
                try privateKey.withUnsafeBytes { privateKey in
                    var txidPointer: UnsafePointer<CChar>?
                    var vsize: Int = 0
                    var change: UInt64 = 0
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
                            &vsize,
                            &txidPointer,
                            &change,
                        )
                    }
                    guard let txidPointer else {
                        throw BitcoinError.nullResult
                    }
                    let txid = String(cString: txidPointer)
                    bitcoin_free_string(txidPointer)
                    return (signedTransaction, vsize, txid, change)
                }
            }
        }
        let changeOutput: Web3Output?
        if change > 0 {
            let amount = Decimal(change) * .satoshi
            let now = Date().toUTCString()
            changeOutput = Web3Output(
                id: Web3Output.bitcoinOutputID(txid: txid, vout: 1),
                assetID: AssetID.btc,
                transactionHash: txid,
                outputIndex: 1,
                amount: TokenAmountFormatter.string(from: amount),
                address: sendAddress,
                pubkeyHex: "",
                pubkeyType: "",
                status: .pending,
                createdAt: now,
                updatedAt: now
            )
        } else {
            changeOutput = nil
        }
        return SignedTransaction(transaction: transaction, vsize: vsize, changeOutput: changeOutput)
    }
    
    static func decode(transaction: String) throws -> DecodedTransaction {
        try transaction.withCString { transaction in
            var inputsPtr: UnsafeMutablePointer<BitcoinUTXO>? = nil
            var inputsLen: Int = 0
            var outputsPtr: UnsafeMutablePointer<BitcoinTransactionOutput>? = nil
            var outputsLen: Int = 0
            let result: BitcoinErrorCode = bitcoin_decode_p2wpkh_transaction(
                transaction,
                &inputsPtr,
                &inputsLen,
                &outputsPtr,
                &outputsLen,
            )
            guard result == BitcoinErrorCodeSuccess, let inputsPtr, let outputsPtr else {
                throw BitcoinError.code(result)
            }
            
            let inputsBuffer = UnsafeBufferPointer(start: inputsPtr, count: inputsLen)
            let inputs = [BitcoinUTXO](inputsBuffer).map { utxo in
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
            
            let outputsBuffer = UnsafeBufferPointer(start: outputsPtr, count: outputsLen)
            let outputs = [BitcoinTransactionOutput](outputsBuffer).map { output in
                DecodedTransaction.Output(
                    address: String(cString: output.address),
                    value: output.value
                )
            }
            bitcoin_free_transaction_outputs(outputsPtr, outputsLen)
            
            return DecodedTransaction(inputs: inputs, outputs: outputs)
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
            inout UnsafeMutablePointer<UInt8>?,
            inout Int
        ) -> BitcoinErrorCode
    ) throws -> Data {
        var pointer: UnsafeMutablePointer<UInt8>?
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
        bitcoin_free_bytes(pointer, count)
        return data
    }
    
}

extension Bitcoin {
    
    struct P2WPKHFeeCalculator {
        
        enum CalculateError: Error {
            case insufficientOutputs(feeAmount: Decimal)
        }
        
        struct Result: CustomDebugStringConvertible {
            
            let transferAmount: Decimal
            let feeAmount: Decimal
            let spendingOutputs: [Web3Output]
            
            var debugDescription: String {
                "<BTCFee transfer: \(transferAmount), fee: \(feeAmount), outputs: \(spendingOutputs.count)>"
            }
            
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
                spendingOutputs.append(output)
                utxoAmount += output.decimalAmount
                feeWithChange = {
                    let size = vSize(
                        numberOfInputs: spendingOutputs.count,
                        numberOfOutputs: 2
                    )
                    return max(minimum, size * rate * .satoshi)
                }()
                let feeWithoutChange = {
                    let size = vSize(
                        numberOfInputs: spendingOutputs.count,
                        numberOfOutputs: 1
                    )
                    return max(minimum, size * rate * .satoshi)
                }()
                // utxoAmount could be between 0 and ∞
                // 0 - (transferAmount + feeWithoutChange) - (transferAmount + feeWithChange + changeDust) - ∞
                if utxoAmount < transferAmount + feeWithoutChange {
                    continue
                } else if utxoAmount == transferAmount + feeWithoutChange {
                    return Result(
                        transferAmount: transferAmount,
                        feeAmount: feeWithoutChange,
                        spendingOutputs: spendingOutputs
                    )
                } else if utxoAmount < transferAmount + feeWithChange + Bitcoin.changeDust {
                    return Result(
                        transferAmount: transferAmount,
                        feeAmount: utxoAmount - transferAmount,
                        spendingOutputs: spendingOutputs
                    )
                } else {
                    return Result(
                        transferAmount: transferAmount,
                        feeAmount: feeWithChange,
                        spendingOutputs: spendingOutputs
                    )
                }
            }
            throw CalculateError.insufficientOutputs(feeAmount: feeWithChange)
        }
        
        func calculateCancellation(
            requiredOutputIDs: Set<String>,
            originalFee: Decimal,
            incrementalFee: Decimal
        ) throws -> Result {
            var spendingOutputs: [Web3Output] = []
            var additionalOutputs: [Web3Output] = []
            var spendingAmount: Decimal = 0
            for output in allOutputs {
                if requiredOutputIDs.contains(output.id) {
                    spendingOutputs.append(output)
                    spendingAmount += output.decimalAmount
                } else {
                    additionalOutputs.append(output)
                }
            }
            
            while true {
                let size = vSize(numberOfInputs: spendingOutputs.count, numberOfOutputs: 1)
                let requiredFee = max(
                    size * rate * .satoshi,
                    originalFee + size * incrementalFee * .satoshi,
                    minimum
                )
                if spendingAmount > requiredFee {
                    return Result(
                        transferAmount: spendingAmount - requiredFee,
                        feeAmount: requiredFee,
                        spendingOutputs: spendingOutputs
                    )
                } else if !additionalOutputs.isEmpty {
                    let output = additionalOutputs.removeFirst()
                    spendingOutputs.append(output)
                    spendingAmount += output.decimalAmount
                } else {
                    throw CalculateError.insufficientOutputs(feeAmount: requiredFee)
                }
            }
        }
        
        func exhaustingOutputsTransferAmount() -> Decimal {
            let totalAmount = allOutputs.reduce(0) { result, output in
                result + output.decimalAmount
            }
            let size = vSize(numberOfInputs: allOutputs.count, numberOfOutputs: 1)
            let fee = max(minimum, size * rate * .satoshi)
            return totalAmount - fee
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
