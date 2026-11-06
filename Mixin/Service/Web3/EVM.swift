import Foundation
import MixinServices

// Offline cryptography and transaction encoding are implemented by Alloy.
enum EVM {
    
    enum Error: Swift.Error, LocalizedError {
        case sdk(Int32)
        case invalidAddress
        case invalidResponse
        case invalidSignature
        case invalidTransaction
        case invalidTypedData
        case invalidTypedDataChainID
        case integerOverflow
        
        var errorDescription: String? {
            switch self {
            case .invalidTypedDataChainID:
                R.string.localizable.eip712_invalid_chain_id()
            default:
                nil
            }
        }
    }
    
    static func address(privateKey: Data) throws(Error) -> EVM.Address {
        let bytes = try output { output in
            privateKey.withEVMBytes { privateKey in
                evm_address(privateKey, output)
            }
        }
        guard bytes.count == 20 else {
            throw Error.invalidResponse
        }
        return try EVM.Address(bytes: bytes)
    }
    
    static func signPersonalMessage(_ message: Data, privateKey: Data) throws(Error) -> String {
        let signature = try output { output in
            message.withEVMBytes { message in
                privateKey.withEVMBytes { privateKey in
                    evm_sign_personal_message(message, privateKey, output)
                }
            }
        }
        return "0x" + signature.hexEncodedString()
    }
    
    static func signTypedData(
        _ message: EVMTypedData,
        chainID: Int,
        privateKey: Data,
    ) throws(Error) -> String {
        guard let chainID = UInt64(exactly: chainID), chainID > 0 else {
            throw .invalidTypedDataChainID
        }
        let signature = try output { output in
            message.json.withEVMBytes { json in
                privateKey.withEVMBytes { privateKey in
                    evm_sign_typed_data(json, chainID, privateKey, output)
                }
            }
        }
        return "0x" + signature.hexEncodedString()
    }
    
    // Sign a locally verified digest without an EIP-191 prefix or hashing again.
    static func signHash(_ hash: Data, privateKey: Data) throws(Error) -> String {
        let signature = try output { output in
            hash.withEVMBytes { hash in
                privateKey.withEVMBytes { privateKey in
                    evm_sign_hash(hash, privateKey, output)
                }
            }
        }
        return "0x" + signature.hexEncodedString()
    }
    
    static func recoverPublicKey(
        hash: Data,
        signature: Data,
    ) throws(Error) -> Data {
        let publicKey = try output { output in
            hash.withEVMBytes { hash in
                signature.withEVMBytes { signature in
                    evm_recover_public_key(hash, signature, output)
                }
            }
        }
        guard publicKey.count == 65, publicKey.first == 0x04 else {
            throw .invalidResponse
        }
        return publicKey
    }
    
    static func data(hex: String) -> Data? {
        let digits = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        return digits.isEmpty ? Data() : Data(hexEncodedString: digits)
    }
    
    static func gaslessTransferAmount(
        _ amount: Decimal,
        precision: Int16,
    ) throws(Error) -> EVMQuantity {
        guard (0...255).contains(precision), !amount.isNaN, amount >= 0 else {
            throw .invalidTransaction
        }
        var amount = amount
        var units = Decimal()
        guard NSDecimalMultiplyByPowerOf10(&units, &amount, precision, .plain) == .noError else {
            throw .integerOverflow
        }
        var integral = Decimal()
        NSDecimalRound(&integral, &units, 0, .down)
        guard units == integral, let quantity = EVMQuantity(NSDecimalNumber(decimal: units).stringValue) else {
            throw .invalidTransaction
        }
        return quantity
    }
    
    static func validateGaslessTransfer(
        _ payload: GaslessTransactionEVMPayload,
        chainID: Int,
        sender: Address,
        recipient: Address,
        token: Address?,
        amount: EVMQuantity,
        feeToken: Address?,
        feeAmount: EVMQuantity,
    ) throws -> (userOperation: Data, authorization: Data?) {
        guard let chainID = UInt64(exactly: chainID), chainID > 0 else {
            throw Error.invalidTransaction
        }
        var expected = EVMGaslessTransfer()
        expected.chain_id = chainID
        try copyBytes(sender.data, into: &expected.sender)
        try copyBytes(recipient.data, into: &expected.recipient)
        expected.amount = amount.raw
        expected.fee_amount = feeAmount.raw
        if let token {
            expected.has_token = 1
            try copyBytes(token.data, into: &expected.token)
        }
        if let feeToken {
            expected.has_fee_token = 1
            try copyBytes(feeToken.data, into: &expected.fee_token)
        }
        let json = try JSONEncoder().encode(payload)
        let hashes = try output { output in
            json.withEVMBytes { evm_validate_gasless_transfer($0, &expected, output) }
        }
        guard hashes.count == 32 || hashes.count == 64 else {
            throw Error.invalidResponse
        }
        return (
            Data(hashes.prefix(32)),
            hashes.count == 64 ? Data(hashes.suffix(32)) : nil,
        )
    }
    
    fileprivate static func output(
        _ operation: (UnsafeMutablePointer<EVMBuffer>) -> EVMErrorCode,
    ) throws(Error) -> Data {
        var buffer = EVMBuffer()
        defer {
            evm_free_buffer(&buffer)
        }
        try check(operation(&buffer))
        guard buffer.len > 0 else {
            return Data()
        }
        guard let bytes = buffer.data else {
            throw Error.invalidResponse
        }
        return Data(bytes: bytes, count: buffer.len)
    }
    
    fileprivate static func check(_ status: EVMErrorCode) throws(Error) {
        guard status != EVMErrorCode_InvalidChainIDInTypedData else {
            throw .invalidTypedDataChainID
        }
        guard status == EVMErrorCode_Success else {
            throw Error.sdk(Int32(status.rawValue))
        }
    }
    
    private static func copyBytes<T>(_ bytes: Data, into value: inout T) throws(Error) {
        guard bytes.count == MemoryLayout<T>.size else {
            throw Error.invalidTransaction
        }
        _ = withUnsafeMutableBytes(of: &value) { destination in
            bytes.copyBytes(to: destination)
        }
    }
    
    private static func writeInteger<T>(_ value: EVMQuantity, into output: inout T) throws(Error) {
        let width = MemoryLayout<T>.size
        let bytes = value.bigEndian
        guard bytes.prefix(bytes.count - width).allSatisfy({ $0 == 0 }) else {
            throw Error.integerOverflow
        }
        try copyBytes(Data(bytes.suffix(width)), into: &output)
    }
    
}

private extension Data {
    
    func withEVMBytes<T>(_ body: (EVMBytes) throws -> T) rethrows -> T {
        try withUnsafeBytes { bytes in
            try body(EVMBytes(data: bytes.bindMemory(to: UInt8.self).baseAddress, len: bytes.count))
        }
    }
    
}

extension EVM {
    
    struct Address: Codable, Hashable, Sendable {
        
        let data: Data
        let checksumString: String
        
        var isZero: Bool {
            data.allSatisfy { $0 == 0 }
        }
        
        init(_ value: String) throws(EVM.Error) {
            let data = EVM.data(hex: value.lowercased())
            guard let data, data.count == 20 else {
                throw .invalidAddress
            }
            try self.init(bytes: data)
        }
        
        init(bytes: Data) throws(EVM.Error) {
            guard bytes.count == 20 else {
                throw .invalidAddress
            }
            let output = try EVM.output { output in
                bytes.withEVMBytes { evm_checksum_address($0, output) }
            }
            guard let checksumString = String(data: output, encoding: .utf8), checksumString.count == 42 else {
                throw .invalidResponse
            }
            self.data = bytes
            self.checksumString = checksumString
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            do {
                try self.init(value)
            } catch {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid EVM address")
            }
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(checksumString)
        }
        
        static func == (lhs: Address, rhs: Address) -> Bool {
            lhs.data == rhs.data
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(data)
        }
        
    }
    
}

struct EVMTypedData {
    
    let description: String
    
    fileprivate let json: Data
    
    init(json data: Data, chainID: Int) throws(EVM.Error) {
        guard let chainID = UInt64(exactly: chainID), chainID > 0 else {
            throw .invalidTypedDataChainID
        }
        try EVM.check(data.withEVMBytes { evm_validate_typed_data_chain_id($0, chainID) })
        // Preserve the original bytes for signing, including full-width integer literals.
        let description = try EVM.output { output in
            data.withEVMBytes { evm_typed_data_description($0, output) }
        }
        guard let description = String(data: description, encoding: .utf8) else {
            throw .invalidTypedData
        }
        self.json = data
        self.description = description
    }
    
}

// A bounded EVM quantity. Alloy owns parsing, formatting, and checked arithmetic.
// The stored bytes always contain exactly one unsigned 256-bit integer.
struct EVMQuantity: Equatable, ExpressibleByIntegerLiteral {
    
    let bigEndian: Data
    
    fileprivate var raw: EVMUInt256 {
        bigEndian.withUnsafeBytes { $0.load(as: EVMUInt256.self) }
    }
    
    init(integerLiteral value: UInt64) {
        self.init(value)
    }
    
    init(_ value: UInt64) {
        self.bigEndian = Data(repeating: 0, count: 24)
            + withUnsafeBytes(of: value.bigEndian, Data.init(_:))
    }
    
    init?(_ decimalString: String) {
        var value = EVMUInt256()
        let status = Data(decimalString.utf8)
            .withEVMBytes { evm_uint256_from_decimal($0, &value) }
        guard status == EVMErrorCode_Success else {
            return nil
        }
        self.init(raw: value)
    }
    
    init?(hex: String) {
        var value = EVMUInt256()
        let status = Data(hex.utf8)
            .withEVMBytes { evm_uint256_from_hex($0, &value) }
        guard status == EVMErrorCode_Success else {
            return nil
        }
        self.init(raw: value)
    }
    
    fileprivate init(raw: EVMUInt256) {
        self.bigEndian = withUnsafeBytes(of: raw, Data.init(_:))
    }
    
    func decimalString() throws(EVM.Error) -> String {
        let bytes = try EVM.output { evm_uint256_to_decimal(raw, $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
    
    func hexQuantity() throws(EVM.Error) -> String {
        let bytes = try EVM.output { evm_uint256_to_hex(raw, $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
    
    func multiplied(by other: EVMQuantity) throws(EVM.Error) -> EVMQuantity {
        var result = EVMUInt256()
        try EVM.check(evm_uint256_multiply(raw, other.raw, &result))
        return EVMQuantity(raw: result)
    }
    
    func divided(by divisor: UInt64) throws(EVM.Error) -> EVMQuantity {
        var result = EVMUInt256()
        try EVM.check(evm_uint256_divide(raw, divisor, &result))
        return EVMQuantity(raw: result)
    }
    
}

extension EVM {
    
    // Every Rust operation borrows this handle immutably. Updates return new handles.
    final class Transaction: @unchecked Sendable {
        
        private let pointer: OpaquePointer
        
        init(
            chainID: Int,
            nonce: Int,
            maxPriorityFeePerGas: EVMQuantity,
            maxFeePerGas: EVMQuantity,
            gasLimit: UInt64,
            destination: EVM.Address?,
            amount: EVMQuantity,
            data: Data,
        ) throws(Error) {
            guard let chainID = UInt64(exactly: chainID), let nonce = UInt64(exactly: nonce) else {
                throw .invalidTransaction
            }
            var fields = EVMTransactionFields()
            fields.chain_id = chainID
            fields.nonce = nonce
            fields.gas_limit = gasLimit
            try EVM.writeInteger(maxPriorityFeePerGas, into: &fields.max_priority_fee_per_gas)
            try EVM.writeInteger(maxFeePerGas, into: &fields.max_fee_per_gas)
            fields.amount = amount.raw
            if let destination {
                fields.has_destination = 1
                try EVM.copyBytes(destination.data, into: &fields.destination)
            }
            var owner: OpaquePointer?
            // Rust copies every field before these input borrows end.
            let status = data.withEVMBytes { data in
                fields.data = data
                return evm_transaction_new(&fields, &owner)
            }
            try EVM.check(status)
            guard let owner else {
                throw .invalidResponse
            }
            self.pointer = owner
        }
        
        init(rawTransaction: String) throws(Error) {
            guard let raw = EVM.data(hex: rawTransaction) else {
                throw .invalidTransaction
            }
            var owner: OpaquePointer?
            try EVM.check(raw.withEVMBytes { evm_transaction_decode($0, &owner) })
            guard let owner else {
                throw .invalidResponse
            }
            self.pointer = owner
        }
        
        private init(pointer: OpaquePointer) {
            self.pointer = pointer
        }
        
        deinit {
            evm_free_transaction(pointer)
        }
        
        func encoded() throws(Error) -> Data {
            try withExtendedLifetime(self) { () throws(Error) in
                try EVM.output { evm_transaction_encode(pointer, $0) }
            }
        }
        
        func sign(privateKey: Data) throws(Error) -> Data {
            try withExtendedLifetime(self) { () throws(Error) in
                try EVM.output { output in
                    privateKey.withEVMBytes { evm_transaction_sign(pointer, $0, output) }
                }
            }
        }
        
        func updating(
            nonce: Int,
            maxPriorityFeePerGas: EVMQuantity,
            maxFeePerGas: EVMQuantity,
            gasLimit: UInt64,
        ) throws(Error) -> Transaction {
            guard let nonce = UInt64(exactly: nonce) else {
                throw .invalidTransaction
            }
            var priorityFee = EVMUInt128()
            var maxFee = EVMUInt128()
            try EVM.writeInteger(maxPriorityFeePerGas, into: &priorityFee)
            try EVM.writeInteger(maxFeePerGas, into: &maxFee)
            return try withExtendedLifetime(self) { () throws(Error) in
                var owner: OpaquePointer?
                try EVM.check(evm_transaction_with_fees(
                    pointer,
                    nonce,
                    gasLimit,
                    priorityFee,
                    maxFee,
                    &owner,
                ))
                guard let owner else {
                    throw .invalidResponse
                }
                return Transaction(pointer: owner)
            }
        }
        
        func cancelling(to destination: EVM.Address) throws(Error) -> Transaction {
            var address = EVMAddressBytes()
            try EVM.copyBytes(destination.data, into: &address)
            return try withExtendedLifetime(self) { () throws(Error) in
                var owner: OpaquePointer?
                try EVM.check(evm_transaction_cancellation(pointer, address, &owner))
                guard let owner else {
                    throw .invalidResponse
                }
                return Transaction(pointer: owner)
            }
        }
        
        func nonce() throws(Error) -> UInt64 {
            try withExtendedLifetime(self) { () throws(Error) in
                try info().nonce
            }
        }
        
        func feeEstimationParameters() throws(Error) -> (to: String, value: String, data: String) {
            try withExtendedLifetime(self) { () throws(Error) in
                let info = try info()
                let to: String
                switch info.has_destination {
                case 0:
                    to = ""
                case 1:
                    let address = withUnsafeBytes(of: info.destination, Data.init(_:))
                    to = try EVM.Address(bytes: address).checksumString
                default:
                    throw .invalidResponse
                }
                let data = info.data.len == 0 ? Data() : Data(bytes: info.data.data!, count: info.data.len)
                return (
                    to: to,
                    value: try EVMQuantity(raw: info.amount).hexQuantity(),
                    data: data.isEmpty ? "" : "0x" + data.hexEncodedString(),
                )
            }
        }
        
        private func info() throws(Error) -> EVMTransactionInfo {
            var info = EVMTransactionInfo()
            try EVM.check(evm_transaction_get_info(pointer, &info))
            return info
        }
        
    }
    
}
