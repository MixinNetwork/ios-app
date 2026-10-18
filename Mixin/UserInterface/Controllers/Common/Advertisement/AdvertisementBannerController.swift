import UIKit
import MixinServices

final class AdvertisementBannerController: NSObject {
    
    protocol Delegate: AnyObject {
        
        func advertisementBannerController(
            _ controller: AdvertisementBannerController,
            requestAction action: AdvertisementBanner.Action,
            for banner: AdvertisementBanner,
        )
        
        func advertisementBannerController(
            _ controller: AdvertisementBannerController,
            requestDismiss banner: AdvertisementBanner,
        )
        
    }
    
    enum BannerSectionPosition<Section> {
        case first
        case after(Section)
    }
    
    enum SnapshotUpdate {
        case reloadData
        case differences(animated: Bool)
    }
    
    weak var delegate: (any AdvertisementBannerController.Delegate)?
    
    private(set) var placement: AppBanner.Placement?
    private(set) var banners: [AdvertisementBanner] = []
    
    private let outlineInBannerCell: Bool
    private let containerHorizontalMargin: CGFloat = 20
    private let interitemSpacing: CGFloat = 6
    private let unfocusedCellScale: CGFloat = 0.93
    private let topContentInset: CGFloat = 0
    private let bottomContentInset: CGFloat
    private let infiniteIllusionMultiplier: Int = {
        if #available(iOS 17.0, *) {
            7
        } else {
            1
        }
    }()
    
    private weak var collectionView: UICollectionView?
    private weak var bannerAutoScrollingTimer: Timer?
    
    private var isViewAppearing = false
    private var isTouchingCollectionView = false
    private var allowsReloadingBanners = true
    private var focusedBannerIndexPath: IndexPath?
    private var isApplyingSnapshot = false
    private var updateID = UUID()
    private var requestID = UUID()
    
    private var displayItemsCount: Int {
        if banners.count <= 1 {
            banners.count
        } else {
            banners.count * infiniteIllusionMultiplier
        }
    }
    
    init(outlineInBannerCell: Bool, sectionBottomInset: CGFloat) {
        self.outlineInBannerCell = outlineInBannerCell
        self.bottomContentInset = sectionBottomInset
        super.init()
    }
    
    deinit {
        bannerAutoScrollingTimer?.invalidate()
    }
    
    func attach(collectionView: UICollectionView) {
        self.collectionView = collectionView
        let touchDetectionRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(detectTouchingOnCollectionView(_:))
        )
        touchDetectionRecognizer.minimumPressDuration = 0
        touchDetectionRecognizer.cancelsTouchesInView = false
        touchDetectionRecognizer.delaysTouchesBegan = false
        touchDetectionRecognizer.delaysTouchesEnded = false
        touchDetectionRecognizer.delegate = self
        collectionView.addGestureRecognizer(touchDetectionRecognizer)
    }
    
    func viewWillAppear() {
        isViewAppearing = true
        scheduleAutoScrolling()
        updateCellTransforms()
    }
    
    func viewWillDisappear() {
        isViewAppearing = false
        allowsReloadingBanners = true
        requestID = UUID()
        invalidateAutoScrolling()
    }
    
    func bannerCellRegistration() -> UICollectionView.CellRegistration<AdvertisementBannerCell, AdvertisementBanner> {
        UICollectionView.CellRegistration<AdvertisementBannerCell, AdvertisementBanner>(
            cellNib: UINib(resource: R.nib.advertisementBannerCell)
        ) { [weak self] cell, indexPath, banner in
            cell.banner = banner
            cell.delegate = self
            if let self {
                cell.drawOutline = self.outlineInBannerCell
                if self.banners.count <= 1 {
                    cell.transform = .identity
                }
            }
        }
    }
    
    func handleSelection(of banner: AdvertisementBanner) {
        delegate?.advertisementBannerController(self, requestAction: .background, for: banner)
    }
    
    func layoutSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        if banners.count <= 1 {
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(81),
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: itemSize,
                subitems: [item],
            )
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: topContentInset,
                leading: containerHorizontalMargin,
                bottom: bottomContentInset,
                trailing: containerHorizontalMargin,
            )
            return section
        }
        
        let containerWidth = environment.container.contentSize.width
        let itemWidth = max(0, containerWidth - containerHorizontalMargin * 2)
        let heightDimension: NSCollectionLayoutDimension
        if #available(iOS 17.0, *) {
            heightDimension = .uniformAcrossSiblings(estimate: 81)
        } else {
            heightDimension = .estimated(81)
        }
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: heightDimension,
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        // Let the content determine its height before the outer group equalizes pages.
        let contentGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(81),
            ),
            subitems: [item],
        )
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(itemWidth),
            heightDimension: heightDimension,
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [contentGroup],
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = interitemSpacing
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.contentInsets = NSDirectionalEdgeInsets(
            top: topContentInset,
            leading: 0,
            bottom: bottomContentInset,
            trailing: 0,
        )
        if #available(iOS 17.0, *) {
            section.orthogonalScrollingProperties.bounce = .always
        }
        
        section.visibleItemsInvalidationHandler = { [weak self] (visibleItems, scrollOffset, environment) in
            guard let self else {
                return
            }
            self.updateCellTransforms()
            guard !self.isApplyingSnapshot else {
                return
            }
            let visibleCells = visibleItems.filter { item in
                item.representedElementCategory == .cell
            }
            let containerCenterX = scrollOffset.x + environment.container.contentSize.width / 2
            let focusCell = visibleCells.min { a, b in
                abs(a.center.x - containerCenterX) < abs(b.center.x - containerCenterX)
            }
            self.focusedBannerIndexPath = focusCell?.indexPath
        }
        return section
    }
    
    func update<Section: Hashable, Item: Hashable>(
        placement: AppBanner.Placement?,
        banners: [AdvertisementBanner],
        snapshot: NSDiffableDataSourceSnapshot<Section, Item>,
        dataSource: UICollectionViewDiffableDataSource<Section, Item>,
        section: Section,
        position: BannerSectionPosition<Section>,
        itemConstructor: (AdvertisementBanner, Int) -> Item,
        mode: SnapshotUpdate,
        completion: (() -> Void)?,
    ) {
        let focusedBanner: AdvertisementBanner?
        if placement == self.placement,
           let indexPath = focusedBannerIndexPath,
           !self.banners.isEmpty
        {
            focusedBanner = self.banners[indexPath.item % self.banners.count]
        } else {
            focusedBanner = nil
        }
        invalidateAutoScrolling()
        if placement != self.placement {
            allowsReloadingBanners = true
            requestID = UUID()
        }
        self.placement = placement
        self.banners = placement == nil ? [] : banners
        self.focusedBannerIndexPath = nil
        self.isApplyingSnapshot = true
        // Only the latest snapshot may restore focus or restart the timer.
        let updateID = UUID()
        self.updateID = updateID
        
        var snapshot = snapshot
        insertBanners(
            into: &snapshot,
            at: position,
            section: section,
            itemConstructor: itemConstructor,
        )
        let finish: () -> Void = { [weak self, weak dataSource] in
            guard let self, self.updateID == updateID else {
                return
            }
            self.isApplyingSnapshot = false
            if let sectionIndex = dataSource?.snapshot().indexOfSection(section) {
                self.restoreFocus(in: sectionIndex, preferredBanner: focusedBanner)
            }
            self.scheduleAutoScrolling()
            self.updateCellTransforms()
            completion?()
        }
        switch mode {
        case .reloadData:
            dataSource.applySnapshotUsingReloadData(snapshot, completion: finish)
        case .differences(let animated):
            dataSource.apply(snapshot, animatingDifferences: animated, completion: finish)
        }
    }
    
    func reloadBannersIfAllowed(
        chainIDs: Set<String>?,
        completion: @escaping ([AppBanner]) -> Void
    ) {
        guard allowsReloadingBanners && isViewAppearing else {
            return
        }
        guard let placement else {
            return
        }
        allowsReloadingBanners = false
        let requestID = UUID()
        self.requestID = requestID
        RewardAPI.appBanners(queue: .global()) { [weak self] result in
            switch result {
            case .failure(let error):
                Logger.general.debug(category: "Banner", message: "\(error)")
            case .success(let remoteBanners):
                AppBanner.saveToCache(remoteBanners: remoteBanners)
                if remoteBanners.isEmpty {
                    AppGroupUserDefaults.Wallet.closedBannerIDs = []
                }
                let closedBannerIDs = Set(AppGroupUserDefaults.Wallet.closedBannerIDs)
                let availableBanners = remoteBanners.filter { banner in
                    guard banner.placement.knownCase == placement else {
                        return false
                    }
                    if closedBannerIDs.contains(banner.bannerID) {
                        return false
                    }
                    if let endAt = DateFormatter.iso8601Full.date(from: banner.endAt),
                       endAt.timeIntervalSinceNow < 0
                    {
                        return false
                    }
                    if let chainIDs, !banner.available(to: chainIDs) {
                        return false
                    }
                    return true
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.requestID == requestID, self.placement == placement else {
                        return
                    }
                    let closedBannerIDs = Set(AppGroupUserDefaults.Wallet.closedBannerIDs)
                    completion(availableBanners.filter { !closedBannerIDs.contains($0.bannerID) })
                }
            }
        }
    }
    
    @objc private func detectTouchingOnCollectionView(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            isTouchingCollectionView = true
            invalidateAutoScrolling()
        case .ended, .cancelled, .failed:
            isTouchingCollectionView = false
            scheduleAutoScrolling()
        case .possible, .changed:
            fallthrough
        @unknown default:
            invalidateAutoScrolling()
        }
    }
    
}

extension AdvertisementBannerController: AdvertisementBannerCell.Delegate {
    
    func advertisementBannerCell(
        _ cell: AdvertisementBannerCell,
        requestPerformAction banner: AdvertisementBanner,
        index: Int
    ) {
        delegate?.advertisementBannerController(self, requestAction: .button(index), for: banner)
    }
    
    func advertisementBannerCell(
        _ cell: AdvertisementBannerCell,
        requestDismiss banner: AdvertisementBanner
    ) {
        delegate?.advertisementBannerController(self, requestDismiss: banner)
    }
    
}

extension AdvertisementBannerController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
    
}

extension AdvertisementBannerController {
    
    private func insertBanners<Section: Hashable, Item: Hashable>(
        into snapshot: inout NSDiffableDataSourceSnapshot<Section, Item>,
        at position: BannerSectionPosition<Section>,
        section: Section,
        itemConstructor: (AdvertisementBanner, Int) -> Item
    ) {
        let multiplier = infiniteIllusionMultiplier
        let displayItems: [Item]
        if banners.count <= 1 || multiplier == 1 {
            displayItems = banners.map { itemConstructor($0, 0) }
        } else {
            let groups: [[Item]] = (-multiplier / 2 ..< 0).map { offset in
                banners.map { banner in
                    itemConstructor(banner, offset)
                }
            } + [
                banners.map { banner in
                    itemConstructor(banner, 0)
                },
            ] + (1 ... multiplier / 2).map { offset in
                banners.map { banner in
                    itemConstructor(banner, offset)
                }
            }
            displayItems = groups.flatMap { $0 }
        }
        if snapshot.sectionIdentifiers.contains(section) {
            snapshot.deleteItems(snapshot.itemIdentifiers(inSection: section))
            if displayItems.isEmpty {
                snapshot.deleteSections([section])
                focusedBannerIndexPath = nil
            } else {
                snapshot.appendItems(displayItems, toSection: section)
            }
        } else if !displayItems.isEmpty {
            switch position {
            case .first:
                if let firstSection = snapshot.sectionIdentifiers.first {
                    snapshot.insertSections([section], beforeSection: firstSection)
                } else {
                    snapshot.appendSections([section])
                }
            case .after(let targetSection):
                if snapshot.sectionIdentifiers.contains(targetSection) {
                    snapshot.insertSections([section], afterSection: targetSection)
                } else if let firstSection = snapshot.sectionIdentifiers.first {
                    snapshot.insertSections([section], afterSection: firstSection)
                } else {
                    snapshot.appendSections([section])
                }
            }
            snapshot.appendItems(displayItems, toSection: section)
        }
    }
    
    private func restoreFocus(in sectionIndex: Int, preferredBanner: AdvertisementBanner?) {
        guard let collectionView, !banners.isEmpty,
              sectionIndex < collectionView.numberOfSections
        else {
            return
        }
        let bannerIndex = preferredBanner.flatMap { banners.firstIndex(of: $0) } ?? 0
        let centerGroupStart = banners.count > 1 ? (infiniteIllusionMultiplier / 2) * banners.count : 0
        let item = centerGroupStart + bannerIndex
        guard item < collectionView.numberOfItems(inSection: sectionIndex) else {
            return
        }
        let indexPath = IndexPath(item: item, section: sectionIndex)
        focusedBannerIndexPath = indexPath
        if #available(iOS 17.0, *) {
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
        }
        updateCellTransforms()
    }
    
    private func scheduleAutoScrolling() {
        bannerAutoScrollingTimer?.invalidate()
        bannerAutoScrollingTimer = nil
        guard #available(iOS 17.0, *) else {
            return
        }
        guard isViewAppearing, !isApplyingSnapshot, banners.count > 1, collectionView != nil else {
            return
        }
        bannerAutoScrollingTimer = .scheduledTimer(
            withTimeInterval: 3,
            repeats: true
        ) { [weak self] _ in
            guard let self, self.isViewAppearing, !self.isTouchingCollectionView else {
                return
            }
            self.resetBannersToCenter()
            guard let focusedIndexPath = self.focusedBannerIndexPath else {
                return
            }
            let nextItem = focusedIndexPath.item + 1
            guard nextItem < self.displayItemsCount else {
                return
            }
            let nextIndexPath = IndexPath(item: nextItem, section: focusedIndexPath.section)
            self.collectionView?.scrollToItem(
                at: nextIndexPath,
                at: .centeredHorizontally,
                animated: true
            )
        }
    }
    
    private func invalidateAutoScrolling() {
        bannerAutoScrollingTimer?.invalidate()
        bannerAutoScrollingTimer = nil
    }
    
    private func resetBannersToCenter() {
        guard #available(iOS 17.0, *) else {
            return
        }
        guard banners.count > 1, let focusedIndexPath = focusedBannerIndexPath else {
            return
        }
        let multiplier = infiniteIllusionMultiplier
        let centerGroupStart = (multiplier / 2) * banners.count
        let bannerIndex = focusedIndexPath.item % banners.count
        let centerItem = centerGroupStart + bannerIndex
        if focusedIndexPath.item != centerItem {
            let newIndexPath = IndexPath(item: centerItem, section: focusedIndexPath.section)
            collectionView?.scrollToItem(at: newIndexPath, at: .centeredHorizontally, animated: false)
            self.focusedBannerIndexPath = newIndexPath
            updateCellTransforms()
        }
    }
    
    private func updateCellTransforms() {
        guard #available(iOS 17.0, *) else {
            return
        }
        guard let collectionView, banners.count > 1 else {
            if let collectionView, banners.count <= 1 {
                for cell in collectionView.visibleCells {
                    guard let bannerCell = cell as? AdvertisementBannerCell else {
                        continue
                    }
                    bannerCell.transform = .identity
                }
            }
            return
        }
        let containerWidth = collectionView.bounds.width
        let itemWidth = containerWidth - containerHorizontalMargin * 2
        guard itemWidth > 0 else {
            return
        }
        let screenCenterX = containerWidth / 2
        let distance = itemWidth + interitemSpacing
        let maxScaleReduction = max(0, 1.0 - unfocusedCellScale)
        
        for cell in collectionView.visibleCells {
            guard let bannerCell = cell as? AdvertisementBannerCell,
                  let superview = bannerCell.superview
            else {
                continue
            }
            let centerInCollectionView = superview.convert(bannerCell.center, to: collectionView)
            let offsetFromCenter = centerInCollectionView.x - screenCenterX
            let absOffset = abs(offsetFromCenter)
            let t = distance > 0 ? min(1.0, absOffset / distance) : 0
            let scale = 1.0 - maxScaleReduction * t
            let sign: CGFloat = offsetFromCenter < 0 ? 1 : -1
            let shiftX = sign * (1.0 - scale) * (itemWidth / 2)
            bannerCell.transform = CGAffineTransform(translationX: shiftX, y: 0).scaledBy(x: scale, y: scale)
            bannerCell.layer.zPosition = CGFloat(Int(scale * 1000))
        }
    }
    
}
