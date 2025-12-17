import UIKit
import MixinServices

final class ExploreViewController: UIViewController {
    
    @IBOutlet weak var segmentsCollectionView: UICollectionView!
    @IBOutlet weak var contentContainerView: UIView!
    
    private let hiddenSearchTopMargin: CGFloat = -28
    
    private lazy var botsViewController = ExploreBotsViewController()
    private lazy var collectiblesViewController = CollectiblesViewController()
    
    private weak var searchViewController: UIViewController?
    private weak var searchViewCenterYConstraint: NSLayoutConstraint?
    
    private weak var selectedViewController: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        segmentsCollectionView.register(R.nib.exploreSegmentCell)
        if let layout = segmentsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
            layout.minimumInteritemSpacing = 0
        }
        segmentsCollectionView.contentInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        segmentsCollectionView.dataSource = self
        segmentsCollectionView.delegate = self
        let defaultSelection = if AppGroupUserDefaults.User.exploreSegmentIndex < Segment.allCases.count {
            IndexPath(item: AppGroupUserDefaults.User.exploreSegmentIndex, section: 0)
        } else {
            IndexPath(item: 0, section: 0)
        }
        segmentsCollectionView.reloadData()
        segmentsCollectionView.selectItem(at: defaultSelection, animated: false, scrollPosition: .left)
        collectionView(segmentsCollectionView, didSelectItemAt: defaultSelection)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cancelSearchingSilently),
            name: dismissSearchNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hideBadgeIfNeeded(_:)),
            name: BadgeManager.viewedNotification,
            object: nil
        )
    }
    
    @IBAction func search(_ sender: Any) {
        guard
            let indexPath = segmentsCollectionView.indexPathsForSelectedItems?.first,
            let segment = Segment(rawValue: indexPath.item)
        else {
            return
        }
        switch segment {
        case .explore:
            let searchViewController = ExploreAggregatedSearchViewController()
            let navigationController = SearchNavigationViewController(
                navigationBarClass: SearchNavigationBar.self,
                toolbarClass: nil
            )
            navigationController.viewControllers = [searchViewController]
            navigationController.searchNavigationBar.searchBoxView.textField.clearButtonMode = .always
            presentSearch(with: navigationController)
            searchViewController.searchTextField.becomeFirstResponder()
        case .collectibles:
            let searchViewController = SearchCollectibleViewController()
            presentSearch(with: searchViewController)
            searchViewController.searchBoxView.textField.becomeFirstResponder()
        }
    }
    
    @IBAction func scanQRCode(_ sender: Any) {
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
    }
    
    @IBAction func openSettings(_ sender: Any) {
        let settings = SettingsViewController()
        navigationController?.pushViewController(settings, animated: true)
    }
    
    @objc func cancelSearching(_ sender: Any) {
        hideSearch(endEditing: true, animate: true)
    }
    
    @objc private func cancelSearchingSilently(_ notification: Notification) {
        hideSearch(endEditing: false, animate: false)
    }
    
    func hideSearch(endEditing: Bool, animate: Bool) {
        guard let searchViewController, let searchViewCenterYConstraint, searchViewController.parent != nil else {
            return
        }
        if endEditing {
            searchViewController.view.endEditing(true)
        }
        searchViewCenterYConstraint.constant = hiddenSearchTopMargin
        let layout = {
            self.view.layoutIfNeeded()
            searchViewController.view.alpha = 0
        }
        let remove = { (_: Bool) in
            searchViewController.willMove(toParent: nil)
            searchViewController.view.removeFromSuperview()
            searchViewController.removeFromParent()
        }
        if animate {
            UIView.animate(withDuration: 0.3, animations: layout, completion: remove)
        } else {
            layout()
            remove(true)
        }
    }
    
    func perform(action: ExploreAction) {
        switch action {
        case .buy:
            let buy = BuyTokenInputAmountViewController(wallet: .privacy)
            navigationController?.pushViewController(buy, animated: true)
            BadgeManager.shared.setHasViewed(identifier: .buy)
        case .trade:
            reporter.report(event: .tradeStart, tags: ["wallet": "main", "source": "explore"])
            let trade = MixinTradeViewController(
                sendAssetID: nil,
                receiveAssetID: nil,
                referral: nil
            )
            navigationController?.pushViewController(trade, animated: true)
            BadgeManager.shared.setHasViewed(identifier: .trade)
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
            UIApplication.homeContainerViewController?.presentReferralPage()
            BadgeManager.shared.setHasViewed(identifier: .referral)
        case .linkDesktop:
            let desktop = DesktopViewController()
            navigationController?.pushViewController(desktop, animated: true)
        case .customerService:
            if let user = UserDAO.shared.getUser(identityNumber: "7000") {
                let conversation = ConversationViewController.instance(ownerUser: user)
                navigationController?.pushViewController(conversation, animated: true)
            }
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
    
    func presentSearch(with searchViewController: UIViewController) {
        addChild(searchViewController)
        searchViewController.view.alpha = 0
        view.addSubview(searchViewController.view)
        searchViewController.view.snp.makeConstraints { make in
            make.size.centerX.equalToSuperview()
        }
        let searchViewCenterYConstraint = searchViewController.view.centerYAnchor
            .constraint(equalTo: view.centerYAnchor, constant: hiddenSearchTopMargin)
        searchViewCenterYConstraint.isActive = true
        searchViewController.didMove(toParent: self)
        view.layoutIfNeeded()
        searchViewCenterYConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
            searchViewController.view.alpha = 1
        }
        self.searchViewController = searchViewController
        self.searchViewCenterYConstraint = searchViewCenterYConstraint
    }
    
    func openApp(user: User) {
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        DispatchQueue.global().async {
            guard let app = AppDAO.shared.getApp(ofUserId: user.userId) else {
                return
            }
            DispatchQueue.main.async {
                AppGroupUserDefaults.User.insertRecentlyUsedAppId(id: app.appId)
                container.presentWebViewController(context: .init(conversationId: "", app: app))
            }
        }
    }
    
}

extension ExploreViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Segment.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
        let segment = Segment.allCases[indexPath.item]
        switch segment {
        case .explore:
            cell.label.text = R.string.localizable.explore()
        case .collectibles:
            cell.label.text = R.string.localizable.collectibles()
        }
        cell.badgeView.isHidden = true
        return cell
    }
    
}

extension ExploreViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        let alreadySelected = collectionView.indexPathsForSelectedItems?.contains(indexPath) ?? false
        return !alreadySelected
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let segment = Segment(rawValue: indexPath.item)!
        switch segment {
        case .explore:
            reporter.report(event: .moreTabSwitch, tags: ["method": "bots"])
            switchToChild(botsViewController)
        case .collectibles:
            reporter.report(event: .moreTabSwitch, tags: ["method": "collectibles"])
            reloadItemKeepingSelection(at: indexPath)
            switchToChild(collectiblesViewController)
        }
        AppGroupUserDefaults.User.exploreSegmentIndex = indexPath.item
    }
    
}

extension ExploreViewController {
    
    private enum Segment: Int, CaseIterable {
        case explore
        case collectibles
    }
    
    @objc private func hideBadgeIfNeeded(_ notification: Notification) {
        guard let identifier = notification.userInfo?[BadgeManager.identifierUserInfoKey] as? BadgeManager.Identifier else {
            return
        }
        if [.trade, .buy, .membership].contains(identifier) {
            let explore = IndexPath(item: Segment.explore.rawValue, section: 0)
            reloadItemKeepingSelection(at: explore)
        }
    }
    
    private func switchToChild(_ newChild: UIViewController) {
        if let currentChild = selectedViewController {
            if currentChild == newChild {
                return
            } else {
                currentChild.willMove(toParent: nil)
                currentChild.view.removeFromSuperview()
                currentChild.removeFromParent()
            }
        }
        selectedViewController = newChild
        
        addChild(newChild)
        contentContainerView.addSubview(newChild.view)
        newChild.view.snp.makeEdgesEqualToSuperview()
        newChild.didMove(toParent: self)
    }
    
    private func reloadItemKeepingSelection(at indexPath: IndexPath) {
        UIView.performWithoutAnimation {
            let selectedIndexPath = segmentsCollectionView.indexPathsForSelectedItems?.first
            segmentsCollectionView.reloadItems(at: [indexPath])
            if let indexPath = selectedIndexPath {
                segmentsCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: .left)
            }
        }
    }
    
}
