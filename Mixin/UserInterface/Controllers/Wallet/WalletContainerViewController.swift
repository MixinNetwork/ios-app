import UIKit
import MixinServices

final class WalletContainerViewController: UIViewController {
    
    private weak var viewController: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch AppGroupUserDefaults.Wallet.lastSelectedWallet {
        case .common(let id):
            if let wallet = Web3WalletDAO.shared.wallet(id: id) {
                load(child: CommonWalletViewController(wallet: wallet))
            } else {
                fallthrough
            }
        case .privacy, .safe:
            load(child: PrivacyWalletViewController())
        }
        
        let job = ReloadMarketAlertsJob()
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    func switchToWalletSummary(animated: Bool) {
        guard let wallet = viewController as? WalletViewController else {
            return
        }
        self.viewController = nil
        let summary = WalletSummaryViewController()
        
        wallet.willMove(toParent: nil)
        addChild(summary)
        summary.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        summary.view.frame = CGRect(
            x: -view.bounds.width,
            y: 0,
            width: view.bounds.width,
            height: view.bounds.height
        )
        transition(
            from: wallet,
            to: summary,
            duration: animated ? 0.5 : 0,
            options: .overdampedCurve,
            animations: {
                summary.view.frame = self.view.bounds
            },
            completion: { _ in
                wallet.removeFromParent()
                summary.didMove(toParent: self)
                self.viewController = summary
            },
        )
    }
    
    func switchToWallet(_ wallet: Wallet) {
        guard let summary = viewController as? WalletSummaryViewController else {
            return
        }
        AppGroupUserDefaults.Wallet.lastSelectedWallet = wallet.identifier
        
        self.viewController = nil
        let viewController: WalletViewController
        switch wallet {
        case .privacy, .safe:
            viewController = PrivacyWalletViewController()
        case .common(let wallet):
            viewController = CommonWalletViewController(wallet: wallet)
        }
        summary.willMove(toParent: nil)
        addChild(viewController)
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.view.frame = view.bounds
        transition(
            from: summary,
            to: viewController,
            duration: 0.5,
            options: .overdampedCurve,
            animations: {
                self.view.bringSubviewToFront(summary.view)
                summary.view.frame.origin.x = -self.view.bounds.width
            },
            completion: { _ in
                summary.removeFromParent()
                viewController.didMove(toParent: self)
                self.viewController = viewController
            },
        )
    }
    
    private func load(child: UIViewController) {
        addChild(child)
        view.addSubview(child.view)
        child.view.snp.makeEdgesEqualToSuperview()
        child.didMove(toParent: self)
        self.viewController = child
    }
    
}
