import Foundation
import MixinServices

protocol WalletSearchModelController {
    
    associatedtype Item: ValuableToken & OnChainToken & ChangeReportingToken & ComparableToken
    
    func history() -> [Item]
    func isTrendingItemAvailable(item: AssetItem) -> Bool
    func localItems(keyword: String) -> [Item]
    func remoteItems(from tokens: [MixinToken]) -> [Item]
    func reportUserSelection(trending item: AssetItem)
    func reportUserSelection(token item: Item)
    
}

final class WalletSearchMixinTokenController: WalletSearchModelController {
    
    protocol Delegate: AnyObject {
        func walletSearchMixinTokenController(_ controller: WalletSearchMixinTokenController, didSelectToken token: MixinTokenItem)
        func walletSearchMixinTokenController(_ controller: WalletSearchMixinTokenController, didSelectTrendingItem item: AssetItem)
    }
    
    weak var delegate: Delegate?
    
    func history() -> [MixinTokenItem] {
        AppGroupUserDefaults.User.assetSearchHistory
            .compactMap(TokenDAO.shared.tokenItem(assetID:))
    }
    
    func isTrendingItemAvailable(item: AssetItem) -> Bool {
        true
    }
    
    func localItems(keyword: String) -> [MixinTokenItem] {
        TokenDAO.shared.search(
            keyword: keyword,
            includesZeroBalanceItems: true,
            sorting: false,
            limit: nil
        )
    }
    
    func remoteItems(from tokens: [MixinToken]) -> [MixinTokenItem] {
        let chainIDs = Set(tokens.map(\.chainID))
        var chains = ChainDAO.shared.chains(chainIDs: chainIDs)
        return tokens.compactMap { (token) -> MixinTokenItem? in
            let chain: Chain
            if let localChain = chains[token.chainID] {
                chain = localChain
            } else if case let .success(remoteChain) = NetworkAPI.chain(id: token.chainID) {
                DispatchQueue.global().async {
                    ChainDAO.shared.save([remoteChain])
                    Web3ChainDAO.shared.save([remoteChain])
                }
                chains[remoteChain.chainId] = remoteChain
                chain = remoteChain
            } else {
                return nil
            }
            let item = MixinTokenItem(token: token, balance: "0", isHidden: false, chain: chain)
            return item
        }
    }
    
    func reportUserSelection(trending item: AssetItem) {
        delegate?.walletSearchMixinTokenController(self, didSelectTrendingItem: item)
    }
    
    func reportUserSelection(token item: MixinTokenItem) {
        delegate?.walletSearchMixinTokenController(self, didSelectToken: item)
    }
    
}

final class WalletSearchWeb3TokenController: WalletSearchModelController {
    
    protocol Delegate: AnyObject {
        func walletSearchWeb3TokenController(_ controller: WalletSearchWeb3TokenController, didSelectToken token: Web3TokenItem)
        func walletSearchWeb3TokenController(_ controller: WalletSearchWeb3TokenController, didSelectTrendingItem item: AssetItem)
    }
    
    private let walletID: String
    private let supportedChainIDs: Set<String>
    
    weak var delegate: Delegate?
    
    init(walletID: String, supportedChainIDs: Set<String>) {
        self.walletID = walletID
        self.supportedChainIDs = supportedChainIDs
    }
    
    func history() -> [Web3TokenItem] {
        AppGroupUserDefaults.User.assetSearchHistory.compactMap { assetID in
            Web3TokenDAO.shared.token(walletID: walletID, assetID: assetID)
        }
    }
    
    func isTrendingItemAvailable(item: AssetItem) -> Bool {
        supportedChainIDs.contains(item.chainId)
    }
    
    func localItems(keyword: String) -> [Web3TokenItem] {
        let items = Web3TokenDAO.shared.search(
            walletID: walletID,
            keyword: keyword,
            limit: nil
        )
        return items
    }
    
    func remoteItems(from tokens: [MixinToken]) -> [Web3TokenItem] {
        let chainIDs = Set(tokens.map(\.chainID))
        let chains = Web3ChainDAO.shared.chains(chainIDs: chainIDs)
        return tokens.compactMap { token in
            guard let chain = chains[token.chainID] else {
                return nil
            }
            let amount = Web3TokenDAO.shared.amount(walletID: walletID, assetID: token.assetID)
            let isHidden = Web3TokenExtraDAO.shared.isHidden(walletID: walletID, assetID: token.assetID)
            let web3Token = Web3Token(
                walletID: walletID,
                assetID: token.assetID,
                chainID: token.chainID,
                assetKey: token.assetKey,
                kernelAssetID: token.kernelAssetID,
                symbol: token.symbol,
                name: token.name,
                precision: token.precision,
                iconURL: token.iconURL,
                amount: amount ?? "0",
                usdPrice: token.usdPrice,
                usdChange: token.usdChange,
                level: Web3Reputation.Level.verified.rawValue,
            )
            return Web3TokenItem(token: web3Token, hidden: isHidden, chain: chain)
        }
    }
    
    func reportUserSelection(trending item: AssetItem) {
        delegate?.walletSearchWeb3TokenController(self, didSelectTrendingItem: item)
    }
    
    func reportUserSelection(token item: Web3TokenItem) {
        delegate?.walletSearchWeb3TokenController(self, didSelectToken: item)
    }
    
}
