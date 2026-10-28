import UIKit
import MixinServices

final class ExploreMoreViewController: UIViewController, AssetChangeAccountRecoveryChecking {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleLabel = UILabel()
        titleLabel.text = R.string.localizable.more()
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = R.color.text()
        let titleItem = UIBarButtonItem(customView: titleLabel)
        if #available(iOS 26.0, *) {
            titleItem.hidesSharedBackground = true
        }
        navigationItem.leftBarButtonItem = titleItem
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem.tintedIcon(
                image: R.image.ic_sticker_setting(),
                target: self,
                action: #selector(openSettings(_:)),
            ),
            UIBarButtonItem.tintedIcon(
                image: R.image.ic_app_category_scan(),
                target: self,
                action: #selector(scanQRCode(_:)),
            ),
            UIBarButtonItem.tintedIcon(
                image: R.image.ic_title_search(),
                target: self,
                action: #selector(search(_:)),
            ),
        ]
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cancelSearchingSilently),
            name: dismissSearchNotification,
            object: nil
        )
    }
    
    @IBAction func search(_ sender: Any) {
        let searchViewController = ExploreAggregatedSearchViewController()
        navigationController?.pushViewController(searchViewController, animated: true)
    }
    
    @IBAction func scanQRCode(_ sender: Any) {
        UIApplication.shared.homeNavigationController?.pushQRCodeScannerViewController()
    }
    
    @IBAction func openSettings(_ sender: Any) {
        let settings = SettingsViewController()
        navigationController?.pushViewController(settings, animated: true)
    }
    
    @objc func cancelSearching(_ sender: Any) {
        navigationController?.popToViewController(self, animated: true)
    }
    
    @objc private func cancelSearchingSilently(_ notification: Notification) {
        guard let navigationController else {
            return
        }
        let viewControllers = navigationController.viewControllers.filter {
            !($0 is ExploreSearchViewController)
        }
        guard viewControllers.count != navigationController.viewControllers.count else {
            return
        }
        navigationController.setViewControllers(viewControllers, animated: false)
    }
    
    func perform(action: ExploreAction) {
        switch action {
        case .buy:
            let buy = BuyTokenInputAmountViewController(wallet: .privacy)
            navigationController?.pushViewController(buy, animated: true)
            BadgeManager.shared.setHasViewed(identifier: .buy)
            reporter.report(event: .buyStart, tags: ["wallet": "main", "source": "explore"])
        case .trade:
            BadgeManager.shared.setHasViewed(identifier: .trade)
            UserOperationAnalytics.tradeSource = .moreExplore
            let trade = TradeViewController(
                wallet: .privacy,
                trading: nil,
                sendAssetID: nil,
                receiveAssetID: nil,
                referral: nil
            )
            guard let trade else {
                return
            }
            withAccountRecoveryChecked { [weak self] in
                self?.navigationController?.pushViewController(trade, animated: true)
            }
        case .membership:
            if let membership = LoginManager.shared.account?.membership, let plan = membership.plan {
                let membership = MembershipViewController(plan: plan, expiredAt: membership.expiredAt)
                navigationController?.pushViewController(membership, animated: true)
            } else {
                let buy = MembershipPlansViewController(selectedPlan: nil)
                present(buy, animated: true)
            }
            BadgeManager.shared.setHasViewed(identifier: .membership)
        case .referral:
            UIApplication.shared.homeNavigationController?.presentReferralPage()
            BadgeManager.shared.setHasViewed(identifier: .referral)
        case .linkDesktop:
            let desktop = DesktopViewController()
            navigationController?.pushViewController(desktop, animated: true)
        case .customerService:
            let customerService = CustomerServiceViewController(reportingTags: nil)
            present(customerService, animated: true)
        case .editFavoriteApps:
            let editApps = EditFavoriteAppsViewController()
            navigationController?.pushViewController(editApps, animated: true)
        }
    }
    
    func presentProfile(user: User) {
        let item = UserItem.createUser(from: user)
        let profile = UserProfileViewController(user: item)
        present(profile, animated: true, completion: nil)
    }
    
    func openApp(user: User) {
        guard let app = AppDAO.shared.getApp(ofUserId: user.userId) else {
            return
        }
        AppGroupUserDefaults.User.insertRecentlyUsedAppId(id: app.appId)
        let web = MixinWebViewController(context: .init(conversationID: "", app: app, isAppVerified: user.isVerified))
        navigationController?.pushViewController(web, animated: true)
    }
    
}
