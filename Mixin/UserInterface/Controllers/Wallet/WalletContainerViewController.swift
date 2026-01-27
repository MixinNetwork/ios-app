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
        
        let animation = {
            summary.view.frame = self.view.bounds
        }
        let completion = { (finished: Bool) in
            self.remove(child: wallet)
            self.viewController = summary
        }
        if animated {
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                options: .overdampedCurve,
                animations: animation,
                completion: completion
            )
        } else {
            animation()
            completion(true)
        }
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
        addChild(viewController)
        view.insertSubview(viewController.view, at: 0)
        viewController.view.snp.makeEdgesEqualToSuperview()
        viewController.didMove(toParent: self)
        
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            summary.view.frame.origin.x = -self.view.bounds.width
        } completion: { _ in
            self.remove(child: summary)
            self.viewController = viewController
            if let viewController = viewController as? HomeTabBarControllerChild {
                viewController.viewControllerDidSwitchToFront()
            }
        }
    }
    
    private func load(child: UIViewController) {
        addChild(child)
        view.addSubview(child.view)
        child.view.snp.makeEdgesEqualToSuperview()
        child.didMove(toParent: self)
        self.viewController = child
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
