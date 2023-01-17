import XCTest

fileprivate let btc = "c6d0c728-2624-429b-8e0d-d9d19b6592fa"
fileprivate let eth = "43d61dcd-e413-450d-80b8-101d5e903357"
fileprivate let ltc = "76c802a2-7c88-447f-a93e-c29c9e5dd9c8"
fileprivate let dash = "6472e7e3-75fd-48b6-b1dc-28d294ee1476"
fileprivate let doge = "6770a1e5-6086-44d5-b60f-545f9d9e8ffd"
fileprivate let xmr = "05c5ac01-31f9-4a69-aa8a-ab796de1d041"
fileprivate let sol = "64692c23-8971-4cf4-84a7-4dd1271dd887"
fileprivate let xin = "c94ac88f-4671-3976-b60a-09064f1811e8"
fileprivate let usdt = "4d8c508b-91c5-375b-92b0-ee702ed2dac5"

final class TransferURLTests: XCTestCase {
    
    struct Case {
        let raw: String
        let expected: TransferURL?
    }
    
    // MARK: - BTC
    let btcCases = [
        Case(raw: "bitcoin:BC1QA7A84SQ2NNKPXUA5DLY6FG553D5V06NSL608SS?amount=0.00186487",
             expected: .external(amount: "0.00186487",
                                 assetId: btc,
                                 destination: "BC1QA7A84SQ2NNKPXUA5DLY6FG553D5V06NSL608SS",
                                 needsCheckPrecision: false,
                                 tag: nil)),
        Case(raw: "bitcoin:35pkcZ531UWYwVWRGeMG6eXkWbPptFg6AG?amount=0.00173492&fee=5&rbf=false&lightning=LNBC1734920N1P3EC8DGPP5NTUUNWS3GF9XUE4EZ2NCPEJCZHAJRVALFW8ALWFPN29LEE76NV5SDZ2GF5HGUN9VE5KCMPQV9SNYCMZVE3RWTF3XVMK2TF5XGMRJTFCXSCNSTF4VCCXYERYXQ6N2VRPVVCQZX7XQRP9SSP5Q4JSN54FHFQ8TRGHQGDQW2PUV790PXNSFVZG20CW322K0E6L7M8Q9QYYSSQA42ZJEMX44Y6PEW3YHWHXV9JUXTM96DMHKEPMD3LXUQTPH0HGSKX9TVZD2XVG7DETCVN450JXN25FM8G80GRYGU9ZHXC3XURSJ4Z20GPF8SQT7",
             expected: .external(amount: "0.00173492",
                                 assetId: btc,
                                 destination: "35pkcZ531UWYwVWRGeMG6eXkWbPptFg6AG",
                                 needsCheckPrecision: false,
                                 tag: nil)),
        Case(raw: "LIGHTNING:LNBC1197710N1P36QPY7PP5NZT3GTZMZP00E8NAR0C40DQVS5JT7PWCF7Z4MLXKH6F988QT08MSDZ2GF5HGUN9VE5KCMPQXGENSVFKXPNRXTTRV43NWTF5V4SKVTFEVCUXYTTXXAJNZVM9X4JRGETY8YCQZX7XQRP9SSP5EU7UUK9E5VKGQ2KYTW68D2JHTK7ALWSTFKYFMMSL2FGT22ZLMW9Q9QYYSSQAWC3VFFRPEGE79NLXKRMPVVR8Q9NVUMD4LFF3U2QRJ23A0RUUTGKJ7UCQQTE3RV93JYH20GJFPQHGLL7K2RPJMNYFXAP9NXPC4XQ80GPFE00SQ",
             expected: nil),
        Case(raw: "bitcoin:BC1QA7A84SQ2NNKPXUA5DLY6FG553D5V06NSL608SS?amount=0.12e3",
             expected: nil),
    ]
    
    // MARK: - ETH
    let ethCases = [
        Case(raw: "ethereum:0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359?value=2.014e18",
             expected: .external(amount: "2.014",
                                 assetId: eth,
                                 destination: "0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359",
                                 needsCheckPrecision: false,
                                 tag: nil)),
        Case(raw: "ethereum:pay-0xdAC17F958D2ee523a2206206994597C13D831ec7@1/transfer?address=0x00d02d4A148bCcc66C6de20C4EB1CbAB4298cDcc&uint256=2e7&gasPrice=14",
             expected: .external(amount: "2e7", // This amount will be fixed outside TransferURL
                                 assetId: usdt,
                                 destination: "0x00d02d4A148bCcc66C6de20C4EB1CbAB4298cDcc",
                                 needsCheckPrecision: true,
                                 tag: nil)),
        Case(raw: "ethereum:0xD994790d2905b073c438457c9b8933C0148862db@1?value=1.697e16&gasPrice=14&label=Bitrefill%2008cba4ee-b6cd-47c8-9768-c82959c0edce",
             expected: .external(amount: "0.01697",
                                 assetId: eth,
                                 destination: "0xD994790d2905b073c438457c9b8933C0148862db",
                                 needsCheckPrecision: false,
                                 tag: nil)),
        Case(raw: "ethereum:0xA974c709cFb4566686553a20790685A47acEAA33@1/transfer?address=0xB38F2E40e82F0AE5613D55203d84953aE4d5181B&amount=1&uint256=1.24e18",
             expected: .external(amount: "1",
                                 assetId: xin,
                                 destination: "0xB38F2E40e82F0AE5613D55203d84953aE4d5181B",
                                 needsCheckPrecision: false,
                                 tag: nil)),
        Case(raw: "ethereum:pay-0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48@1/transfer?address=0x50bF16E33E892F1c9Aa7C7FfBaF710E971b86Dd1&gasPrice=14",
             expected: nil),
        Case(raw: "ethereum:0xA974c709cFb4566686553a20790685A47acEAA33@1/transfer?a=b&c=d&uint256=1.24e18&e=f&amount=1&g=h&address=0xB38F2E40e82F0AE5613D55203d84953aE4d5181B&i=j&k=m&n=o&p=q",
             expected: .external(amount: "1",
                                 assetId: xin,
                                 destination: "0xB38F2E40e82F0AE5613D55203d84953aE4d5181B",
                                 needsCheckPrecision: false,
                                 tag: nil)),
        Case(raw: "ethereum:0xA974c709cFb4566686553a20790685A47acEAA33@1/transfer?address=0xB38F2E40e82F0AE5613D55203d84953aE4d5181B&amount=1e7&uint256=1.24e18",
             expected: nil),
    ]
    
    // MARK: - LTC
    let ltcCases = [
        Case(raw: "litecoin:MAA5rAYDJcfpGShL2fHHyqdH5Sum4hC9My?amount=0.31837321",
             expected: .external(amount: "0.31837321",
                                 assetId: ltc,
                                 destination: "MAA5rAYDJcfpGShL2fHHyqdH5Sum4hC9My",
                                 needsCheckPrecision: false,
                                 tag: nil)),
        Case(raw: "litecoin:MAA5rAYDJcfpGShL2fHHyqdH5Sum4hC9My?amount=0.31e5",
             expected: nil),
    ]
    
    // MARK: - DOGE
    let dogeCases = [
        Case(raw: "dogecoin:DQDHx7KcDjq1uDR5MC8tHQPiUp1C3eQHcd?amount=258.69",
             expected: .external(amount: "258.69",
                                 assetId: doge,
                                 destination: "DQDHx7KcDjq1uDR5MC8tHQPiUp1C3eQHcd",
                                 needsCheckPrecision: false,
                                 tag: nil)),
        Case(raw: "dogecoin:DQDHx7KcDjq1uDR5MC8tHQPiUp1C3eQHcd?amount=258.6e5",
             expected: nil),
    ]
    
    // MARK: - DASH
    let dashCases = [
        Case(raw: "dash:XimNHukVq5PFRkadrwybyuppbree51mByS?amount=0.47098703&IS=1",
             expected: .external(amount: "0.47098703",
                                 assetId: dash,
                                 destination: "XimNHukVq5PFRkadrwybyuppbree51mByS",
                                 needsCheckPrecision: false,
                                 tag: nil)),
        Case(raw: "dash:XimNHukVq5PFRkadrwybyuppbree51mByS?amount=0.47e5&IS=1",
             expected: nil),
    ]
    
    // MARK: - XMR
    let xmrCases = [
        Case(raw: "monero:83sfoqWFNrsGTAyuC3PxHeS9stn8TQiTkiBcizHwjyHN57NczsRJE8UfrnhTUxT5PLBWLnq5yXrtPKeAjWeoDTkCPHGVe1Y?tx_amount=1.61861962",
             expected: .external(amount: "1.61861962",
                                 assetId: xmr,
                                 destination: "83sfoqWFNrsGTAyuC3PxHeS9stn8TQiTkiBcizHwjyHN57NczsRJE8UfrnhTUxT5PLBWLnq5yXrtPKeAjWeoDTkCPHGVe1Y",
                                 needsCheckPrecision: false,
                                 tag: nil)),
        Case(raw: "monero:83sfoqWFNrsGTAyuC3PxHeS9stn8TQiTkiBcizHwjyHN57NczsRJE8UfrnhTUxT5PLBWLnq5yXrtPKeAjWeoDTkCPHGVe1Y?tx_amount=1.61e6",
             expected: nil),
    ]
    
    // MARK: - SOL
    let solCases = [
        Case(raw: "solana:mvines9iiHiQTysrwkJjGf2gb9Ex9jXJX8ns3qwf2kN?amount=1&label=Michael&message=Thanks%20for%20all%20the%20fish&memo=OrderId12345",
             expected: .external(amount: "1",
                                 assetId: sol,
                                 destination: "mvines9iiHiQTysrwkJjGf2gb9Ex9jXJX8ns3qwf2kN",
                                 needsCheckPrecision: false,
                                 tag: nil)),
        Case(raw: "solana:mvines9iiHiQTysrwkJjGf2gb9Ex9jXJX8ns3qwf2kN?amount=0.01&spl-token=EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
             expected: nil),
        Case(raw: "solana:mvines9iiHiQTysrwkJjGf2gb9Ex9jXJX8ns3qwf2kN?amount=1e7&label=Michael&message=Thanks%20for%20all%20the%20fish&memo=OrderId12345",
             expected: nil),
    ]
    
    func testAll() {
        let allCases = btcCases + ethCases + ltcCases + dogeCases + dashCases + xmrCases + solCases
        for testCase in allCases {
            let output = TransferURL(string: testCase.raw)
            switch (output, testCase.expected) {
            case (nil, nil):
                break
            case let (.mixin(outputQueries), .mixin(expectedQueries)):
                XCTAssertEqual(outputQueries, expectedQueries, testCase.raw)
            case let (.external(outputAmount, outputAssetId, outputDestination, outputNeedsCheckPrecision, outputTag),
                      .external(expectedAmount, expectedAssetId, expectedDestination, expectedNeedsCheckPrecision, expectedTag)):
                XCTAssertEqual(outputAmount, expectedAmount, testCase.raw)
                XCTAssertEqual(outputAssetId, expectedAssetId, testCase.raw)
                XCTAssertEqual(outputDestination, expectedDestination, testCase.raw)
                XCTAssertEqual(outputNeedsCheckPrecision, expectedNeedsCheckPrecision, testCase.raw)
                XCTAssertEqual(outputTag, expectedTag, testCase.raw)
            default:
                XCTFail(testCase.raw)
            }
        }
    }
    
}
