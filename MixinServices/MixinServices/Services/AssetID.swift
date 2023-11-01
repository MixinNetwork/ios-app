import Foundation

public enum AssetID {
    
    public static let xin = "c94ac88f-4671-3976-b60a-09064f1811e8"
    public static let btc = "c6d0c728-2624-429b-8e0d-d9d19b6592fa"
    public static let eth = "43d61dcd-e413-450d-80b8-101d5e903357"
    public static let eos = "6cfe566e-4aad-470b-8c9a-2fd35b49c68d"
    public static let ltc = "76c802a2-7c88-447f-a93e-c29c9e5dd9c8"
    public static let dash = "6472e7e3-75fd-48b6-b1dc-28d294ee1476"
    public static let doge = "6770a1e5-6086-44d5-b60f-545f9d9e8ffd"
    public static let xrp = "23dfb5a5-5d7b-48b6-905f-3970e3176e27"
    public static let avax = "cbc77539-0a20-4666-8c8a-4ded62b36f0a"
    public static let xmr = "05c5ac01-31f9-4a69-aa8a-ab796de1d041"
    public static let sol = "64692c23-8971-4cf4-84a7-4dd1271dd887"
    public static let trx = "25dabac5-056a-48ff-b9f9-f67395dc407c"
    public static let ethereumUSDT = "4d8c508b-91c5-375b-92b0-ee702ed2dac5"
    public static let usdc = "80b65786-7c75-3523-bc03-fb25378eae41"
    public static let tronUSDT = "b91e18ff-a9ae-3dc7-8679-e935d9a4b34b"
    public static let eosUSDT = "5dac5e28-ad13-31ea-869f-41770dfcee09"
    public static let polygonUSDT = "218bc6f4-7927-3f8e-8568-3a3725b74361"
    public static let bep20USDT = "94213408-4ee7-3150-a9c4-9c5cce421c78"
    
    public static let mgd = "b207bce9-c248-4b8e-b6e3-e357146f3f4c"
    public static let classicBTM = "443e1ef5-bc9b-47d3-be77-07f328876c50"
    public static let omniUSDT = "815b0b1a-2764-3736-8faa-42d694fa620a"
    
    public static let depositNotSupported: Set<String> = [
        AssetID.mgd,
        AssetID.classicBTM,
        AssetID.omniUSDT,
    ]
    
}
