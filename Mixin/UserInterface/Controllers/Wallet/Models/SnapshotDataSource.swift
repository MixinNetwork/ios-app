import UIKit
import MixinServices

class SnapshotDataSource {
    
    static let numberOfItemsPerPage = 50
    
    let category: Category
    
    var onReload: (() -> ())?
    
    private(set) var titles = [String]()
    private(set) var snapshots = [[SnapshotItem]]()
    
    private let queue = OperationQueue()
    
    private var rawItems = [SnapshotItem]()
    private var indexMap = [IndexPath: Int]()
    private var numberOfFilteredItems = 0
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
            case .user(let id):
                items = SnapshotDAO.shared.getSnapshots(opponentId: id, sort: sort, filter: filter, limit: SnapshotDataSource.numberOfItemsPerPage)
            case .asset(let id):
                items = SnapshotDAO.shared.getSnapshots(assetId: id, sort: sort, filter: filter, limit: SnapshotDataSource.numberOfItemsPerPage)
            case .all:
                items = SnapshotDAO.shared.getSnapshots(sort: sort, filter: filter, limit: SnapshotDataSource.numberOfItemsPerPage)
            }
            SnapshotDataSource.refreshUserIfNeeded(items)
            let (titles, snapshots) = SnapshotDataSource.categorizedItems(items, sort: sort, filter: filter)
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
        let lastSnapshot = self.rawItems.last
        let oldItems = self.rawItems
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            let newItems: [SnapshotItem]
            switch category {
            case .user(let id):
                newItems = SnapshotDAO.shared.getSnapshots(opponentId: id, below: lastSnapshot, sort: sort, filter: filter, limit: SnapshotDataSource.numberOfItemsPerPage)
            case .asset(let id):
                newItems = SnapshotDAO.shared.getSnapshots(assetId: id, below: lastSnapshot, sort: sort, filter: filter, limit: SnapshotDataSource.numberOfItemsPerPage)
            case .all:
                newItems = SnapshotDAO.shared.getSnapshots(below: lastSnapshot, sort: sort, filter: filter, limit: SnapshotDataSource.numberOfItemsPerPage)
            }
            SnapshotDataSource.refreshUserIfNeeded(newItems)
            let items = oldItems + newItems
            let (titles, snapshots) = SnapshotDataSource.categorizedItems(items, sort: sort, filter: filter)
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
        }
        let didAddJob = ConcurrentJobQueue.shared.addJob(job: job)
        if didAddJob {
            remoteLoadingJobIds.insert(job.getJobId())
        }
    }
    
}

extension SnapshotDataSource {
    
    enum Category {
        case user(id: String)
        case asset(id: String)
        case all
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
