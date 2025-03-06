import UIKit
import MixinServices

final class WalletContainerViewController: UIViewController {
    
    private weak var viewController: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let wallet = PrivacyWalletViewController()
        addChild(wallet)
        view.addSubview(wallet.view)
        wallet.view.snp.makeEdgesEqualToSuperview()
        wallet.didMove(toParent: self)
        self.viewController = wallet
        
        let job = ReloadMarketAlertsJob()
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    func switchToWalletSummary() {
        guard let wallet = viewController as? WalletViewController else {
            return
        }
        self.viewController = nil
        let summary = WalletSummaryViewController()
        
        addChild(summary)
        summary.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        summary.view.frame = CGRect(
            x: -view.bounds.width,
            y: 0,
            width: view.bounds.width,
            height: view.bounds.height
        )
        view.addSubview(summary.view)
        summary.didMove(toParent: self)
        
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            summary.view.frame = self.view.bounds
        } completion: { _ in
            self.remove(child: wallet)
            self.viewController = summary
        }
    }
    
    func switchToWallet(_ wallet: Wallet) {
        guard let summary = viewController as? WalletSummaryViewController else {
            return
        }
        self.viewController = nil
        let wallet = switch wallet {
        case .privacy:
            PrivacyWalletViewController()
        case .classic(let id):
            ClassicWalletViewController(walletID: id)
        }
        
        addChild(wallet)
        view.insertSubview(wallet.view, at: 0)
        wallet.view.snp.makeEdgesEqualToSuperview()
        wallet.didMove(toParent: self)
        
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            summary.view.frame.origin.x = -self.view.bounds.width
        } completion: { _ in
            self.remove(child: summary)
            self.viewController = wallet
        }
    }
    
    private func remove(child: UIViewController) {
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }
    
}

extension WalletContainerViewController: HomeTabBarControllerChild {
    
    func viewControllerDidSwitchToFront() {
        if let viewController = viewController as? HomeTabBarControllerChild {
            viewController.viewControllerDidSwitchToFront()
        }
    }
    
}
