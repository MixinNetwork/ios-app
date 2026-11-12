import Foundation
import MixinServices

enum WalletSearchItem<Token> {
    
    struct ID: Hashable {
        let category: WalletSearchCategory
        let value: String
    }
    
    case token(Token)
    case perps(PerpetualPositionItem, PerpetualMarket)
    case earn(WalletSearchEarnViewModel)
    case collectible(InscriptionOutput)
    
}

extension WalletSearchItem: Identifiable where Token: ValuableToken & OnChainToken {
    
    var id: ID {
        switch self {
        case .token(let token):
            ID(category: .tokens, value: token.assetID)
        case .perps(let position, _):
            ID(category: .perps, value: position.positionID)
        case .earn(let viewModel):
            ID(category: .earn, value: viewModel.productionID)
        case .collectible(let output):
            ID(category: .collectibles, value: output.output.id)
        }
    }
    
    func recentSearch() -> RecentWalletSearch? {
        switch self {
        case .token(let token):
            .token(assetID: token.assetID)
        case .perps:
            nil
        case .earn(let viewModel):
            .earn(productionID: viewModel.productionID)
        case .collectible(let output):
            .collectible(inscriptionHash: output.inscriptionHash)
        }
    }
    
}
