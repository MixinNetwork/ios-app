import XCTest

final class ExternalTransferURLTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    private let bitcoin = "c6d0c728-2624-429b-8e0d-d9d19b6592fa"
    private let ethereum = "43d61dcd-e413-450d-80b8-101d5e903357"
    private let litecoin = "76c802a2-7c88-447f-a93e-c29c9e5dd9c8"
    private let dash = "6472e7e3-75fd-48b6-b1dc-28d294ee1476"
    private let dogcoin = "6770a1e5-6086-44d5-b60f-545f9d9e8ffd"
    private let monero = "05c5ac01-31f9-4a69-aa8a-ab796de1d041"
    private let solana = "64692c23-8971-4cf4-84a7-4dd1271dd887"
    private let xin = "c94ac88f-4671-3976-b60a-09064f1811e8"
    private let usdt = "4d8c508b-91c5-375b-92b0-ee702ed2dac5"
    
    func testParseBitcoin() throws {
        let url1 = "bitcoin:BC1QA7A84SQ2NNKPXUA5DLY6FG553D5V06NSL608SS?amount=0.00186487"
        let result1 = ExternalTransferURL(string: url1)
        checkResult(result: result1, assetId: bitcoin, destination: "BC1QA7A84SQ2NNKPXUA5DLY6FG553D5V06NSL608SS", amount: "0.00186487", needsCheckPrecision: false)
        
        let url2 = "bitcoin:35pkcZ531UWYwVWRGeMG6eXkWbPptFg6AG?amount=0.00173492&fee=5&rbf=false&lightning=LNBC1734920N1P3EC8DGPP5NTUUNWS3GF9XUE4EZ2NCPEJCZHAJRVALFW8ALWFPN29LEE76NV5SDZ2GF5HGUN9VE5KCMPQV9SNYCMZVE3RWTF3XVMK2TF5XGMRJTFCXSCNSTF4VCCXYERYXQ6N2VRPVVCQZX7XQRP9SSP5Q4JSN54FHFQ8TRGHQGDQW2PUV790PXNSFVZG20CW322K0E6L7M8Q9QYYSSQA42ZJEMX44Y6PEW3YHWHXV9JUXTM96DMHKEPMD3LXUQTPH0HGSKX9TVZD2XVG7DETCVN450JXN25FM8G80GRYGU9ZHXC3XURSJ4Z20GPF8SQT7"
        let result2 = ExternalTransferURL(string: url2)
        checkResult(result: result2, assetId: bitcoin, destination: "35pkcZ531UWYwVWRGeMG6eXkWbPptFg6AG", amount: "0.00173492", needsCheckPrecision: false)
        
        let url3 = "LIGHTNING:LNBC1197710N1P36QPY7PP5NZT3GTZMZP00E8NAR0C40DQVS5JT7PWCF7Z4MLXKH6F988QT08MSDZ2GF5HGUN9VE5KCMPQXGENSVFKXPNRXTTRV43NWTF5V4SKVTFEVCUXYTTXXAJNZVM9X4JRGETY8YCQZX7XQRP9SSP5EU7UUK9E5VKGQ2KYTW68D2JHTK7ALWSTFKYFMMSL2FGT22ZLMW9Q9QYYSSQAWC3VFFRPEGE79NLXKRMPVVR8Q9NVUMD4LFF3U2QRJ23A0RUUTGKJ7UCQQTE3RV93JYH20GJFPQHGLL7K2RPJMNYFXAP9NXPC4XQ80GPFE00SQ"
        let result3 = ExternalTransferURL(string: url3)
        XCTAssertNil(result3)
    }
    
    func testParseLitecoin() {
        let url = "litecoin:MAA5rAYDJcfpGShL2fHHyqdH5Sum4hC9My?amount=0.31837321"
        let result = ExternalTransferURL(string: url)
        checkResult(result: result, assetId: litecoin, destination: "MAA5rAYDJcfpGShL2fHHyqdH5Sum4hC9My", amount: "0.31837321", needsCheckPrecision: false)
    }
    
    func testParseDash() {
        let url = "dash:XimNHukVq5PFRkadrwybyuppbree51mByS?amount=0.47098703&IS=1"
        let result = ExternalTransferURL(string: url)
        checkResult(result: result, assetId: dash, destination: "XimNHukVq5PFRkadrwybyuppbree51mByS", amount: "0.47098703", needsCheckPrecision: false)
    }
    
    func testParseDogcoin() {
        let url = "dogecoin:DQDHx7KcDjq1uDR5MC8tHQPiUp1C3eQHcd?amount=258.69"
        let result = ExternalTransferURL(string: url)
        checkResult(result: result, assetId: dogcoin, destination: "DQDHx7KcDjq1uDR5MC8tHQPiUp1C3eQHcd", amount: "258.69", needsCheckPrecision: false)
    }
    
    func testParseMonero() {
        let url = "monero:83sfoqWFNrsGTAyuC3PxHeS9stn8TQiTkiBcizHwjyHN57NczsRJE8UfrnhTUxT5PLBWLnq5yXrtPKeAjWeoDTkCPHGVe1Y?tx_amount=1.61861962"
        let result = ExternalTransferURL(string: url)
        checkResult(result: result, assetId: monero, destination: "83sfoqWFNrsGTAyuC3PxHeS9stn8TQiTkiBcizHwjyHN57NczsRJE8UfrnhTUxT5PLBWLnq5yXrtPKeAjWeoDTkCPHGVe1Y", amount: "1.61861962", needsCheckPrecision: false)
    }
    
    func testParseSolana() {
        let url1 = "solana:mvines9iiHiQTysrwkJjGf2gb9Ex9jXJX8ns3qwf2kN?amount=1&label=Michael&message=Thanks%20for%20all%20the%20fish&memo=OrderId12345"
        let result1 = ExternalTransferURL(string: url1)
        checkResult(result: result1, assetId: solana, destination: "mvines9iiHiQTysrwkJjGf2gb9Ex9jXJX8ns3qwf2kN", amount: "1", needsCheckPrecision: false)
        
        let url2 = "solana:mvines9iiHiQTysrwkJjGf2gb9Ex9jXJX8ns3qwf2kN?amount=0.01&spl-token=EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
        let result2 = ExternalTransferURL(string: url2)
        XCTAssertNil(result2)
        
        let url3 = "solana:mvines9iiHiQTysrwkJjGf2gb9Ex9jXJX8ns3qwf2kN?amount=1e7&label=Michael&message=Thanks%20for%20all%20the%20fish&memo=OrderId12345"
        let result3 = ExternalTransferURL(string: url3)
        XCTAssertNil(result3)
    }
    
    func testParseEthereum() {
        let url1 = "ethereum:0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359?value=2.014e18"
        let result1 = ExternalTransferURL(string: url1)
        checkResult(result: result1, assetId: ethereum, destination: "0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359", amount: "2.014", needsCheckPrecision: false)
        
        // xin
        let url2 = "ethereum:pay-0xa974c709cfb4566686553a20790685a47aceaa33@1/transfer?address=0x00d02d4A148bCcc66C6de20C4EB1CbAB4298cDcc&uint256=2e17&gasPrice=14"
        let result2 = ExternalTransferURL(string: url2)
        checkResult(result: result2, assetId: xin, destination: "0x00d02d4A148bCcc66C6de20C4EB1CbAB4298cDcc", amount: "0.2", needsCheckPrecision: true)
        
        let url3 = "ethereum:43d61dcd-e413-450d-80b8-101d5e903357@1?value=1.697e16&gasPrice=14&label=Bitrefill%2008cba4ee-b6cd-47c8-9768-c82959c0edce"
        let result3 = ExternalTransferURL(string: url3)
        checkResult(result: result3, assetId: ethereum, destination: "43d61dcd-e413-450d-80b8-101d5e903357", amount: "0.01697", needsCheckPrecision: false)
        
        // xin
        let url4 = "ethereum:0xa974c709cfb4566686553a20790685a47aceaa33@1/transfer?address=0xB38F2E40e82F0AE5613D55203d84953aE4d5181B&amount=66&uint256=1e18"
        let result4 = ExternalTransferURL(string: url4)
        checkResult(result: result4, assetId: xin, destination: "0xB38F2E40e82F0AE5613D55203d84953aE4d5181B", amount: "66", needsCheckPrecision: false)
        
        // usdt
        let url5 = "ethereum:0xdac17f958d2ee523a2206206994597c13d831ec7@1/transfer?address=0xB38F2E40e82F0AE5613D55203d84953aE4d5181B&uint256=5e7"
        let result5 = ExternalTransferURL(string: url5)
        checkResult(result: result5, assetId: usdt, destination: "0xB38F2E40e82F0AE5613D55203d84953aE4d5181B", amount: "50", needsCheckPrecision: true)
        
        let url6 = "ethereum:pay-0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48@1/transfer?address=0x50bF16E33E892F1c9Aa7C7FfBaF710E971b86Dd1&gasPrice=14"
        let result6 = ExternalTransferURL(string: url6)
        XCTAssertNil(result6)
        
        let url7 = "ethereum:0xA974c709cFb4566686553a20790685A47acEAA33@1/transfer?address=0xB38F2E40e82F0AE5613D55203d84953aE4d5181B&amount=66e10&uint256=1e18"
        let result7 = ExternalTransferURL(string: url7)
        XCTAssertNil(result7)
    }
    
    func checkResult(result: ExternalTransferURL!, assetId: String, destination: String, amount: String, needsCheckPrecision: Bool) {
        XCTAssertNotNil(result)
        XCTAssertEqual(result.assetId, assetId)
        XCTAssertEqual(result.destination, destination)
        XCTAssertEqual(result.needsCheckPrecision, needsCheckPrecision)
        if result.needsCheckPrecision {
            let precision: Int
            if assetId == xin {
                precision = 18
            } else if assetId == usdt {
                precision = 6
            } else {
                precision = 1
            }
            if let value = Decimal(string: result.amount) {
                let newAmount = "\(value / pow(Decimal(10), precision))"
                XCTAssertEqual(newAmount, amount)
            }
        } else {
            XCTAssertEqual(result.amount, amount)
        }
    }
    
}
