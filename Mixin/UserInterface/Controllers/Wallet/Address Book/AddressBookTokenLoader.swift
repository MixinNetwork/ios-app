import Foundation
import MixinServices

enum AddressBookTokenLoader {
    
    static func load(assetID: String, chain: Chain?, completion: @escaping (MixinTokenItem) -> Void) {
        let hud = Hud()
        hud.show(style: .busy, text: "")
        DispatchQueue.global().async {
            func report(error: Error) {
                DispatchQueue.main.async {
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
            
            var token: MixinTokenItem
            if let localToken = TokenDAO.shared.tokenItem(assetID: assetID) {
                token = localToken
            } else {
                switch SafeAPI.assets(id: assetID) {
                case let .success(remoteToken):
                    TokenDAO.shared.save(token: remoteToken)
                    token = MixinTokenItem(token: remoteToken, balance: "0", isHidden: false, chain: nil)
                case let .failure(error):
                    report(error: error)
                    return
                }
            }
            if token.chain == nil {
                let tokenChain: Chain
                if let localChain = chain ?? ChainDAO.shared.chain(chainId: token.chainID) {
                    tokenChain = localChain
                } else {
                    switch NetworkAPI.chain(id: token.chainID) {
                    case let .success(remoteChain):
                        ChainDAO.shared.save([remoteChain])
                        Web3ChainDAO.shared.save([remoteChain])
                        tokenChain = remoteChain
                    case let .failure(error):
                        report(error: error)
                        return
                    }
                }
                token = MixinTokenItem(token: token, balance: token.balance, isHidden: token.isHidden, chain: tokenChain)
            }
            DispatchQueue.main.async {
                hud.hide()
                completion(token)
            }
        }
    }
    
}
