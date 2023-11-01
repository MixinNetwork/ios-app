import UIKit
import MixinServices

class SnapshotDataSource {
    
    static let numberOfItemsPerPage = 50
    
    let category: Category
    
    var onReload: (() -> ())?
    
    private(set) var titles = [String]()
    private(set) var snapshots = [[SafeSnapshotItem]]()
    
    private let queue = OperationQueue()
    
    private var rawItems = [SafeSnapshotItem]()
    private var indexMap = [IndexPath: Int]()
    private var numberOfFilteredItems = 0
    private var isLoading = false
    private var didLoadEarliestLocalSnapshot = false
    private var didLoadEarliestRemoteSnapshot = false
    private var sort = Snapshot.Sort.createdAt
    private var remoteLoadingJobIds = Set<String>()
    
    init(category: Category) {
        self.category = category
        queue.maxConcurrentOperationCount = 1
        if case .address = category {
            didLoadEarliestRemoteSnapshot = true
            didLoadEarliestLocalSnapshot = true
        } else {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(snapshotsDidChange(_:)),
                                                   name: SafeSnapshotDAO.snapshotDidChangeNotification,
                                                   object: nil)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func reloadFromLocal() {
        if case .address = category {
            return
        }
        queue.cancelAllOperations()
        isLoading = true
        let category = self.category
        let sort = self.sort
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self, limit=SnapshotDataSource.numberOfItemsPerPage] in
            let items: [SafeSnapshotItem]
            switch category {
            case .address:
                items = []
            case .user(let id):
                items = SafeSnapshotDAO.shared.snapshots(opponentID: id, sort: sort, limit: limit)
            case .asset(let id):
                items = SafeSnapshotDAO.shared.snapshots(assetId: id, sort: sort, limit: limit)
            case .all:
                items = SafeSnapshotDAO.shared.snapshots(sort: sort, limit: limit)
            }
            Self.refreshUserIfNeeded(items)
            let (titles, snapshots) = SnapshotDataSource.categorizedItems(items, sort: sort)
            let (indexMap, filteredItemsCount) = SnapshotDataSource.indexMapAndItemsCount(models: snapshots)
            DispatchQueue.main.sync {
                guard let weakSelf = self, !op.isCancelled else {
                    self?.isLoading = false
                    return
                }
                weakSelf.didLoadEarliestLocalSnapshot = items.count < SnapshotDataSource.numberOfItemsPerPage
                weakSelf.rawItems = items
                weakSelf.indexMap = indexMap
                weakSelf.numberOfFilteredItems = filteredItemsCount
                weakSelf.titles = titles
                weakSelf.snapshots = snapshots
                weakSelf.onReload?()
                weakSelf.isLoading = false
                if filteredItemsCount < SnapshotDataSource.numberOfItemsPerPage {
                    weakSelf.loadMoreIfPossible()
                }
            }
        }
        queue.addOperation(op)
    }
    
    func reloadFromRemote() {
        let job: RefreshSnapshotsJob
        switch category {
        case .user(let id):
            job = RefreshSnapshotsJob(category: .opponent(id: id))
        case .asset(let id):
            job = RefreshSnapshotsJob(category: .asset(id: id))
        case .all:
            job = RefreshSnapshotsJob(category: .all)
        case .address:
            loadAddressSnapshots()
            return
        }
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    func loadAddressSnapshots() {
        guard case let .address(asset, destination, tag) = category else {
            return
        }
//        AssetAPI.snapshots(limit: 300, assetId: asset, destination: destination, tag: tag) { [weak self](result) in
//            guard let weakSelf = self else {
//                return
//            }
//            switch result {
//            case let .success(snapshots):
//                let items = snapshots.compactMap(SnapshotItem.init)
//                let (titles, snapshots) = SnapshotDataSource.categorizedItems(items, sort: weakSelf.sort, filter: weakSelf.filter)
//                let (indexMap, filteredItemsCount) = SnapshotDataSource.indexMapAndItemsCount(models: snapshots)
//                weakSelf.rawItems = items
//                weakSelf.indexMap = indexMap
//                weakSelf.numberOfFilteredItems = filteredItemsCount
//                weakSelf.titles = titles
//                weakSelf.snapshots = snapshots
//                weakSelf.onReload?()
//            case let .failure(error):
//                showAutoHiddenHud(style: .error, text: error.localizedDescription)
//            }
//        }
    }
    
    func loadMoreIfPossible() {
        guard !didLoadEarliestLocalSnapshot else {
            loadMoreRemoteSnapshotsIfNeeded()
            return
        }
        guard !isLoading else {
            return
        }
        isLoading = true
        let category = self.category
        let sort = self.sort
        let lastSnapshot = self.rawItems.last
        let oldItems = self.rawItems
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self, limit=SnapshotDataSource.numberOfItemsPerPage] in
            let newItems: [SafeSnapshotItem]
            switch category {
            case .user(let id):
                newItems = SafeSnapshotDAO.shared.snapshots(opponentID: id, below: lastSnapshot, sort: sort, limit: limit)
            case .asset(let id):
                newItems = SafeSnapshotDAO.shared.snapshots(assetId: id, below: lastSnapshot, sort: sort, limit: limit)
            case .all:
                newItems = SafeSnapshotDAO.shared.snapshots(below: lastSnapshot, sort: sort, limit: limit)
            case .address:
                newItems = []
            }
            Self.refreshUserIfNeeded(newItems)
            let items = oldItems + newItems
            let (titles, snapshots) = SnapshotDataSource.categorizedItems(items, sort: sort)
            let (indexMap, filteredItemsCount) = SnapshotDataSource.indexMapAndItemsCount(models: snapshots)
            DispatchQueue.main.sync {
                guard let weakSelf = self, !op.isCancelled else {
                    self?.isLoading = false
                    return
                }
                weakSelf.didLoadEarliestLocalSnapshot = newItems.count < SnapshotDataSource.numberOfItemsPerPage
                weakSelf.rawItems = items
                weakSelf.titles = titles
                weakSelf.snapshots = snapshots
                weakSelf.indexMap = indexMap
                weakSelf.numberOfFilteredItems = filteredItemsCount
                weakSelf.onReload?()
                if weakSelf.didLoadEarliestLocalSnapshot {
                    weakSelf.loadMoreRemoteSnapshotsIfNeeded()
                }
                weakSelf.isLoading = false
                if filteredItemsCount < SnapshotDataSource.numberOfItemsPerPage {
                    weakSelf.loadMoreIfPossible()
                }
            }
        }
        queue.addOperation(op)
    }
    
    func setSort(_ sort: Snapshot.Sort) {
        let needsReload = sort != self.sort
        self.sort = sort
        if needsReload {
            reloadFromLocal()
        }
    }
    
    func distanceToLastItem(of indexPath: IndexPath) -> Int? {
        guard let index = indexMap[indexPath] else {
            return nil
        }
        return numberOfFilteredItems - index
    }
    
    @objc func snapshotsDidChange(_ notification: Notification) {
        if let jobId = notification.userInfo?[LoadMoreSnapshotsJob.jobIdUserInfoKey] as? String, remoteLoadingJobIds.contains(jobId) {
            remoteLoadingJobIds.remove(jobId)
            didLoadEarliestRemoteSnapshot = (notification.userInfo?[LoadMoreSnapshotsJob.didLoadEarliestSnapshotUserInfoKey] as? Bool) ?? false
            didLoadEarliestLocalSnapshot = false
            if sort == .createdAt {
                loadMoreIfPossible()
            } else {
                reloadFromLocal()
            }
        } else {
            reloadFromLocal()
        }
    }
    
    private func loadMoreRemoteSnapshotsIfNeeded() {
        guard !didLoadEarliestRemoteSnapshot else {
            return
        }
        let job: LoadMoreSnapshotsJob
        switch category {
        case .user(let id):
            job = LoadMoreSnapshotsJob(category: .opponent(id: id))
        case .asset(let id):
            job = LoadMoreSnapshotsJob(category: .asset(id: id))
        case .all:
            job = LoadMoreSnapshotsJob(category: .all)
        case .address:
            return
        }
        let didAddJob = ConcurrentJobQueue.shared.addJob(job: job)
        if didAddJob {
            remoteLoadingJobIds.insert(job.getJobId())
        }
    }
    
}

extension SnapshotDataSource {
    
    enum Category {
        case address(asset: String, destination: String, tag: String)
        case user(id: String)
        case asset(id: String)
        case all
    }
    
    // This method will apply filters, and categorize items imported
    typealias CategorizedItems = (titles: [String], snapshots: [[SafeSnapshotItem]])
    private static func categorizedItems(_ items: [SafeSnapshotItem], sort: Snapshot.Sort) -> CategorizedItems {
        switch sort {
        case .createdAt:
            var titles = [String]()
            var snapshots = [[SafeSnapshotItem]]()
            for item in items {
                let title = DateFormatter.dateSimple.string(from: item.createdAt.toUTCDate())
                if title == titles.last {
                    snapshots[snapshots.count - 1].append(item)
                } else {
                    titles.append(title)
                    snapshots.append([item])
                }
            }
            return (titles, snapshots)
        case .amount:
            return ([""], [items])
        }
    }
    
    private static func indexMapAndItemsCount(models: [[Any]]) -> ([IndexPath: Int], Int) {
        var index = 0
        var result = [IndexPath: Int]()
        for section in 0..<models.count {
            for row in 0..<models[section].count {
                result[IndexPath(row: row, section: section)] = index
                index += 1
            }
        }
        return (result, index)
    }
    
    private static func refreshUserIfNeeded(_ snapshots: [SafeSnapshotItem]) {
        var inexistedUserIds = snapshots.compactMap(\.opponentUserID)
        inexistedUserIds = Array(Set(inexistedUserIds))
        if !inexistedUserIds.isEmpty {
            ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: inexistedUserIds))
        }
    }
    
}
