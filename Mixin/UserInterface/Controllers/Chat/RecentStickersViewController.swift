import UIKit
import MixinServices

class RecentStickersViewController: StickersViewController {
    
    init(index: Int) {
        super.init(nibName: nil, bundle: nil)
        self.index = index
        NotificationCenter.default.addObserver(self, selector: #selector(stickerUsedAtDidUpdate(_:)), name: .StickerUsedAtDidUpdate, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override var updateUsedAtAfterSent: Bool {
        return false
    }
    
    @objc func stickerUsedAtDidUpdate(_ notification: Notification) {
        guard let sticker = notification.object as? StickerItem else {
            return
        }
        if let index = stickers.firstIndex(where: { $0.stickerId == sticker.stickerId }) {
            collectionView.performBatchUpdates({
                stickers.remove(at: index)
                stickers.insert(sticker, at: 0)
                collectionView.moveItem(at: IndexPath(item: index, section: 0),
                                        to: IndexPath(item: 0, section: 0))
            }, completion: nil)
        } else if stickers.count >= StickerInputModelController.maxNumberOfRecentStickers {
            collectionView.performBatchUpdates({
                stickers.removeLast()
                stickers.insert(sticker, at: 0)
                collectionView.deleteItems(at: [IndexPath(item: stickers.count - 1, section: 0)])
                collectionView.insertItems(at: [IndexPath(item: 0, section: 0)])
            }, completion: nil)
        } else {
            collectionView.performBatchUpdates({
                stickers.insert(sticker, at: 0)
                collectionView.insertItems(at: [IndexPath(item: 0, section: 0)])
            }, completion: nil)
        }
    }
    
}
