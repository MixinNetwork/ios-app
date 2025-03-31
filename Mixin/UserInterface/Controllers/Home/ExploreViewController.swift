import UIKit
import MixinServices

final class ExploreViewController: UIViewController {
    
    @IBOutlet weak var segmentsCollectionView: UICollectionView!
    @IBOutlet weak var contentContainerView: UIView!
    
    private let hiddenSearchTopMargin: CGFloat = -28
    
    private var showBadgeOnMarket = false
    
    private lazy var exploreBotsViewController = ExploreBotsViewController()
    private lazy var exploreMarketViewController = ExploreMarketViewController()
    
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
        segmentsCollectionView.reloadData()
        let indexPath = if AppGroupUserDefaults.User.exploreSegmentIndex < Segment.allCases.count {
            IndexPath(item: AppGroupUserDefaults.User.exploreSegmentIndex, section: 0)
        } else {
            IndexPath(item: 0, section: 0)
        }
        segmentsCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: .left)
        collectionView(segmentsCollectionView, didSelectItemAt: indexPath)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelSearchingSilently), name: dismissSearchNotification, object: nil)
        DispatchQueue.global().async {
            let hasReviewed: Bool = PropertiesDAO.shared.value(forKey: .hasMarketReviewed) ?? false
            DispatchQueue.main.async {
                guard !hasReviewed else {
                    return
                }
                let indexPath = IndexPath(item: Segment.markets.rawValue, section: 0)
                if self.segmentsCollectionView.indexPathsForSelectedItems?.first == indexPath {
                    self.markMarketReviewed()
                } else {
                    self.showBadgeOnMarket = true
                    self.reloadItemKeepingSelection(at: indexPath)
                }
            }
        }
    }
    
    @IBAction func searchApps(_ sender: Any) {
        let searchViewController = ExploreAggregatedSearchViewController()
        let navigationController = SearchNavigationViewController(
            navigationBarClass: SearchNavigationBar.self,
            toolbarClass: nil
        )
        navigationController.viewControllers = [searchViewController]
        navigationController.searchNavigationBar.searchBoxView.textField.clearButtonMode = .always
        presentSearch(with: navigationController)
        searchViewController.searchTextField.becomeFirstResponder()
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
        case .camera:
            UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: false)
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
    
    func switchToSegment(_ segment: Segment) {
        let indexPath = IndexPath(item: segment.rawValue, section: 0)
        segmentsCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: .left)
        collectionView(segmentsCollectionView, didSelectItemAt: indexPath)
    }
    
}

extension ExploreViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Segment.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
        cell.label.text = Segment.allCases[indexPath.item].name
        switch Segment(rawValue: indexPath.item) {
        case .markets:
            cell.badgeView.isHidden = !showBadgeOnMarket
        default:
            cell.badgeView.isHidden = true
        }
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
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
        case .bots:
            switchToChild(exploreBotsViewController)
        case .markets:
            if showBadgeOnMarket {
                showBadgeOnMarket = false
                reloadItemKeepingSelection(at: indexPath)
                markMarketReviewed()
            }
            switchToChild(exploreMarketViewController)
        }
        AppGroupUserDefaults.User.exploreSegmentIndex = indexPath.item
    }
    
}

extension ExploreViewController: HomeTabBarControllerChild {
    
    func viewControllerDidSwitchToFront() {
        if let controller = selectedViewController, controller is ExploreMarketViewController {
            if showBadgeOnMarket {
                showBadgeOnMarket = false
                let indexPath = IndexPath(item: Segment.markets.rawValue, section: 0)
                reloadItemKeepingSelection(at: indexPath)
                markMarketReviewed()
            }
        }
    }
    
}

extension ExploreViewController {
    
    enum Segment: Int, CaseIterable {
        
        case bots
        case markets
        
        var name: String {
            switch self {
            case .bots:
                R.string.localizable.bots_title()
            case .markets:
                R.string.localizable.markets()
            }
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
    
    private func markMarketReviewed() {
        DispatchQueue.global().async {
            PropertiesDAO.shared.set(true, forKey: .hasMarketReviewed)
        }
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
