import UIKit
import MixinServices

final class WalletSearchMixinTokenHandler {
    
    private weak var navigationController: UINavigationController?
    
    init(navigationController: UINavigationController?) {
        self.navigationController = navigationController
    }
    
}

extension WalletSearchMixinTokenHandler: WalletSearchMixinTokenController.Delegate {
    
    func walletSearchMixinTokenController(_ controller: WalletSearchMixinTokenController, didSelectToken token: MixinTokenItem) {
        let controller = MixinTokenViewController(token: token)
        navigationController?.pushViewController(controller, animated: true)
        DispatchQueue.global().async {
            TokenDAO.shared.save(assets: [token])
        }
        reporter.report(event: .assetDetail, tags: ["wallet": "main", "source": "wallet_search"])
    }
    
    func walletSearchMixinTokenController(_ controller: WalletSearchMixinTokenController, didSelectTrendingItem item: AssetItem) {
        if let token = TokenDAO.shared.tokenItem(assetID: item.assetId) {
            walletSearchMixinTokenController(controller, didSelectToken: token)
        } else {
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            DispatchQueue.global().async { [weak self] in
                func report(error: Error) {
                    DispatchQueue.main.sync {
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                }
                
                let chainID = item.chainId
                let chain: Chain
                if let localChain = ChainDAO.shared.chain(chainId: chainID) {
                    chain = localChain
                } else {
                    switch NetworkAPI.chain(id: chainID) {
                    case .success(let remoteChain):
                        chain = remoteChain
                        ChainDAO.shared.save([chain])
                        Web3ChainDAO.shared.save([chain])
                    case .failure(let error):
                        report(error: error)
                        return
                    }
                }
                switch SafeAPI.assets(id: item.assetId) {
                case .success(let token):
                    let item = MixinTokenItem(token: token, balance: "0", isHidden: false, chain: chain)
                    DispatchQueue.main.sync {
                        hud.hide()
                        self?.walletSearchMixinTokenController(controller, didSelectToken: item)
                    }
                case .failure(let error):
                    report(error: error)
                }
            }
        }
    }
    
}
