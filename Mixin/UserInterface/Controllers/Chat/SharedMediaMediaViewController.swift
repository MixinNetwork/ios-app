import UIKit

class SharedMediaMediaViewController: UIViewController, SharedMediaContentViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionLayout: UICollectionViewFlowLayout!
    
    var conversationId: String!
    
    private let queue = DispatchQueue(label: "one.mixin.ios.gallery")
    private let numberOfCellPerLine: CGFloat = 4
    private let numberOfItemsPerFetch = 30
    
    private var dates = [String]()
    private var items = [String: [GalleryItem]]()
    private var loadedMessageIds = Set<String>()
    private var isLoadingEarlier = false
    private var didLoadEarliest = false
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(conversationDidChange(_:)),
                                               name: .ConversationDidChange,
                                               object: nil)
        collectionLayout.sectionHeadersPinToVisibleBounds = true
        collectionView.dataSource = self
        collectionView.delegate = self
        let conversationId = self.conversationId!
        let fetchItemsCount = numberOfItemsPerFetch
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            let items = MessageDAO.shared.getGalleryItems(conversationId: conversationId, location: nil, count: fetchItemsCount)
            let (dates, map) = weakSelf.categorizedItems(items: items)
            let loadedMessageIds = Set(items.map({ $0.messageId }))
            DispatchQueue.main.async {
                weakSelf.dates = dates
                weakSelf.items = map
                weakSelf.loadedMessageIds = loadedMessageIds
                weakSelf.collectionView.reloadData()
            }
        }
    }
    
    override func viewWillLayoutSubviews() {
        var width = view.bounds.width
            - collectionLayout.sectionInset.horizontal
            - collectionLayout.minimumInteritemSpacing * (numberOfCellPerLine - 1)
        width = floor((width) / numberOfCellPerLine)
        collectionLayout.itemSize = CGSize(width: width, height: width)
        super.viewWillLayoutSubviews()
    }
    
    @objc func conversationDidChange(_ notification: Notification) {
        guard let change = notification.object as? ConversationChange, change.conversationId == conversationId else {
            return
        }
        switch change.action {
        case .updateMessage(let messageId):
            updateMessage(messageId: messageId)
        case .recallMessage(let messageId):
            removeItem(messageId: messageId)
        default:
            break
        }
    }
    
    private func updateMessage(messageId: String) {
        guard loadedMessageIds.contains(messageId) else {
            return
        }
        queue.async { [weak self] in
            guard let message = MessageDAO.shared.getMessage(messageId: messageId), let item = GalleryItem(message: message) else {
                return
            }
            let date = item.createdAt.toUTCDate()
            let title = DateFormatter.dateSimple.string(from: date)
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                guard let section = weakSelf.dates.firstIndex(of: title), var items = weakSelf.items[title], let row = items.firstIndex(where: { $0.messageId == item.messageId }) else {
                    return
                }
                items[row] = item
                weakSelf.items[title] = items
                let indexPath = IndexPath(row: row, section: section)
                weakSelf.collectionView.reloadItems(at: [indexPath])
            }
        }
    }
    
    private func removeItem(messageId: String) {
        loadedMessageIds.remove(messageId)
        for (date, var items) in self.items {
            guard let row = items.firstIndex(where: { $0.messageId == messageId }) else {
                continue
            }
            guard let section = self.dates.firstIndex(of: date) else {
                return
            }
            if items.count == 1 {
                self.dates.remove(at: section)
                self.items[date] = nil
                collectionView.deleteSections(IndexSet(integer: section))
            } else {
                items.remove(at: row)
                self.items[date] = items
                let indexPath = IndexPath(row: row, section: section)
                collectionView.deleteItems(at: [indexPath])
            }
        }
    }
    
    private func visibleCell(of messageId: String) -> SharedMediaCell? {
        for case let cell as SharedMediaCell in collectionView.visibleCells {
            if cell.item?.messageId == messageId {
                return cell
            }
        }
        return nil
    }
    
    private func setCell(of messageId: String, contentViewHidden hidden: Bool) {
        guard let cell = visibleCell(of: messageId) else {
            return
        }
        cell.contentView.isHidden = hidden
    }
    
    private func categorizedItems(items: [GalleryItem]) -> (dates: [String], map: [String: [GalleryItem]]) {
        var dates = [String]()
        var map = [String: [GalleryItem]]()
        for item in items {
            let date = item.createdAt.toUTCDate()
            let title = DateFormatter.dateSimple.string(from: date)
            if map[title] != nil {
                map[title]!.append(item)
            } else {
                dates.append(title)
                map[title] = [item]
            }
        }
        return (dates, map)
    }
    
}

extension SharedMediaMediaViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        dates.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items[dates[section]]?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.shared_media, for: indexPath)!
        let date = dates[indexPath.section]
        if let item = items[date]?[indexPath.row] {
            cell.render(item: item)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader,
                                                                   withReuseIdentifier: R.reuseIdentifier.shared_media_header,
                                                                   for: indexPath)!
        view.label.text = dates[indexPath.section]
        return view
    }
    
}

extension SharedMediaMediaViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let items = self.items[dates[indexPath.section]], let cell = collectionView.cellForItem(at: indexPath) as? SharedMediaCell else {
            return
        }
        let item = items[indexPath.row]
        if let galleryViewController = UIApplication.homeContainerViewController?.galleryViewController {
            galleryViewController.conversationId = conversationId
            galleryViewController.show(item: item, from: cell)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard !didLoadEarliest, !isLoadingEarlier else {
            return
        }
        guard indexPath.section == dates.count - 1, let lastDate = dates.last, let lastItems = items[lastDate], indexPath.row >= lastItems.count - 10, let lastItem = lastItems.last else {
            return
        }
        isLoadingEarlier = true
        let conversationId = self.conversationId!
        let fetchItemsCount = numberOfItemsPerFetch
        var loadedMessageIds = self.loadedMessageIds
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            let items = MessageDAO.shared.getGalleryItems(conversationId: conversationId, location: lastItem, count: -fetchItemsCount).reversed()
            var (dates, map) = weakSelf.categorizedItems(items: Array(items))
            let messageIds = items.map({ $0.messageId })
            loadedMessageIds.formUnion(messageIds)
            DispatchQueue.main.sync {
                if let lastCurrentDate = weakSelf.dates.last, lastCurrentDate == dates.first {
                    dates.removeFirst()
                    if let items = map[lastDate] {
                        weakSelf.items[lastDate]?.append(contentsOf: items)
                    }
                }
                weakSelf.dates.append(contentsOf: dates)
                for date in dates {
                    weakSelf.items[date] = map[date]
                }
                weakSelf.loadedMessageIds = loadedMessageIds
                weakSelf.collectionView.reloadData()
                weakSelf.isLoadingEarlier = false
                weakSelf.didLoadEarliest = items.count < fetchItemsCount
            }
        }
    }
    
}

extension SharedMediaMediaViewController: GalleryViewControllerDelegate {
    
    func galleryViewController(_ viewController: GalleryViewController, cellFor item: GalleryItem) -> GalleryTransitionSource? {
        return visibleCell(of: item.messageId)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willShow item: GalleryItem) {
        guard UIApplication.homeContainerViewController?.pipController?.item != item else {
            return
        }
        setCell(of: item.messageId, contentViewHidden: true)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didShow item: GalleryItem) {
        setCell(of: item.messageId, contentViewHidden: false)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willDismiss item: GalleryItem) {
        setCell(of: item.messageId, contentViewHidden: true)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didCancelDismissalFor item: GalleryItem) {
        setCell(of: item.messageId, contentViewHidden: false)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didDismiss item: GalleryItem, relativeOffset: CGFloat?) {
        setCell(of: item.messageId, contentViewHidden: false)
    }
    
}
