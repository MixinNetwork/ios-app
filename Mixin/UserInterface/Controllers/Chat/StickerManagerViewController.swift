import UIKit
import FLAnimatedImage

class StickerManagerViewController: UICollectionViewController {

    private var stickers = [Sticker]()
    private lazy var itemSize: CGSize = {
        let minWidth: CGFloat = UIScreen.main.bounds.width > 400 ? 120 : 100
        let rowCount = floor(UIScreen.main.bounds.size.width / minWidth)
        let itemWidth = (UIScreen.main.bounds.size.width - (rowCount + 1) * 8) / rowCount
        return CGSize(width: itemWidth, height: itemWidth)
    }()
    private var isDeleteStickers = false

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchStickers()
    }

    private func fetchStickers() {
        DispatchQueue.global().async { [weak self] in
            let stickers = StickerDAO.shared.getFavoriteStickers()
            DispatchQueue.main.async {
                self?.stickers = stickers
                self?.collectionView?.reloadData()
            }
        }
    }

    class func instance() -> UIViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "sticker_manager") as! StickerManagerViewController

        return ContainerViewController.instance(viewController: vc, title: Localized.STICKER_MANAGER_TITLE)
    }

}

extension StickerManagerViewController: ContainerViewControllerDelegate {

    func barRightButtonTappedAction() {

    }

    func textBarRightButton() -> String? {
        return Localized.ACTION_SAVE
    }

}


extension StickerManagerViewController: UICollectionViewDelegateFlowLayout {

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isDeleteStickers ? stickers.count : stickers.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return itemSize
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell_identifier_favorite_sticker", for: indexPath) as! FavoriteStickerCell
        if isDeleteStickers {
            cell.render(sticker: stickers[indexPath.row], isDeleteStickers: isDeleteStickers)
        } else {
            if indexPath.row == 0 {
                cell.selectionImageView.isHidden = true
                cell.stickerImageView.image = #imageLiteral(resourceName: "ic_sticker_add")
            } else {
                cell.render(sticker: stickers[indexPath.row - 1], isDeleteStickers: isDeleteStickers)
            }
        }

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isDeleteStickers {

        } else {
            if indexPath.row == 0 {
                navigationController?.pushViewController(StickerAddViewController.instance(), animated: true)
            }
        }
    }
}


class FavoriteStickerCell: UICollectionViewCell {

    @IBOutlet weak var selectionImageView: UIImageView!
    @IBOutlet weak var stickerImageView: FLAnimatedImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
    }

    override var isSelected: Bool {
        didSet {
            selectionImageView.image = isSelected ? #imageLiteral(resourceName: "ic_member_selected") : #imageLiteral(resourceName: "ic_member_not_selected")
        }
    }

    func render(sticker: Sticker, isDeleteStickers: Bool) {
        selectionImageView.isHidden = !isDeleteStickers
        if let url = URL(string: sticker.assetUrl) {
            stickerImageView.sd_setImage(with: url)
        }
    }
}
