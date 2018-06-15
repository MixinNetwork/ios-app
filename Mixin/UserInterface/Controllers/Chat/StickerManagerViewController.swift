import UIKit
import FLAnimatedImage
import Photos

class StickerManagerViewController: UICollectionViewController {

    private var stickers = [Sticker]()
    private var isDeleteStickers = false

    private lazy var itemSize: CGSize = {
        let minWidth: CGFloat = UIScreen.main.bounds.width > 400 ? 120 : 100
        let rowCount = floor(UIScreen.main.bounds.size.width / minWidth)
        let itemWidth = (UIScreen.main.bounds.size.width - (rowCount + 1) * 8) / rowCount
        return CGSize(width: itemWidth, height: itemWidth)
    }()
    private var videoPickerController: UIViewController {
        let picker = PickerViewController.instance(filterMediaType: .image)
        picker.delegate = self
        return ContainerViewController.instance(viewController: picker, title: Localized.IMAGE_PICKER_TITLE_CAMERA_ROLL)
    }

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

    func prepareBar(rightButton: StateResponsiveButton) {
        rightButton.isEnabled = true
        rightButton.setTitleColor(.systemTint, for: .normal)
    }

    func barRightButtonTappedAction() {
        if isDeleteStickers {
            guard !(container?.rightButton.isBusy ?? true), let selectionCells = collectionView?.indexPathsForSelectedItems, selectionCells.count > 0 else {
                return
            }
            container?.rightButton.isBusy = true

            let stickerIds: [String] = selectionCells.flatMap { (indexPath) -> String? in
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
                    weakSelf.container?.rightButton.setTitle(Localized.ACTION_REMOVE, for: .normal)
                    weakSelf.isDeleteStickers = !weakSelf.isDeleteStickers
                    weakSelf.collectionView?.allowsMultipleSelection = false
                    weakSelf.collectionView?.deleteItems(at: selectionCells)
                    weakSelf.isDeleteStickers = !weakSelf.isDeleteStickers
                case .failure:
                    NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.STICKER_REMOVE_FAILED)
                }
            })
        } else {
            container?.rightButton.setTitle(Localized.ACTION_DONE, for: .normal)
            isDeleteStickers = true
            collectionView?.allowsMultipleSelection = true
            collectionView?.reloadData()
        }
    }

    func textBarRightButton() -> String? {
        return Localized.ACTION_REMOVE
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
            if indexPath.row == stickers.count {
                cell.selectionImageView.isHidden = true
                cell.stickerImageView.image = #imageLiteral(resourceName: "ic_sticker_add")
            } else {
                cell.render(sticker: stickers[indexPath.row], isDeleteStickers: isDeleteStickers)
            }
        }

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isDeleteStickers, indexPath.row == stickers.count else {
            return
        }
        
        navigationController?.pushViewController(videoPickerController, animated: true)
    }
}

extension StickerManagerViewController: PickerViewControllerDelegate {

    func pickerController(_ picker: PickerViewController, didFinishPickingMediaWithAsset asset: PHAsset) {
        navigationController?.pushViewController(StickerAddViewController.instance(asset: asset), animated: true)
    }

}


class FavoriteStickerCell: UICollectionViewCell {

    @IBOutlet weak var selectionImageView: UIImageView!
    @IBOutlet weak var stickerImageView: FLAnimatedImageView!
    @IBOutlet weak var selectionMaskView: UIView!
    

    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
    }

    override var isSelected: Bool {
        didSet {
            if !selectionImageView.isHidden {
                selectionImageView.image = isSelected ? #imageLiteral(resourceName: "ic_member_selected") : #imageLiteral(resourceName: "ic_sticker_normal")
                selectionMaskView.isHidden = !isSelected
            }
        }
    }

    func render(sticker: Sticker, isDeleteStickers: Bool) {
        selectionImageView.isHidden = !isDeleteStickers
        if let url = URL(string: sticker.assetUrl) {
            stickerImageView.sd_setImage(with: url)
        }
    }
}
