//
//  EVMTests.swift
//  Mixin
//
//  Created by wu on 2026/11/2.
//  Copyright © 2026 Mixin. All rights reserved.
//

import Testing
import UIKit
import CommonCrypto
import CryptoKit
import TIP
import WalletConnectSigner
import WalletConnectSign
@testable import Mixin
@testable import MixinServices

struct EVMTests {
    
    @Test func walletConnectPublicKeyRecovery() throws {
        let provider = Web3CryptoProvider()
        let message = Data("\u{19}Ethereum Signed Message:\n7Message".utf8)
        let serialized = try #require(Data(hexEncodedString: "66121e60cccc01fbf7fcba694a1e08ac5db35fb4ec6c045bedba7860445b95c021cad2c595f0bf68ff896964c7c02bb2f3a3e9540e8e4595c98b737ce264cc541b"))
        let signature = EthereumSignature(serialized: serialized)
        let publicKey = try provider.recoverPubKey(signature: signature, message: message)
        #expect(publicKey.count == 64)
        #expect(provider.keccak256(publicKey).suffix(20).hexEncodedString() == "15bca56b6e2728aec2532df9d436bd1600e86688")
        let wrongKey = try provider.recoverPubKey(signature: signature, message: Data("Wrong message".utf8))
        #expect(wrongKey != publicKey)
        let invalidSignatures = [
            EthereumSignature(v: 0, r: [], s: signature.s),
            EthereumSignature(v: 255, r: signature.r, s: signature.s),
            EthereumSignature(v: 0, r: [UInt8](repeating: 0, count: 32), s: signature.s),
        ]
        for signature in invalidSignatures {
            #expect(throws: EVM.Error.self) {
                try provider.recoverPubKey(signature: signature, message: message)
            }
        }
    }
    
    @Test func addressAndGaslessSignatureVector() throws {
        let privateKey = try #require(Data(hexEncodedString: "774681694ad86635346b6e9b92fa8aa4806265336dc6766623029a6264a162c1"))
        let hash = try #require(Data(hexEncodedString: "9dd2c369a187b4e6b9c402f030e50743e619301ea62aa4c0737d4ef7e10a3d49"))
        let signature = try EVM.signHash(hash, privateKey: privateKey)
        // Existing web3.swift vector, with the gasless API's 27/28 recovery byte.
        #expect(signature == "0x16f89ddb9bf9ec08ff696bc766e675da7cfcb4f0b10bc8ce7c1a87a414a65a4f19c05c207e1b59f2e1cd18053cb8406fb7c6d22cec5e348d6217febbff8fc1981c")
        #expect(throws: EVM.Error.self) {
            try EVM.signHash(Data([1]), privateKey: privateKey)
        }
        #expect(throws: EVM.Error.self) {
            try EVM.address(privateKey: Data(repeating: 0, count: 32))
        }
        let key = Data(repeating: 0, count: 31) + Data([1])
        #expect(try EVM.address(privateKey: key).checksumString == "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf")
        #expect(try EVM.Address("0x52908400098527886e0f7030069857d2e4169ee7").checksumString == "0x52908400098527886E0F7030069857D2E4169EE7")
    }
    
    @Test func signingUsesOnlyTheSuppliedKeyAndMessageMode() throws {
        let firstKey = Data(repeating: 0, count: 31) + Data([1])
        let secondKey = Data(repeating: 0, count: 31) + Data([2])
        let message = Data(repeating: 0xab, count: 32)
        let firstSignature = try EVM.signPersonalMessage(message, privateKey: firstKey)
        let secondSignature = try EVM.signPersonalMessage(message, privateKey: secondKey)
        #expect(firstSignature != secondSignature)
        #expect(try EVM.signPersonalMessage(message, privateKey: firstKey) == firstSignature)
        #expect(try EVM.signHash(message, privateKey: firstKey) != firstSignature)
        #expect(throws: EVM.Error.self) {
            try EVM.signPersonalMessage(message, privateKey: Data())
        }
    }
    
    @Test func addressesUseBinaryIdentityAndChecksumSerialization() throws {
        let expected = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"
        let lowercased = try EVM.Address(expected.lowercased())
        let uppercased = try EVM.Address(expected.uppercased())
        let checksummed = try EVM.Address(expected)
        let withoutPrefix = try EVM.Address(String(expected.dropFirst(2)))
        #expect(lowercased.checksumString == expected)
        #expect(lowercased == uppercased)
        #expect(lowercased == checksummed)
        #expect(lowercased == withoutPrefix)
        #expect(Set([lowercased, uppercased, checksummed]).count == 1)
        #expect(lowercased.data.count == 20)
        #expect(lowercased.data.hexEncodedString() == expected.dropFirst(2).lowercased())
        #expect(try EVM.Address(bytes: lowercased.data) == lowercased)
        let input = try JSONEncoder().encode(expected.lowercased())
        let decoded = try JSONDecoder().decode(EVM.Address.self, from: input)
        #expect(decoded == checksummed)
        let output = try JSONEncoder().encode(decoded)
        #expect(try JSONDecoder().decode(String.self, from: output) == expected)
        #expect(try EVM.Address("0x" + String(repeating: "0", count: 40)).data == Data(repeating: 0, count: 20))
    }
    
    @Test func addressesRejectMalformedInput() throws {
        let valid = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"
        let invalidAddresses = [
            "", "0x", "0x00",
            "0x" + String(repeating: "a", count: 39),
            "0x" + String(repeating: "a", count: 41),
            "0x" + String(repeating: "g", count: 40),
            " " + valid, valid + " ", valid + "\0",
        ]
        for input in invalidAddresses {
            #expect(throws: EVM.Error.self) { try EVM.Address(input) }
            let encoded = try JSONEncoder().encode(input)
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(EVM.Address.self, from: encoded)
            }
        }
        for count in [0, 19, 21] {
            #expect(throws: EVM.Error.self) {
                try EVM.Address(bytes: Data(repeating: 0, count: count))
            }
        }
    }
    
    @Test func externalAddressesUseBinaryValuesAndChecksumSerialization() throws {
        let expected = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"
        let transaction = try ExternalEVMTransaction(json: [
            "from": expected.lowercased(),
            "to": expected.lowercased(),
            "accessList": [["address": expected.lowercased(), "storageKeys": []]],
        ])
        #expect(transaction.from.checksumString == expected)
        #expect(transaction.to?.checksumString == expected)
        let data = try JSONEncoder().encode(transaction)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["from"] as? String == expected)
        #expect(object["to"] as? String == expected)
        let decoded = try JSONDecoder().decode(ExternalEVMTransaction.self, from: data)
        #expect(decoded.from == transaction.from)
        #expect(decoded.to == transaction.to)
        #expect(throws: EVM.Error.self) {
            try ExternalEVMTransaction(json: ["from": expected, "to": "invalid"])
        }
    }
    
    @Test func transactionWireFormatAndEmptyData() throws {
        let transaction = try EVM.Transaction(
            chainID: 1,
            nonce: 0,
            maxPriorityFeePerGas: 1,
            maxFeePerGas: 2,
            gasLimit: 21000,
            destination: try EVM.Address("0x0000000000000000000000000000000000000001"),
            amount: 1,
            data: Data(),
        )
        let raw = try transaction.encoded()
        #expect(raw.hexEncodedString() == "02df018001028252089400000000000000000000000000000000000000010180c0")
        #expect(try EVM.Transaction(rawTransaction: "0x" + raw.hexEncodedString()).encoded() == raw)
        let privateKey = Data(repeating: 0, count: 31) + Data([1])
        let signed = try transaction.sign(privateKey: privateKey)
        #expect(try EVM.Transaction(rawTransaction: "0x" + signed.hexEncodedString()).encoded() == transaction.encoded())
        #expect(throws: EVM.Error.self) {
            try EVM.Transaction(rawTransaction: "0x" + signed.hexEncodedString() + "00")
        }
        #expect(EVM.data(hex: "0x") == Data())
    }
    
    @Test func contractCreationAndIntegerLimitsRoundTrip() throws {
        let transaction = try EVM.Transaction(
            chainID: 137,
            nonce: 7,
            maxPriorityFeePerGas: try #require(EVMQuantity(hex: "1" + String(repeating: "0", count: 25))),
            maxFeePerGas: try #require(EVMQuantity(hex: String(repeating: "f", count: 32))),
            gasLimit: UInt64.max,
            destination: nil,
            amount: try #require(EVMQuantity(hex: String(repeating: "f", count: 64))),
            data: Data([0x60, 0x00]),
        )
        let privateKey = Data(repeating: 0, count: 31) + Data([1])
        let signed = try transaction.sign(privateKey: privateKey)
        let decoded = try EVM.Transaction(rawTransaction: "0x" + signed.hexEncodedString())
        #expect(try decoded.encoded() == transaction.encoded())
    }
    
    @Test func typedTransactionRejectsIntegerOverflow() throws {
        let overflowingFee = try #require(EVMQuantity(hex: "1" + String(repeating: "0", count: 32)))
        let invalidFields: [(chainID: Int, nonce: Int, fee: EVMQuantity)] = [
            (-1, 0, 1),
            (1, -1, 1),
            (1, 0, overflowingFee),
        ]
        for fields in invalidFields {
            #expect(throws: EVM.Error.self) {
                _ = try EVM.Transaction(
                    chainID: fields.chainID,
                    nonce: fields.nonce,
                    maxPriorityFeePerGas: fields.fee,
                    maxFeePerGas: fields.fee,
                    gasLimit: 21000,
                    destination: nil,
                    amount: 0,
                    data: Data(),
                )
            }
        }
    }
    
    @Test func externalTransactionIgnoresAccessList() throws {
        let address = "0x0000000000000000000000000000000000000001"
        let json: [String: Any] = [
            "from": address,
            "data": "0x",
            "accessList": [[
                "address": address,
                "storageKeys": ["0x" + String(repeating: "ab", count: 32)],
            ]],
        ]
        let transaction = try ExternalEVMTransaction(json: json)
        #expect(transaction.to == nil)
        #expect(transaction.data == Data())
        let encoded = try JSONEncoder().encode(transaction)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["accessList"] == nil)
        let decoded = try JSONDecoder().decode(
            ExternalEVMTransaction.self,
            from: JSONSerialization.data(withJSONObject: json),
        )
        #expect(decoded.from == transaction.from)
        #expect(decoded.data == transaction.data)
    }
    
    @Test func externalTransactionIgnoresMalformedAccessLists() throws {
        let address = "0x0000000000000000000000000000000000000001"
        let accessLists: [Any] = ["invalid", 42, true, ["address": address], NSNull()]
        for accessList in accessLists {
            let json: [String: Any] = [
                "from": address,
                "to": address,
                "value": "0x1",
                "accessList": accessList,
            ]
            let transaction = try ExternalEVMTransaction(json: json)
            let decoded = try JSONDecoder().decode(
                ExternalEVMTransaction.self,
                from: JSONSerialization.data(withJSONObject: json),
            )
            #expect(transaction.from.checksumString == address)
            #expect(decoded.to == transaction.to)
            #expect(decoded.value == 1)
        }
    }
    
    @Test func decodedTransactionsUseEmptyAccessLists() throws {
        // Unsigned EIP-1559 transaction containing two access-list entries.
        let raw = "0x02f871010701028275309400000000000000000000000000000000000000010382abcdf84ff7940000000000000000000000000000000000000001e1a0ababababababababababababababababababababababababababababababababd694aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaac0"
        let transaction = try EVM.Transaction(rawTransaction: raw)
        let expected = try EVM.Transaction(
            chainID: 1,
            nonce: 7,
            maxPriorityFeePerGas: 1,
            maxFeePerGas: 2,
            gasLimit: 30000,
            destination: try EVM.Address("0x0000000000000000000000000000000000000001"),
            amount: 3,
            data: Data([0xab, 0xcd]),
        )
        #expect(try transaction.encoded() == expected.encoded())
        let updated = try transaction.updating(
            nonce: 7,
            maxPriorityFeePerGas: 3,
            maxFeePerGas: 4,
            gasLimit: 40000,
        )
        let expectedUpdate = try expected.updating(
            nonce: 7,
            maxPriorityFeePerGas: 3,
            maxFeePerGas: 4,
            gasLimit: 40000,
        )
        #expect(try updated.encoded() == expectedUpdate.encoded())
        let privateKey = Data(repeating: 0, count: 31) + Data([1])
        #expect(try updated.sign(privateKey: privateKey) == expectedUpdate.sign(privateKey: privateKey))
    }
    
    @Test func ownedTransactionUpdatesPreserveTheOriginal() throws {
        let original = try EVM.Transaction(
            chainID: 137,
            nonce: 7,
            maxPriorityFeePerGas: 1,
            maxFeePerGas: 2,
            gasLimit: 21000,
            destination: nil,
            amount: 3,
            data: Data([0x60, 0x00]),
        )
        let raw = try original.encoded()
        let updated = try original.updating(
            nonce: 8,
            maxPriorityFeePerGas: 3,
            maxFeePerGas: 4,
            gasLimit: 75000,
        )
        #expect(try original.encoded() == raw)
        #expect(try original.nonce() == 7)
        #expect(try updated.nonce() == 8)
        #expect(try updated.encoded() != raw)
        let originalParameters = try original.feeEstimationParameters()
        let updatedParameters = try updated.feeEstimationParameters()
        #expect(originalParameters.to.isEmpty)
        #expect(originalParameters.value == updatedParameters.value)
        #expect(originalParameters.data == updatedParameters.data)
        let cancellation = try updated.cancelling(
            to: try EVM.Address("0x0000000000000000000000000000000000000001"),
        )
        let parameters = try cancellation.feeEstimationParameters()
        #expect(try cancellation.nonce() == 8)
        #expect(parameters.to == "0x0000000000000000000000000000000000000001")
        #expect(parameters.value == "0x0")
        #expect(parameters.data.isEmpty)
        let privateKey = Data(repeating: 0, count: 31) + Data([1])
        let signature = try updated.sign(privateKey: privateKey)
        let otherKey = Data(repeating: 0, count: 31) + Data([2])
        #expect(try updated.sign(privateKey: otherKey) != signature)
        #expect(try updated.sign(privateKey: privateKey) == signature)
        #expect(try EVM.Transaction(rawTransaction: "0x" + signature.hexEncodedString()).encoded() == updated.encoded())
        #expect(throws: EVM.Error.self) {
            try updated.updating(
                nonce: -1,
                maxPriorityFeePerGas: 1,
                maxFeePerGas: 2,
                gasLimit: 21000,
            )
        }
    }
    
    @Test func quantitiesPreserveFullWidthAndRejectOverflow() throws {
        let decimal = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        let maximum = try #require(EVMQuantity(decimal))
        #expect(maximum.bigEndian == Data(repeating: 255, count: 32))
        #expect(try maximum.decimalString() == decimal)
        #expect(try maximum.hexQuantity() == "0x" + String(repeating: "f", count: 64))
        #expect(try EVMQuantity(0).hexQuantity() == "0x0")
        #expect(try EVMQuantity(0).decimalString() == "0")
        #expect(try EVMQuantity(UInt64.max).decimalString() == "18446744073709551615")
        #expect(try EVMQuantity(21000).multiplied(by: 30000000000).decimalString() == "630000000000000")
        #expect(try EVMQuantity(100).divided(by: 3) == 33)
        #expect(EVMQuantity(hex: "0x000aBc") == EVMQuantity(2748))
        #expect(EVMQuantity(hex: "1" + String(repeating: "0", count: 64)) == nil)
        #expect(EVMQuantity("115792089237316195423570985008687907853269984665640564039457584007913129639936") == nil)
        for invalid in ["", "-1", "+1", "1.0", "1e2", " 1", "1\0"] {
            #expect(EVMQuantity(invalid) == nil)
        }
        #expect(throws: EVM.Error.self) { try maximum.multiplied(by: 2) }
        #expect(throws: EVM.Error.self) { try maximum.divided(by: 0) }
    }
    
    @Test func externalQuantitiesAndGasLimitsRoundTrip() throws {
        let address = "0x0000000000000000000000000000000000000001"
        let original = try ExternalEVMTransaction(json: [
            "from": address,
            "to": address,
            "value": "0x10000000000000000",
            "gas": "0xffffffffffffffff",
            "data": "0x00ff",
        ])
        #expect(try original.value?.decimalString() == "18446744073709551616")
        #expect(original.gas == UInt64.max)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExternalEVMTransaction.self, from: encoded)
        #expect(decoded.value == original.value)
        #expect(decoded.gas == original.gas)
        #expect(decoded.data == original.data)
        #expect(decoded.decimalValue == original.decimalValue)
        #expect(throws: ExternalEVMTransaction.Error.self) {
            try ExternalEVMTransaction(json: ["from": address, "gas": "0x10000000000000000"])
        }
        #expect(throws: ExternalEVMTransaction.Error.self) {
            try ExternalEVMTransaction(json: ["from": address, "value": "0x1" + String(repeating: "0", count: 64)])
        }
    }
    
    @Test func typedDataPreservesLargeIntegerLiterals() throws {
        let amount = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        let json = """
        {"types":{"EIP712Domain":[],"Amount":[{"name":"amount","type":"uint256"}]},"primaryType":"Amount","domain":{},"message":{"amount":\(amount)}}
        """
        let numeric = try EVMTypedData(json: Data(json.utf8), chainID: 1)
        let quoted = try EVMTypedData(
            json: Data(json.replacingOccurrences(of: amount, with: "\"" + amount + "\"").utf8),
            chainID: 1,
        )
        let privateKey = Data(repeating: 0, count: 31) + Data([1])
        let signature = try EVM.signTypedData(numeric, chainID: 1, privateKey: privateKey)
        #expect(try EVM.signTypedData(quoted, chainID: 1, privateKey: privateKey) == signature)
        #expect(try EVM.signTypedData(numeric, chainID: 42161, privateKey: privateKey) == signature)
        #expect(numeric.description.contains(amount))
        #expect(throws: EVM.Error.self) {
            try EVMTypedData(json: Data("{}".utf8), chainID: 1)
        }
    }
    
    @Test func typedDataChecksChainIDBeforePreviewAndSigning() throws {
        let json = #"""
        {"types":{"EIP712Domain":[{"name":"chainId","type":"uint256"}],"Message":[{"name":"text","type":"string"}]},"primaryType":"Message","domain":{"chainId":42161},"message":{"text":"Hello, \"world\"!"}}
        """#
        let privateKey = Data(repeating: 0, count: 31) + Data([1])
        let canonical = try EVMTypedData(json: Data(json.utf8), chainID: 42161)
        let signature = try EVM.signTypedData(canonical, chainID: 42161, privateKey: privateKey)
        for chainID in ["42161", "42161.0", "4.2161e4", "\"42161\"", "\"0xa4b1\"", "\"0xA4B1\""] {
            let data = Data(json.replacingOccurrences(of: ":42161", with: ":" + chainID).utf8)
            let typedData = try EVMTypedData(json: data, chainID: 42161)
            #expect(try EVM.signTypedData(typedData, chainID: 42161, privateKey: privateKey) == signature)
        }
        for chainID in [
            "1", "\"1\"", "\"0x1\"", "null", "true", "[]", "{}", "1.5", "-1",
            "\"\"", "\"0x\"", "\"0xzz\"", "\"1.0\"", "42161.000000000000000000000001",
        ] {
            let data = Data(json.replacingOccurrences(of: ":42161", with: ":" + chainID).utf8)
            #expect(throws: EVM.Error.self) {
                try EVMTypedData(json: data, chainID: 42161)
            }
        }
        #expect(throws: EVM.Error.self) {
            try EVM.signTypedData(canonical, chainID: 1, privateKey: privateKey)
        }
    }
    
    @Test func walletConnectTypedDataUsesRequestChain() throws {
        let json = #"{"types":{"EIP712Domain":[{"name":"chainId","type":"uint256"}],"Message":[{"name":"text","type":"string"}]},"primaryType":"Message","domain":{"chainId":"0xa4b1"},"message":{"text":"Hello, \"world\"!"}}"#
        for method in ["eth_signTypedData", "eth_signTypedData_v4"] {
            let matching = try WalletConnectSign.Request(
                topic: "test",
                method: method,
                params: AnyCodable(["0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf", json, ""]),
                chainId: Web3Chain.arbitrumOne.caip2,
            )
            let decoded = try WalletConnectDecodedSigningRequest.ethSignTypedData(request: matching)
            #expect(decoded.chain == .arbitrumOne)
            #expect(decoded.humanReadable.contains("world"))
            let mismatching = try WalletConnectSign.Request(
                topic: "test",
                method: method,
                params: matching.params,
                chainId: Web3Chain.ethereum.caip2,
            )
            #expect(throws: EVM.Error.self) {
                try WalletConnectDecodedSigningRequest.ethSignTypedData(request: mismatching)
            }
        }
    }
    
    @Test func gaslessTransferAmountsPreserveUnitsAndRejectRounding() throws {
        #expect(try EVM.gaslessTransferAmount(Decimal(string: "1.25")!, precision: 6) == EVMQuantity("1250000"))
        #expect(try EVM.gaslessTransferAmount(1, precision: 18) == EVMQuantity("1000000000000000000"))
        #expect(try EVM.gaslessTransferAmount(0, precision: 6) == 0)
        let preciseAmount = try #require(Decimal(string: "12345678901234567890.123456789012345678"))
        #expect(try EVM.gaslessTransferAmount(preciseAmount, precision: 18) == EVMQuantity("12345678901234567890123456789012345678"))
        for (amount, precision): (Decimal, Int16) in [
            (-1, 18), (Decimal(string: "0.0000001")!, 6),
            (1, -1), (1, 256), (1, 78), (.nan, 18),
        ] {
            #expect(throws: EVM.Error.self) {
                try EVM.gaslessTransferAmount(amount, precision: precision)
            }
        }
    }
    
    @Test func gaslessTransferValidationUsesRebuiltHashesAndConfirmedFields() throws {
        // The user-operation vector is produced by an independent EIP-712 encoder.
        let json = #"""
        {
          "signing": {
            "userOperation": {
              "message": "0x3ae5154e1f40ed8838a70dc8f2585ad90320652984302b8965f21fa26f81380d",
              "signType": ""
            }
          },
          "userOperation": {
            "callData": "0xb61d27f60000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000",
            "callGasLimit": "0x186a0",
            "initCode": "0x7702",
            "maxFeePerGas": "0x3b9aca00",
            "maxPriorityFeePerGas": "0x5f5e100",
            "nonce": "0x0",
            "paymasterAndData": "0x22222222222222222222222222222222222222220000000000000000000000000000000000000000000000000000000000000000",
            "preVerificationGas": "0xc350",
            "sender": "0xe6cae83bde06e4c305530e199d7217f42808555b",
            "signature": "0x",
            "verificationGasLimit": "0x30d40"
          }
        }
        """#
        let sender = try EVM.Address("0xe6cae83bde06e4c305530e199d7217f42808555b")
        let recipient = try EVM.Address("0x1111111111111111111111111111111111111111")
        let payload = try JSONDecoder().decode(GaslessTransactionEVMPayload.self, from: Data(json.utf8))
        let hashes = try EVM.validateGaslessTransfer(
            payload,
            chainID: 1,
            sender: sender,
            recipient: recipient,
            token: nil,
            amount: 100,
            feeToken: nil,
            feeAmount: 2,
        )
        #expect(hashes.userOperation.hexEncodedString() == "3ae5154e1f40ed8838a70dc8f2585ad90320652984302b8965f21fa26f81380d")
        #expect(hashes.authorization == nil)
        for (chainID, amount, destination) in [(0, 100, recipient), (8453, 100, recipient), (1, 101, recipient), (1, 100, sender)] {
            #expect(throws: EVM.Error.self) {
                try EVM.validateGaslessTransfer(
                    payload,
                    chainID: chainID,
                    sender: sender,
                    recipient: destination,
                    token: nil,
                    amount: EVMQuantity(UInt64(amount)),
                    feeToken: nil,
                    feeAmount: 2,
                )
            }
        }
        let authorizationHash = "0x5ff19acadaf683f545b800216672c273bcb8563df38a3f451ad080f8b936979b"
        for authorization in [
            GaslessTransactionEVMPayload.Signing.EIP7702Auth(
                signType: nil,
                message: authorizationHash,
                chainID: "1",
                address: sender.checksumString,
                nonce: "0",
            ),
            .init(signType: nil, message: "", chainID: nil, address: nil, nonce: nil),
        ] {
            let candidate = GaslessTransactionEVMPayload(
                userOperation: payload.userOperation,
                signing: .init(userOperation: payload.signing.userOperation, eip7702Auth: authorization),
            )
            let hashes = try EVM.validateGaslessTransfer(
                candidate,
                chainID: 1,
                sender: sender,
                recipient: recipient,
                token: nil,
                amount: 100,
                feeToken: nil,
                feeAmount: 2,
            )
            #expect(hashes.authorization == (authorization.message == "" ? nil : EVM.data(hex: authorizationHash)))
        }
    }
    
}
