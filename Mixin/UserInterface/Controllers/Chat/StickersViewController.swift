import UIKit

class StickersViewController: StickersCollectionViewController {
    
    var stickers = [Sticker]()
    
    override var isEmpty: Bool {
        return stickers.isEmpty
    }
    
    func load(stickers: [Sticker]) {
        self.stickers = stickers
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
    }
    
    func send(sticker: Sticker) {
        conversationViewController?.dataSource?.sendMessage(type: .SIGNAL_STICKER, value: sticker)
        conversationViewController?.reduceStickerPanelHeightIfMaximized()
        if updateUsedAtAfterSent {
            DispatchQueue.global().async {
                let newUsedAt = Date().toUTCString()
                StickerDAO.shared.updateUsedAt(stickerId: sticker.stickerId, usedAt: newUsedAt)
                var newSticker = sticker
                newSticker.lastUseAt = newUsedAt
                NotificationCenter.default.postOnMain(name: .StickerUsedAtDidUpdate, object: newSticker)
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickers.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! StickerCollectionViewCell
        if let url = URL(string: stickers[indexPath.row].assetUrl) {
            cell.imageView.sd_setImage(with: url, completed: nil)
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        send(sticker: stickers[indexPath.row])
    }
    
}
