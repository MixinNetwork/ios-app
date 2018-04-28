import UIKit

class StickerPageViewController: UIViewController {

    static let recentStickersRowColumn = 6
    static var itemSize: CGSize {
        return UIScreen.main.bounds.width > 400
            ? CGSize(width: 120, height: 120)
            : CGSize(width: 100, height: 100)
    }

    static func numberOfRecentStickers(forLayoutWidth layoutWidth: CGFloat) -> Int {
        return Int(floor(layoutWidth / itemSize.width)) * recentStickersRowColumn
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var isRecentPage = false
    
    private let stickerCellReuseId = "StickerCell"
    
    private var stickers = [Sticker]()
    private var stickerPanelViewController: StickerPanelViewController? {
        return parent as? StickerPanelViewController
    }
    private var conversationViewController: ConversationViewController? {
        return parent?.parent as? ConversationViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let itemSize = StickerPageViewController.itemSize
            let layoutWidth = AppDelegate.current.window!.bounds.width
            let numberOfItemsPerRow = floor(layoutWidth / itemSize.width)
            let whitespaceWidth = layoutWidth - numberOfItemsPerRow * itemSize.width
            let margin = whitespaceWidth / (numberOfItemsPerRow + 1)
            layout.sectionInset = UIEdgeInsets(top: 8, left: margin, bottom: 8, right: margin)
            layout.minimumLineSpacing = 8
            layout.itemSize = itemSize
        }
    }

    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        if view.safeAreaInsets.bottom != 0, let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionInset.bottom = max(0, layout.sectionInset.top - view.safeAreaInsets.bottom)
        }
    }
    
    func reload(stickers: [Sticker]) {
        self.stickers = stickers
        collectionView.reloadData()
    }
    
    class func instance() -> StickerPageViewController {
        return Storyboard.chat.instantiateViewController(withIdentifier: "sticker_page") as! StickerPageViewController
    }

}

extension StickerPageViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: stickerCellReuseId, for: indexPath) as! StickerCollectionViewCell
        if let url = URL(string: stickers[indexPath.row].assetUrl) {
            cell.imageView.sd_setImage(with: url, completed: nil)
        }
        return cell
    }
    
}

extension StickerPageViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let sticker = stickers[indexPath.row]
        conversationViewController?.dataSource?.sendMessage(type: .SIGNAL_STICKER, value: sticker)
        if !isRecentPage {
            DispatchQueue.global().async { [weak self] in
                StickerDAO.shared.updateUsedAt(albumId: sticker.albumId, name: sticker.name, usedAt: Date().toUTCString())
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                    self?.stickerPanelViewController?.reloadRecentPage()
                })
            }
        }
    }
    
}
