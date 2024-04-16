import UIKit
import MixinServices

final class ExploreViewController: UIViewController {
    
    @IBOutlet weak var segmentsCollectionView: UICollectionView!
    @IBOutlet weak var contentContainerView: UIView!
    
    private let hiddenSearchTopMargin: CGFloat = -28
    
    private lazy var exploreBotsViewController = ExploreBotsViewController()
    private lazy var ethereumViewController = ExploreWeb3ViewController(chain: .ethereum)
    
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
    }
    
    @IBAction func searchApps(_ sender: Any) {
        let searchViewController = ExploreSearchViewController(users: exploreBotsViewController.allUsers)
        presentSearch(with: searchViewController)
    }
    
    @IBAction func scanQRCode(_ sender: Any) {
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
    }
    
    @IBAction func openSettings(_ sender: Any) {
        let settings = SettingsViewController.instance()
        navigationController?.pushViewController(settings, animated: true)
    }
    
    func perform(action: ExploreAction) {
        switch action {
        case .camera:
            UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: false)
        case .linkDesktop:
            let desktop = DesktopViewController.instance()
            navigationController?.pushViewController(desktop, animated: true)
        case .customerService:
            if let user = UserDAO.shared.getUser(identityNumber: "7000") {
                let conversation = ConversationViewController.instance(ownerUser: user)
                navigationController?.pushViewController(conversation, animated: true)
            }
        case .editFavoriteApps:
            let editApps = EditFavoriteAppsViewController.instance()
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
        guard let home = UIApplication.homeContainerViewController?.homeTabBarController else {
            return
        }
        DispatchQueue.global().async {
            guard let app = AppDAO.shared.getApp(ofUserId: user.userId) else {
                return
            }
            DispatchQueue.main.async {
                AppGroupUserDefaults.User.insertRecentlyUsedAppId(id: app.appId)
                MixinWebViewController.presentInstance(with: .init(conversationId: "", app: app), asChildOf: home)
            }
            reporter.report(event: .openApp, userInfo: ["source": "Explore", "identityNumber": app.appNumber])
        }
    }
    
    func cancelSearching() {
        guard let searchViewController, let searchViewCenterYConstraint else {
            return
        }
        searchViewCenterYConstraint.constant = hiddenSearchTopMargin
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
            searchViewController.view.alpha = 0
        } completion: { _ in
            searchViewController.willMove(toParent: nil)
            searchViewController.view.removeFromSuperview()
            searchViewController.removeFromParent()
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
        case .ethereum:
            switchToChild(ethereumViewController)
        }
        AppGroupUserDefaults.User.exploreSegmentIndex = indexPath.item
    }
    
}

extension ExploreViewController {
    
    enum Segment: Int, CaseIterable {
        
        case bots
        case ethereum
        
        var name: String {
            switch self {
            case .bots:
                R.string.localizable.bots_title()
            case .ethereum:
                "Ethereum"
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
    
}
