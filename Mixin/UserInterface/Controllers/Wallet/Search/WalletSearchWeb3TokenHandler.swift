import UIKit
import MixinServices

final class WalletSearchWeb3TokenHandler {
    
    private let wallet: Web3Wallet
    private let availability: Web3Wallet.Availability
    
    private weak var navigationController: UINavigationController?
    
    init(
        wallet: Web3Wallet,
        availability: Web3Wallet.Availability,
        navigationController: UINavigationController?,
    ) {
        self.wallet = wallet
        self.availability = availability
        self.navigationController = navigationController
    }
    
}

extension WalletSearchWeb3TokenHandler: WalletSearchWeb3TokenController.Delegate {
    
    func walletSearchWeb3TokenController(_ controller: WalletSearchWeb3TokenController, didSelectToken token: Web3TokenItem) {
        let controller = Web3TokenViewController(
            wallet: wallet,
            token: token,
            availability: availability
        )
        navigationController?.pushViewController(controller, animated: true)
    }
    
    func walletSearchWeb3TokenController(_ controller: WalletSearchWeb3TokenController, didSelectTrendingItem item: AssetItem) {
        let walletID = wallet.walletID
        if let item = Web3TokenDAO.shared.token(walletID: walletID, assetID: item.assetId) {
            walletSearchWeb3TokenController(controller, didSelectToken: item)
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
                case .failure(let error):
                    report(error: error)
                case .success(let token):
                    let item = Web3TokenItem(
                        token: Web3Token(
                            walletID: walletID,
                            assetID: token.assetID,
                            chainID: token.chainID,
                            assetKey: token.assetKey,
                            kernelAssetID: token.kernelAssetID,
                            symbol: token.symbol,
                            name: token.name,
                            precision: token.precision,
                            iconURL: token.iconURL,
                            amount: "0",
                            usdPrice: token.usdPrice,
                            usdChange: token.usdChange,
                            level: Web3Reputation.Level.verified.rawValue
                        ),
                        hidden: false,
                        chain: chain
                    )
                    DispatchQueue.main.sync {
                        hud.hide()
                        self?.walletSearchWeb3TokenController(controller, didSelectToken: item)
                    }
                }
            }
        }
    }
    
}
