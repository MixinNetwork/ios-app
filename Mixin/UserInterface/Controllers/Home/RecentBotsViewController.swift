import UIKit

class RecentBotsViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionLayout: UICollectionViewFlowLayout!
    
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    private let reuseId = "app"
    private let cellCountPerRow = 4
    private let maxRowCount = 2
    private let queue = OperationQueue()
    
    private var apps = [App]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        queue.maxConcurrentOperationCount = 1
        collectionView.dataSource = self
        collectionView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: CommonUserDefault.didChangeRecentlyUsedAppIdsNotification, object: nil)
        reloadData()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let cellsWidth = collectionLayout.itemSize.width * CGFloat(cellCountPerRow)
        let totalSpacing = view.bounds.width - cellsWidth
        let spacing = floor(totalSpacing / CGFloat(cellCountPerRow + 1))
        collectionLayout.minimumInteritemSpacing = spacing
        collectionLayout.sectionInset = UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: spacing)
    }
    
    @objc func reloadData() {
        queue.cancelAllOperations()
        let maxIdCount = maxRowCount * cellCountPerRow
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            let ids = CommonUserDefault.shared.recentlyUsedAppIds.prefix(maxIdCount)
            let apps = AppDAO.shared.getApps(ids: Array(ids))
            guard let weakSelf = self, !op.isCancelled else {
                return
            }
            DispatchQueue.main.sync {
                weakSelf.reload(apps: apps)
            }
        }
        queue.addOperation(op)
    }
    
    private func reload(apps: [App]) {
        self.apps = apps
        contentView.isHidden = apps.isEmpty
        if !apps.isEmpty {
            let lineCount = apps.count > cellCountPerRow ? 2 : 1
            let height = collectionLayout.itemSize.height * CGFloat(lineCount)
            collectionViewHeightConstraint.constant = height
            collectionView.reloadData()
            view.layoutIfNeeded()
        }
    }
    
}

extension RecentBotsViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return apps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseId, for: indexPath) as! RecentBotCell
        cell.render(app: apps[indexPath.row])
        return cell
    }
    
}

extension RecentBotsViewController: UICollectionViewDelegate {
    
}
