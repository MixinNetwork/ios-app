//
//  MixinTests.swift
//  MixinTests
//
//  Created by wu on 2025/7/15.
//  Copyright © 2025 Mixin. All rights reserved.
//

import Testing
import CommonCrypto
import CryptoKit
@testable import Mixin
@testable import MixinServices

struct MixinTests {
    
    @Test func testP2PKHDerivation() {
        let seed = Data(hexEncodedString: "67f93560761e20617de26e0cb84f7234aaf373ed2e66295c3d7397e6d7ebe882ea396d5d293808b0defd7edd2babd4c091ad942e6a9351e6d075a29d4df872af")!
        let key = ExtendedKey(seed: seed, curve: .secp256k1)
        let addresses = try! (0..<20).map { (index: UInt32) in
            let path = try DerivationPath(string: "m/44'/0'/0'/0/\(index)")
            let publicKey = try key.deriveUsingSecp256k1(path: path).publicKey()
            return P2PKH.address(of: publicKey)
        }
        let expectation = [
            "1AZnveys2k5taGCCF743RtrWGwc58UMeq",
            "1AMYJTJyV4o1hwNACJtfdXBW6BiD1f5FXb",
            "1NPFFtSiFRatoeUf35rwYb8j8C1u7sVhGa",
            "1L44VTYEzWesp8cxnXcPGbUzuwTYoSW9at",
            "1FK85vpZavzZu6oBCvBcmD4FWXQT5fVYRu",
            "12QaHfWLtyuMwNXuap3FscMY434bw4TS6n",
            "1NeFG5BYAR9bnjAG72SDYKvNZBH4kPa8r1",
            "1yF3BiHqbQKL4aRfNYHQt4ZpgNagC4nQe",
            "144vmUhuAZJsV3m2GsP5Kqp55Pmzwx2gna",
            "1DQM5w6C7gNaCKBxQV3rXKftcamRKDPQ2M",
            "17XRvBac5xpgMVr6LbsDA56fgsaAed4oEV",
            "1BSQC3Qn38UT2WVfcM6LdybkfE7tTGW5M2",
            "1KUG4EDePnG97xQNXtuU9Xmp4sThqFvSoS",
            "18sXnPcBnXBRFBYbqr85aKPPNpwT4f52a8",
            "15S2gpAVvprN1GPE44oXCdtkA4L7yQtBkX",
            "1FvC2STfbj7dcr2ApAPhagnSCP5Dmy79nH",
            "15VZHWTEjnQuJSvUHzS7K6gmYjNv4A5cVJ",
            "1N4S7Z43gb22PDCcpjHhX25cgDSLxegdWm",
            "1MzS2BktGqokVM4kDuB6VavjLuib72W2je",
            "1GDLeWJ4FcK2uiTFvLshtVcBArA7M9ECxq",
        ]
        #expect(addresses == expectation)
    }
    
    @Test func testEthereumDerivation() {
        let seed = Data(hexEncodedString: "67f93560761e20617de26e0cb84f7234aaf373ed2e66295c3d7397e6d7ebe882ea396d5d293808b0defd7edd2babd4c091ad942e6a9351e6d075a29d4df872af")!
        let key = ExtendedKey(seed: seed, curve: .secp256k1)
        let addresses = try! (0..<20).map { (index: UInt32) in
            let path = try DerivationPath(string: "m/44'/60'/0'/0/\(index)")
            let derivation = try key.deriveUsingSecp256k1(path: path)
            return derivation.key.hexEncodedString()
        }
        let expectation = [
            "322ae50bf8cd9772f46aefde87f0f7d1718ad7ff32e44dc8a81286a0c3867eb4",
            "05ff1dde0918cf4cdbe460c324eefedbfa09cc3412e3de06908b1381c879d18d",
            "651c53a2331f431081e56bf18631bbf33b5f42bcaecb6cbe592c9b0887febef9",
            "46f3c97eb2130b9d65661ab7942ccdd8dc70c35e68417d65eb88345bca816fc8",
            "568b468ba48cd3c899bf7af7c67de4f24a17b2efadc9b795259231b10fcb2593",
            "eb50a6aa07b57dc0db072bc4c9d9e05244cdc066b934db4c60f93d85222ed37c",
            "51cc51e38a5aa270effe9224351d986cb409428c470c71f2aa9ffef72828a5ec",
            "5944991366e19b8256fc37e0e9be48a4c89fa2bbc31fee9f3e63040e6dc30492",
            "da3bdd11fd7398b3b75cdac5d3ce65d00a219a159e7ceab3cab0db059ba131fe",
            "5cc51856968b847cd7a598babf9e85baa7726295f80f23f0852c97150e941917",
            "cc2e595a7a846be6fa2e6a89f6fa8f821a1092723aa785fde478300966a9acfd",
            "3899c6abfeccd6e4a1267b417871358d7eb654b85a1133aa51d5d7e66cba0ac2",
            "a8d76b19791b1f67627b91d30bc77144a1e54f110f6d5e1c3078ef83eb34148e",
            "1d46eea92df793067ff47a6bf1d032f8ac9069112cc313bbd882c3437b2a780a",
            "221bb43c31de32ebe7f1745a86aef9b53ab73ab9566fb87370e3d34592bfb5d3",
            "a2e6b0d555bbb9fbbe2b3da9226eb6dff20a1b821c82a5b66334f007f3f77b6b",
            "246ce231da88f00970978a3b7ebd18f62341e4819a3376c699cab00a1007f67c",
            "2f0975c720429921a9d19c36f3824a3a838954681eb1625e94e8a56956a1d0ed",
            "46315db4a72805aefac61197175f5693136fe91b2c3677b70ba088df60a8ed84",
            "a2e392cf1425ab9baf126c6ed9eb0924ad3a25ce52e3cb7e76495095d9d91f7c",
        ]
        #expect(addresses == expectation)
    }
    
    @Test func testSolanaDerivation() throws {
        let phrases = "legal winner thank year wave sausage worth useful legal winner thank yellow"
            .components(separatedBy: " ")
        let mnemonics = try BIP39Mnemonics(phrases: phrases)
        let solAddress = try mnemonics.checkedDerivationForSolana(path: DerivationPath(string: "m/44'/501'/1'/0'")).address
        #expect(solAddress == "EdjcxP8MmXP4yRHguEVoH75kbXVfZNFXPgNfL9NqcXXK")
        for i in 0..<10 {
            let path = try DerivationPath(string: "m/44'/501'/\(i)'/0'")
            let solAddress = try mnemonics.checkedDerivationForSolana(path: path).address
            let output = "\(path.string) => \(solAddress)"
            switch i {
            case 0:
                #expect(output == "m/44'/501'/0'/0' => BLeUXTx9thHGT7VJUtF9vHEmfMDgW1nnKZ9UVer2CoLX")
            case 1:
                #expect(output == "m/44'/501'/1'/0' => EdjcxP8MmXP4yRHguEVoH75kbXVfZNFXPgNfL9NqcXXK")
            case 2:
                #expect(output == "m/44'/501'/2'/0' => AFG4eoTGSCdNemYFQhhJBqT7tJwo3WdC4Raeq9SkXx7p")
            case 3:
                #expect(output == "m/44'/501'/3'/0' => gBXdHgqD3g2ChGjHveWiPXSGMRXRTNwbieiBWtKVtzJ")
            case 4:
                #expect(output == "m/44'/501'/4'/0' => 9c8ixKiHZ7vuydxovD32uGGi4Hn1BkpdyZeUy9jkTLtw")
            case 5:
                #expect(output == "m/44'/501'/5'/0' => BnWk78yTZn6PmKnFQ1j2fqL4ZXekhQ6VYZVDNtU7d6Cq")
            case 6:
                #expect(output == "m/44'/501'/6'/0' => 6h5ScC2T65UKvJNnajrttU7rBhq1kCgaBGtw9z9s4K6L")
            case 7:
                #expect(output == "m/44'/501'/7'/0' => GPAJ4A3YSzzVYeTigrfxB91j8ELPcqHCCq13vJvJhna1")
            case 8:
                #expect(output == "m/44'/501'/8'/0' => HBWQTWgxLGy5JpvicSvHCZcmBjMN11shqBiGSaVvQtPJ")
            case 9:
                #expect(output == "m/44'/501'/9'/0' => EMcYx649Zj64Tk32Xg6c7eYkLyJ7y2qjpnrQVcqCvJKA")
            default:
                break
            }
        }
    }
    
    @Test func testSavingMnemonics() throws {
        let phrases = ["legal", "winner", "thank", "year", "wave", "sausage", "worth", "useful", "legal", "winner", "thank", "yellow"]
        let spendKey = Data(hexEncodedString: "0f09874fa3dc875b9594cd956977decda74e12dea331cef4585649f27b200950")!
        let key = Data(SHA256.hash(data: spendKey))
        let nonce = try AES.GCM.Nonce(data: Data(hexEncodedString: "d20167853779cde83da34ff3")!)
        
        let mnemonics = try BIP39Mnemonics(phrases: phrases)
        #expect(mnemonics.entropy == Data(hexEncodedString: "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f")!)
        let encryptedMnemonics = try EncryptedBIP39Mnemonics(mnemonics: mnemonics, key: key, nonce: nonce)
        #expect(encryptedMnemonics.data == Data(hexEncodedString: "d20167853779cde83da34ff313f98e144e0c78360c41e8d75ebfa8ebeccd5ab6639458880ab9e854fc7d00ee")!)
        let decrypted = try encryptedMnemonics.decrypt(with: key)
        #expect(decrypted.entropy == mnemonics.entropy)
        #expect(decrypted.phrases == phrases)
    }
    
    @Test func testExportPrivateKey() throws {
        let phrases = ["legal", "winner", "thank", "year", "wave", "sausage", "worth", "useful", "legal", "winner", "thank", "yellow"]
        let mnemonics = try BIP39Mnemonics(phrases: phrases)
        
        let evmPath = try DerivationPath(string: "m/44'/60'/0'/0/0")
        let evmPrivateKey = try mnemonics.checkedDerivationForEVM(path: evmPath).privateKey
        let evmKey = "0x" + evmPrivateKey.hexEncodedString()
        #expect(evmKey == "0x33fa40f84e854b941c2b0436dd4a256e1df1cb41b9c1c0ccc8446408c19b8bf9")
        
        let solanaPath = try DerivationPath(string: "m/44'/501'/0'/0'")
        let solanaDerivation = try mnemonics.checkedDerivationForSolana(path: solanaPath)
        let solanaKey = try Solana.keyPair(derivation: solanaDerivation)
        #expect(solanaKey == "37NfN7eam3KCwdC6jAc7nFeuDNYCV1K2AgNWmT4Xo6ogQPMnJ1ZoWA7AKN6jzEoQi3FNTEkkXiwu7VjqXdu8FGUs")
    }
    
    @Test func testGroupConversationID() {
        let ownerID = "c8cb0ac7-d456-4341-be66-0b143aa09922"
        let groupName = "Mixin Rocks"
        let participantUserIDs = [
            "f937ca18-d1ff-46f5-99e8-e23fbd6fd5f2",
            "0e0a20c8-31b8-4093-81b8-9cebd9bc8afc",
            "8391e472-cdbe-4704-be1f-7d184635b885",
            "831fdb67-13ed-4dc5-ac64-dda89aeda2bb",
            "f7ff9dde-18c2-4375-8097-b364068b120e",
            "088c1e3e-1f07-4065-85b5-6b49b4370d32",
        ]
        let randomID = "01d21e2c-76f5-4940-8ea0-9b7f21728674"
        let conversationID = NewGroupViewController.groupConversationID(
            ownerID: ownerID,
            groupName: groupName,
            participantUserIDs: participantUserIDs,
            randomID: randomID
        )
        #expect(conversationID == "5dac944e-2037-31b4-bbd9-e5fd3ffe571e")
    }
    
}
