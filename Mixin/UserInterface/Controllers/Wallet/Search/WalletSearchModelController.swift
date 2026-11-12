import Foundation
import MixinServices

protocol WalletSearchModelController {
    
    associatedtype Item: ValuableToken & OnChainToken & ChangeReportingToken & ComparableToken
    
    var supportedCategories: [WalletSearchCategory] { get }
    
    func search(keyword: String, category: WalletSearchCategory, limit: Int?) -> [WalletSearchItem<Item>]?
    func recentItems() -> [WalletSearchItem<Item>]
    func reportUserSelection(token item: Item)
    
}

extension WalletSearchModelController {
    
    func insertRecentSearch(_ item: RecentWalletSearch) {
        PropertiesDAO.shared.updateValue(
            forKey: .walletRecentSearches,
            type: String.self,
        ) { string in
            var items = string?.data(using: .utf8).flatMap { data in
                try? JSONDecoder.default.decode([RecentWalletSearch].self, from: data)
            } ?? []
            items.removeAll { $0 == item }
            items.insert(item, at: 0)
            guard let data = try? JSONEncoder.default.encode(Array(items.prefix(5))) else {
                return string
            }
            return String(decoding: data, as: UTF8.self)
        }
    }
    
}

final class PrivacyWalletSearchModelController: WalletSearchModelController {
    
    protocol Delegate: AnyObject {
        func privacyWalletSearchModelController(_ controller: PrivacyWalletSearchModelController, didSelectToken token: MixinTokenItem)
    }
    
    let supportedCategories = WalletSearchCategory.allCases
    
    weak var delegate: Delegate?
    
    func search(
        keyword: String,
        category: WalletSearchCategory,
        limit: Int?,
    ) -> [WalletSearchItem<Item>]? {
        switch category {
        case .all:
            return nil
        case .tokens:
            var tokens = TokenDAO.shared.search(
                keyword: keyword,
                includesZeroBalanceItems: true,
                sorting: limit != nil,
                limit: limit,
            )
            if limit == nil {
                tokens.sort(using: TokenComparator<Item>(keyword: keyword))
            }
            return tokens.map { .token($0) }
        case .perps:
            return PerpsPositionDAO.shared.search(
                walletID: Wallet.privacy.tradingWalletID,
                keyword: keyword,
                limit: limit,
            ).compactMap { position in
                guard let market = PerpsMarketDAO.shared.market(marketID: position.marketID) else {
                    return nil
                }
                return .perps(position, market)
            }
        case .earn:
            let products = PropertiesDAO.shared.jsonObject(forKey: .earnProducts, type: [EarnProduct].self) ?? []
            guard !products.isEmpty else {
                return nil
            }
            let matches = products.lazy.compactMap { product -> WalletSearchItem<Item>? in
                guard let token = TokenDAO.shared.tokenItem(assetID: product.assetID),
                      [token.name, token.symbol, product.productionID]
                        .contains(where: { $0.localizedCaseInsensitiveContains(keyword) })
                else {
                    return nil
                }
                return .earn(WalletSearchEarnViewModel(product: product, token: token))
            }
            return Array(matches.prefix(limit ?? Int.max))
        case .collectibles:
            return InscriptionDAO.shared.search(keyword: keyword, limit: limit).map { .collectible($0) }
        }
    }
    
    func recentItems() -> [WalletSearchItem<Item>] {
        let string: String? = PropertiesDAO.shared.value(forKey: .walletRecentSearches)
        let searches = string?.data(using: .utf8).flatMap { data in
            try? JSONDecoder.default.decode([RecentWalletSearch].self, from: data)
        } ?? []
        let earnings = PropertiesDAO.shared.jsonObject(forKey: .earnProducts, type: [EarnProduct].self) ?? []
        return searches.compactMap { recent in
            switch recent {
            case .token(let assetID):
                TokenDAO.shared.tokenItem(assetID: assetID).flatMap { token in
                    token.isDisplayable ? .token(token) : nil
                }
            case .earn(let productionID):
                if let product = earnings.first(where: { $0.productionID == productionID }),
                   let token = TokenDAO.shared.tokenItem(assetID: product.assetID)
                {
                    .earn(WalletSearchEarnViewModel(product: product, token: token))
                } else {
                    nil
                }
            case .collectible(let hash):
                InscriptionDAO.shared.inscriptionOutput(inscriptionHash: hash).flatMap { output in
                        .collectible(output)
                }
            }
        }
    }
    
    func reportUserSelection(token item: MixinTokenItem) {
        delegate?.privacyWalletSearchModelController(self, didSelectToken: item)
    }
    
}

final class CommonWalletSearchModelController: WalletSearchModelController {
    
    protocol Delegate: AnyObject {
        func commonWalletSearchModelController(_ controller: CommonWalletSearchModelController, didSelectToken token: Web3TokenItem)
    }
    
    let wallet: Web3Wallet
    let supportedCategories: [WalletSearchCategory] = [.all, .tokens]
    
    weak var delegate: Delegate?
    
    init(wallet: Web3Wallet) {
        self.wallet = wallet
    }
    
    func search(
        keyword: String,
        category: WalletSearchCategory,
        limit: Int?,
    ) -> [WalletSearchItem<Item>]? {
        switch category {
        case .tokens:
            return Web3TokenDAO.shared.search(
                walletID: wallet.walletID,
                keyword: keyword,
                includesZeroBalanceItems: true,
                limit: nil,
            )
            .sorted(using: TokenComparator<Item>(keyword: keyword))
            .prefix(limit ?? .max)
            .map { .token($0) }
        case .all, .perps, .earn, .collectibles:
            return nil
        }
    }
    
    func recentItems() -> [WalletSearchItem<Item>] {
        let string: String? = PropertiesDAO.shared.value(forKey: .walletRecentSearches)
        let searches = string?.data(using: .utf8).flatMap { data in
            try? JSONDecoder.default.decode([RecentWalletSearch].self, from: data)
        } ?? []
        return searches.compactMap { recent in
            switch recent {
            case .token(let assetID):
                Web3TokenDAO.shared.token(walletID: wallet.walletID, assetID: assetID).flatMap { token in
                        .token(token)
                }
            case .earn, .collectible:
                nil
            }
        }
    }
    
    func reportUserSelection(token item: Web3TokenItem) {
        delegate?.commonWalletSearchModelController(self, didSelectToken: item)
    }
    
}
