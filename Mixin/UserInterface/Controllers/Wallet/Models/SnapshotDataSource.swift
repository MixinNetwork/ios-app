import UIKit

class SnapshotDataSource {
    
    static let numberOfItemsPerPage = 50
    
    let category: Category
    
    var onReload: (() -> ())?
    
    private(set) var titles = [String]()
    private(set) var snapshots = [[SnapshotItem]]()
    
    private let queue = OperationQueue()
    
    private var rawItems = [SnapshotItem]()
    private var indexMap = [IndexPath: Int]()
    private var isLoading = false
    private var didLoadEarliestLocalSnapshot = false
    private var didLoadEarliestRemoteSnapshot = false
    private var sort = Snapshot.Sort.createdAt
    private var filter = Snapshot.Filter.all
    private var remoteLoadingJobIds = Set<String>()
    
    init(category: Category) {
        self.category = category
        queue.maxConcurrentOperationCount = 1
        NotificationCenter.default.addObserver(self, selector: #selector(snapshotsDidChange(_:)), name: .SnapshotDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func reloadFromLocal() {
        queue.cancelAllOperations()
        isLoading = true
        let category = self.category
        let sort = self.sort
        let filter = self.filter
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            let items: [SnapshotItem]
            switch category {
            case .asset(let id):
                items = SnapshotDAO.shared.getSnapshots(assetId: id, sort: sort, limit: SnapshotDataSource.numberOfItemsPerPage)
            case .all:
                items = SnapshotDAO.shared.getSnapshots(sort: sort, limit: SnapshotDataSource.numberOfItemsPerPage)
            }
            SnapshotDataSource.refreshUserIfNeeded(items)
            let (titles, snapshots) = SnapshotDataSource.categorizedItems(items, sort: sort, filter: filter)
            let indexMap = SnapshotDataSource.indexMap(models: snapshots)
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                defer {
                    weakSelf.isLoading = false
                }
                guard !op.isCancelled else {
                    return
                }
                weakSelf.didLoadEarliestLocalSnapshot = items.count < SnapshotDataSource.numberOfItemsPerPage
                weakSelf.rawItems = items
                weakSelf.indexMap = indexMap
                weakSelf.titles = titles
                weakSelf.snapshots = snapshots
                weakSelf.onReload?()
            }
        }
        queue.addOperation(op)
    }
    
    func reloadFromRemote() {
        let job: RefreshSnapshotsJob
        switch category {
        case .asset(let id):
            job = RefreshSnapshotsJob(category: .asset(id: id))
        case .all:
            job = RefreshSnapshotsJob(category: .all)
        }
        ConcurrentJobQueue.shared.addJob(job: job)
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
        let filter = self.filter
        let lastSnapshot = snapshots.last?.last
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            let newItems: [SnapshotItem]
            switch category {
            case .asset(let id):
                newItems = SnapshotDAO.shared.getSnapshots(assetId: id, below: lastSnapshot, sort: sort, limit: SnapshotDataSource.numberOfItemsPerPage)
            case .all:
                newItems = SnapshotDAO.shared.getSnapshots(below: lastSnapshot, sort: sort, limit: SnapshotDataSource.numberOfItemsPerPage)
            }
            SnapshotDataSource.refreshUserIfNeeded(newItems)
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                defer {
                    weakSelf.isLoading = false
                }
                guard !op.isCancelled else {
                    return
                }
                let (titles, snapshots) = SnapshotDataSource.categorizedItems(weakSelf.rawItems + newItems, sort: sort, filter: filter)
                weakSelf.didLoadEarliestLocalSnapshot = newItems.count < SnapshotDataSource.numberOfItemsPerPage
                weakSelf.rawItems += newItems
                weakSelf.indexMap = SnapshotDataSource.indexMap(models: snapshots)
                weakSelf.titles = titles
                weakSelf.snapshots = snapshots
                weakSelf.onReload?()
                if weakSelf.didLoadEarliestLocalSnapshot {
                    weakSelf.loadMoreRemoteSnapshotsIfNeeded()
                }
            }
        }
        queue.addOperation(op)
    }
    
    func setSort(_ sort: Snapshot.Sort, filter: Snapshot.Filter) {
        let needsReload = sort != self.sort || self.filter != filter
        self.sort = sort
        self.filter = filter
        if needsReload {
            reloadFromLocal()
        }
    }
    
    func distanceToLastItem(of indexPath: IndexPath) -> Int? {
        guard let index = indexMap[indexPath] else {
            return nil
        }
        return rawItems.count - index
    }
    
    @objc func snapshotsDidChange(_ notification: Notification) {
        if let jobId = notification.userInfo?[LoadMoreSnapshotsJob.jobIdUserInfoKey] as? String, remoteLoadingJobIds.contains(jobId) {
            remoteLoadingJobIds.remove(jobId)
            didLoadEarliestRemoteSnapshot = (notification.userInfo?[LoadMoreSnapshotsJob.didLoadEarliestSnapshotUserInfoKey] as? Bool) ?? false
            loadMoreIfPossible()
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
        case .asset(let id):
            job = LoadMoreSnapshotsJob(category: .asset(id: id))
        case .all:
            job = LoadMoreSnapshotsJob(category: .all)
        }
        remoteLoadingJobIds.insert(job.getJobId())
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}

extension SnapshotDataSource {
    
    enum Category {
        case asset(id: String)
        case all
        
        var assetId: String? {
            switch self {
            case .asset(let id):
                return id
            case .all:
                return nil
            }
        }
    }
    
    // This method will apply filters, and categorize items imported
    typealias CategorizedItems = (titles: [String], snapshots: [[SnapshotItem]])
    private static func categorizedItems(_ items: [SnapshotItem], sort: Snapshot.Sort, filter: Snapshot.Filter) -> CategorizedItems {
        let visibleSnapshotTypes = filter.snapshotTypes.map({ $0.rawValue })
        let items = items.filter({ visibleSnapshotTypes.contains($0.type) })
        switch sort {
        case .createdAt:
            var titles = [String]()
            var snapshots = [[SnapshotItem]]()
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
    
    private static func indexMap(models: [[Any]]) -> [IndexPath: Int] {
        var index = 0
        var result = [IndexPath: Int]()
        let numberOfInnerModels = models.map({ $0.count })
        for section in 0..<models.count {
            for row in 0..<numberOfInnerModels[section] {
                result[IndexPath(row: row, section: section)] = index
                index += 1
            }
        }
        return result
    }
    
    private static func refreshUserIfNeeded(_ snapshots: [SnapshotItem]) {
        var inexistedUserIds = snapshots
            .filter({ $0.opponentUserFullName == nil })
            .compactMap({ $0.opponentId })
        inexistedUserIds = Array(Set(inexistedUserIds))
        if !inexistedUserIds.isEmpty {
            ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: inexistedUserIds))
        }
    }
    
}
