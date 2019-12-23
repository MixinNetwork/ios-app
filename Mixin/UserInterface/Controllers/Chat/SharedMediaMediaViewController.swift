import UIKit
import MixinServices

class SharedMediaMediaViewController: UIViewController, SharedMediaContentViewController {
    
    typealias ItemType = GalleryItem
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionLayout: UICollectionViewFlowLayout!
    
    var conversationId: String! {
        didSet {
            dataSource.conversationId = conversationId
        }
    }
    
    private let dataSource = SharedMediaDataSource<ItemType, SharedMediaCategorizer<ItemType>>()
    
    private let numberOfCellPerLine: CGFloat = 4
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionLayout.sectionHeadersPinToVisibleBounds = true
        collectionView.dataSource = self
        collectionView.delegate = self
        dataSource.setDelegate(self)
        dataSource.reload()
    }
    
    override func viewWillLayoutSubviews() {
        var width = view.bounds.width
            - collectionLayout.sectionInset.horizontal
            - collectionLayout.minimumInteritemSpacing * (numberOfCellPerLine - 1)
        width = floor((width) / numberOfCellPerLine)
        collectionLayout.itemSize = CGSize(width: width, height: width)
        super.viewWillLayoutSubviews()
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
    
}

extension SharedMediaMediaViewController: SharedMediaDataSourceDelegate {
    
    func sharedMediaDataSource(_ dataSource: AnyObject, itemsForConversationId conversationId: String, location: ItemType?, count: Int) -> [ItemType] {
        let count = location == nil ? count : -count
        var items = MessageDAO.shared.getGalleryItems(conversationId: conversationId, location: location, count: count)
        if location != nil {
            items = Array(items.reversed())
        }
        return items
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, itemForMessageId messageId: String) -> ItemType? {
        guard let message = MessageDAO.shared.getMessage(messageId: messageId) else {
            return nil
        }
        return GalleryItem(message: message)
    }
    
    func sharedMediaDataSourceDidReload(_ dataSource: AnyObject) {
        collectionView.reloadData()
        collectionView.checkEmpty(dataCount: self.dataSource.numberOfSections,
                                  text: R.string.localizable.chat_shared_media_empty(),
                                  photo: R.image.ic_shared_media()!)
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, didUpdateItemAt indexPath: IndexPath) {
        collectionView.reloadItems(at: [indexPath])
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, didRemoveItemAt indexPath: IndexPath) {
        if self.dataSource.numberOfItems(in: indexPath.section) == 1 {
            collectionView.deleteSections(IndexSet(integer: indexPath.section))
        } else {
            collectionView.deleteItems(at: [indexPath])
        }
    }
    
}

extension SharedMediaMediaViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataSource.numberOfSections
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.numberOfItems(in: section)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.shared_media, for: indexPath)!
        if let item = dataSource.item(at: indexPath) {
            cell.render(item: item)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader,
                                                                   withReuseIdentifier: R.reuseIdentifier.shared_media_header,
                                                                   for: indexPath)!
        view.label.text = dataSource.title(of: indexPath.section)
        return view
    }
    
}

extension SharedMediaMediaViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.item(at: indexPath), let cell = collectionView.cellForItem(at: indexPath) as? SharedMediaCell else {
            return
        }
        if let galleryViewController = UIApplication.homeContainerViewController?.galleryViewController {
            galleryViewController.conversationId = conversationId
            galleryViewController.show(item: item, from: cell)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        dataSource.loadMoreEarlierItemsIfNeeded(location: indexPath)
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
