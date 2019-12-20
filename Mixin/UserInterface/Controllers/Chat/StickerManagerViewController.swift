import UIKit
import YYImage
import Photos

class StickerManagerViewController: UICollectionViewController {

    private var stickers = [StickerItem]()
    private var isDeleteStickers = false
    private var pickerContentOffset = CGPoint.zero

    private lazy var itemSize: CGSize = {
        let minWidth: CGFloat = UIScreen.main.bounds.width > 400 ? 120 : 100
        let rowCount = floor(UIScreen.main.bounds.size.width / minWidth)
        let itemWidth = (UIScreen.main.bounds.size.width - (rowCount + 1) * 8) / rowCount
        return CGSize(width: itemWidth, height: itemWidth)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchStickers()

        NotificationCenter.default.addObserver(forName: .FavoriteStickersDidChange, object: nil, queue: .main) { [weak self] (_) in
            self?.fetchStickers()
        }
    }

    private func fetchStickers() {
        DispatchQueue.global().async { [weak self] in
            let stickers = StickerDAO.shared.getFavoriteStickers()
            DispatchQueue.main.async {
                self?.stickers = stickers
                self?.collectionView?.reloadData()
                self?.container?.rightButton.isEnabled = stickers.count > 0
            }
        }
    }

    class func instance() -> UIViewController {
        let vc = R.storyboard.chat.sticker_manager()!
        return ContainerViewController.instance(viewController: vc, title: Localized.STICKER_MANAGER_TITLE)
    }

}

extension StickerManagerViewController: ContainerViewControllerDelegate {

    func prepareBar(rightButton: StateResponsiveButton) {
        rightButton.isEnabled = true
        rightButton.setTitleColor(.systemTint, for: .normal)
    }

    func barRightButtonTappedAction() {
        if isDeleteStickers {
            guard !(container?.rightButton.isBusy ?? true), let selectionCells = collectionView?.indexPathsForSelectedItems, selectionCells.count > 0 else {
                container?.rightButton.setTitle(Localized.ACTION_SELECT, for: .normal)
                isDeleteStickers = false
                collectionView?.allowsMultipleSelection = false
                collectionView?.reloadData()
                return
            }
            container?.rightButton.isBusy = true

            let stickerIds: [String] = selectionCells.compactMap { (indexPath) -> String? in
                guard indexPath.row < stickers.count else {
                    return nil
                }
                return stickers[indexPath.row].stickerId
            }

            StickerAPI.shared.removeSticker(stickerIds: stickerIds, completion: { [weak self] (result) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.container?.rightButton.isBusy = false
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        if let album = AlbumDAO.shared.getSelfAlbum() {
                            StickerRelationshipDAO.shared.removeStickers(albumId: album.albumId, stickerIds: stickerIds)
                        }

                        DispatchQueue.main.async {
                            guard let weakSelf = self else {
                                return
                            }
                            weakSelf.container?.rightButton.setTitle(Localized.ACTION_SELECT, for: .normal)
                            weakSelf.isDeleteStickers = !weakSelf.isDeleteStickers
                            weakSelf.collectionView?.allowsMultipleSelection = false
                            weakSelf.fetchStickers()
                        }
                    }
                case let .failure(error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            })
        } else {
            container?.rightButton.setTitle(Localized.ACTION_REMOVE, for: .normal)
            isDeleteStickers = true
            collectionView?.allowsMultipleSelection = true
            collectionView?.reloadData()
        }
    }

    func textBarRightButton() -> String? {
        return Localized.ACTION_SELECT
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
                cell.stickerImageView.image = R.image.ic_sticker_add()
            } else {
                cell.render(sticker: stickers[indexPath.row-1], isDeleteStickers: isDeleteStickers)
            }
        }

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isDeleteStickers, indexPath.row == 0 else {
            return
        }

        PHPhotoLibrary.checkAuthorization { [weak self](authorized) in
            guard authorized, let weakSelf = self else {
                return
            }

            let picker = PhotoAssetPickerNavigationController.instance(pickerDelegate: weakSelf, isFilterCustomSticker: true, scrollToOffset: weakSelf.pickerContentOffset)
            weakSelf.present(picker, animated: true, completion: nil)
        }
    }
}

// MARK: - PhotoAssetPickerDelegate
extension StickerManagerViewController: PhotoAssetPickerDelegate {

    func pickerController(_ picker: PickerViewController, contentOffset: CGPoint, didFinishPickingMediaWithAsset asset: PHAsset) {
        self.pickerContentOffset = contentOffset
        navigationController?.pushViewController(StickerAddViewController.instance(asset: asset), animated: true)
    }

}


class FavoriteStickerCell: UICollectionViewCell {

    @IBOutlet weak var selectionImageView: UIImageView!
    @IBOutlet weak var stickerImageView: YYAnimatedImageView!
    @IBOutlet weak var selectionMaskView: UIView!
    

    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
    }

    override var isSelected: Bool {
        didSet {
            if !selectionImageView.isHidden {
                selectionImageView.image = isSelected ? R.image.ic_member_selected() : R.image.ic_sticker_normal()
                selectionMaskView.isHidden = !isSelected
            }
        }
    }

    func render(sticker: StickerItem, isDeleteStickers: Bool) {
        selectionImageView.isHidden = !isDeleteStickers
        if let url = URL(string: sticker.assetUrl) {
            let context = stickerLoadContext(category: sticker.category)
            stickerImageView.sd_setImage(with: url, placeholderImage: nil, context: context)
        }
    }
}
