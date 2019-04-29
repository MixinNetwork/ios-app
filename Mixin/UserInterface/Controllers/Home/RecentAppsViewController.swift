import UIKit

class RecentAppsViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionLayout: UICollectionViewFlowLayout!
    
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    private let cellCountPerRow = 4
    private let maxRowCount = 2
    private let queue = OperationQueue()
    
    private var users = [UserItem]()
    private var needsReload = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        queue.maxConcurrentOperationCount = 1
        scrollView.delegate = self
        collectionView.dataSource = self
        collectionView.delegate = self
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didChangeRecentlyUsedAppIds),
                                               name: CommonUserDefault.didChangeRecentlyUsedAppIdsNotification,
                                               object: nil)
        reloadIfNeeded()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let cellsWidth = collectionLayout.itemSize.width * CGFloat(cellCountPerRow)
        let totalSpacing = view.bounds.width - cellsWidth
        let spacing = floor(totalSpacing / CGFloat(cellCountPerRow + 1))
        collectionLayout.minimumInteritemSpacing = spacing
        collectionLayout.sectionInset = UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: spacing)
    }
    
    @objc func didChangeRecentlyUsedAppIds() {
        needsReload = true
    }
    
    func reloadIfNeeded() {
        guard needsReload else {
            return
        }
        needsReload = false
        queue.cancelAllOperations()
        let maxIdCount = maxRowCount * cellCountPerRow
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            let ids = CommonUserDefault.shared.recentlyUsedAppIds.prefix(maxIdCount)
            let users = UserDAO.shared.getUsers(ofAppIds: Array(ids))
            DispatchQueue.main.sync {
                guard let weakSelf = self, !op.isCancelled else {
                    return
                }
                weakSelf.reload(users: users)
            }
        }
        queue.addOperation(op)
    }
    
    private func reload(users: [UserItem]) {
        self.users = users
        contentView.isHidden = users.isEmpty
        if !users.isEmpty {
            let lineCount = users.count > cellCountPerRow ? 2 : 1
            let height = collectionLayout.itemSize.height * CGFloat(lineCount)
            collectionViewHeightConstraint.constant = height
            collectionView.reloadData()
            view.layoutIfNeeded()
        }
    }
    
}

extension RecentAppsViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else {
            return
        }
        if scrollView.panGestureRecognizer.velocity(in: scrollView).y < 0 {
            (UIApplication.rootNavigationController()?.topViewController as? HomeViewController)?.hideSearch()
        }
    }
    
}

extension RecentAppsViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return users.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.recent_app, for: indexPath)!
        cell.render(user: users[indexPath.row])
        return cell
    }
    
}

extension RecentAppsViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let user = users[indexPath.row]
        let vc = ConversationViewController.instance(ownerUser: user)
        (parent as? SearchViewController)?.searchTextField.resignFirstResponder()
        UIApplication.rootNavigationController()?.pushViewController(vc, animated: true)
    }
    
}
