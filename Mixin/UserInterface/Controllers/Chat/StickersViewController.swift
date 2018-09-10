import UIKit

class StickersViewController: UIViewController {
    
    let cellReuseId = "StickerCell"
    
    var index = NSNotFound
    
    var collectionView: UICollectionView {
        return view as! UICollectionView
    }
    
    var updateUsedAtAfterSent: Bool {
        return true
    }
    
    internal var stickers = [Sticker]()
    
    private var conversationViewController: ConversationViewController? {
        return parent?.parent?.parent as? ConversationViewController
    }
    
    override func loadView() {
        let frame = CGRect(x: 0, y: 0, width: 375, height: 200)
        let layout = StickersCollectionViewFlowLayout(numberOfItemsPerRow: StickerInputModelController.numberOfItemsPerRow)
        let view = UICollectionView(frame: frame, collectionViewLayout: layout)
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.backgroundColor = .white
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(StickerCollectionViewCell.self, forCellWithReuseIdentifier: cellReuseId)
        collectionView.dataSource = self
        collectionView.delegate = self
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
    
}

extension StickersViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! StickerCollectionViewCell
        if let url = URL(string: stickers[indexPath.row].assetUrl) {
            cell.imageView.sd_setImage(with: url, completed: nil)
        }
        return cell
    }
    
}

extension StickersViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        send(sticker: stickers[indexPath.row])
    }
    
}
