import Foundation

public enum AssetID {
    
    public static let xin = "c94ac88f-4671-3976-b60a-09064f1811e8"
    public static let eth = "43d61dcd-e413-450d-80b8-101d5e903357"
    public static let eos = "6cfe566e-4aad-470b-8c9a-2fd35b49c68d"
    public static let ltc = "76c802a2-7c88-447f-a93e-c29c9e5dd9c8"
    public static let dash = "6472e7e3-75fd-48b6-b1dc-28d294ee1476"
    public static let doge = "6770a1e5-6086-44d5-b60f-545f9d9e8ffd"
    public static let xrp = "23dfb5a5-5d7b-48b6-905f-3970e3176e27"
    public static let xmr = "05c5ac01-31f9-4a69-aa8a-ab796de1d041"
    public static let sol = "64692c23-8971-4cf4-84a7-4dd1271dd887"
    public static let trx = "25dabac5-056a-48ff-b9f9-f67395dc407c"
    public static let matic = "b7938396-3f94-4e0a-9179-d3440718156f"
    public static let bnb = "1949e683-6a08-49e2-b087-d6b72398588f"
    public static let baseETH = "3fb612c5-6844-3979-ae4a-5a84e79da870"
    public static let arbitrumOneETH = "8c590110-1abc-3697-84f2-05214e6516aa"
    public static let opMainnetETH = "60360611-370c-3b69-9826-b13db93f6aba"
    public static let ton = "ef660437-d915-4e27-ad3f-632bfb6ba0ee"
    
    public static let btc = "c6d0c728-2624-429b-8e0d-d9d19b6592fa"
    public static let lightningBTC = "59c09123-95cc-3ffd-a659-0f9169074cee"
    
    public static let erc20USDT = "4d8c508b-91c5-375b-92b0-ee702ed2dac5"
    public static let tronUSDT = "b91e18ff-a9ae-3dc7-8679-e935d9a4b34b"
    public static let eosUSDT = "5dac5e28-ad13-31ea-869f-41770dfcee09"
    public static let polygonUSDT = "218bc6f4-7927-3f8e-8568-3a3725b74361"
    public static let bep20USDT = "94213408-4ee7-3150-a9c4-9c5cce421c78"
    public static let solanaUSDT = "cb54aed4-1893-3977-b739-ec7b2e04f0c5"
    public static let tonUSDT = "7369eea0-0c69-3906-b419-e960e3595a4f"
    
    public static let erc20USDC = "9b180ab6-6abe-3dc0-a13f-04169eb34bfa"
    public static let solanaUSDC = "de6fa523-c596-398e-b12f-6d6980544b59"
    public static let baseUSDC = "2f845564-3898-3d17-8c24-3275e96235b5"
    public static let polygonUSDC = "5fec1691-561d-339f-8819-63d54bf50b52"
    public static let bep20USDC = "3d3d69f1-6742-34cf-95fe-3f8964e6d307"
    
    public static let avalancheXAVAX = "cbc77539-0a20-4666-8c8a-4ded62b36f0a"
    public static let avalancheCAVAX = "1f67ac58-87ba-3571-9781-e9413c046f34"
    
    public static let stablecoins: Set<String> = [
        AssetID.erc20USDT, AssetID.tronUSDT, AssetID.polygonUSDT,
        AssetID.bep20USDT, AssetID.solanaUSDT, AssetID.eosUSDT,
        AssetID.erc20USDC, AssetID.solanaUSDC, AssetID.baseUSDC,
        AssetID.polygonUSDC, AssetID.bep20USDC,
    ]
    
}

extension AssetID {
    
    public static let mgd = "b207bce9-c248-4b8e-b6e3-e357146f3f4c"
    public static let classicBTM = "443e1ef5-bc9b-47d3-be77-07f328876c50"
    public static let omniUSDT = "815b0b1a-2764-3736-8faa-42d694fa620a"
    
}
