import UIKit
import PhotosUI
import CoreServices
import SDWebImage
import MixinServices

class StickerManagerViewController: UICollectionViewController {
    
    private var stickers = [StickerItem]()
    private var isDeleteStickers = false
    private var pickerContentOffset = CGPoint.zero
    
    private weak var rightBarButton: BusyButton?
    
    private lazy var itemSize: CGSize = {
        let minWidth: CGFloat = UIScreen.main.bounds.width > 400 ? 120 : 100
        let rowCount = floor(UIScreen.main.bounds.size.width / minWidth)
        let itemWidth = (UIScreen.main.bounds.size.width - (rowCount + 1) * 8) / rowCount
        return CGSize(width: itemWidth, height: itemWidth)
    }()
    
    private lazy var selectButton: UIBarButtonItem = .busyButton(
        title: R.string.localizable.select(),
        target: self,
        action: #selector(selectItems(_:))
    )
    
    private lazy var deleteButton: UIBarButtonItem = .busyButton(
        title: R.string.localizable.delete(),
        target: self,
        action: #selector(deleteSelections(_:))
    )
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.chat.sticker_manager()!
        vc.title = R.string.localizable.my_stickers()
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = selectButton
        rightBarButton = navigationItem.rightBarButtonItem?.customView as? BusyButton
        view.backgroundColor = R.color.background()
        fetchStickers()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fetchStickers),
                                               name: StickerDAO.favoriteStickersDidChangeNotification,
                                               object: nil)
    }
    
    @objc private func fetchStickers() {
        DispatchQueue.global().async { [weak self] in
            let stickers = StickerDAO.shared.getFavoriteStickers()
            DispatchQueue.main.async {
                self?.stickers = stickers
                self?.collectionView?.reloadData()
                self?.rightBarButton?.isEnabled = stickers.count > 0
            }
        }
    }
    
    @objc private func deleteSelections(_ sender: BusyButton) {
        guard !sender.isBusy, let selectionCells = collectionView?.indexPathsForSelectedItems, selectionCells.count > 0 else {
            navigationItem.rightBarButtonItem = selectButton
            isDeleteStickers = false
            collectionView?.allowsMultipleSelection = false
            collectionView?.reloadData()
            return
        }
        sender.isBusy = true
        
        let stickerIds: [String] = selectionCells.compactMap { (indexPath) -> String? in
            guard indexPath.row < stickers.count else {
                return nil
            }
            return stickers[indexPath.row].stickerId
        }
        
        StickerAPI.removeSticker(stickerIds: stickerIds, completion: { [weak self] (result) in
            sender.isBusy = false
            switch result {
            case .success:
                DispatchQueue.global().async {
                    if let album = AlbumDAO.shared.getPersonalAlbum() {
                        StickerRelationshipDAO.shared.removeStickers(albumId: album.albumId, stickerIds: stickerIds)
                    }
                    
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        weakSelf.navigationItem.rightBarButtonItem = weakSelf.selectButton
                        weakSelf.isDeleteStickers = !weakSelf.isDeleteStickers
                        weakSelf.collectionView?.allowsMultipleSelection = false
                        weakSelf.fetchStickers()
                    }
                }
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        })
    }
    
    @objc private func selectItems(_ sender: Any) {
        navigationItem.rightBarButtonItem = deleteButton
        navigationController?.navigationBar.setNeedsLayout()
        navigationController?.navigationBar.layoutIfNeeded()
        isDeleteStickers = true
        collectionView?.allowsMultipleSelection = true
        collectionView?.reloadData()
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.favorite_sticker, for: indexPath)!
        if isDeleteStickers {
            cell.render(sticker: stickers[indexPath.row], isDeleteStickers: isDeleteStickers)
        } else {
            if indexPath.row == 0 {
                cell.selectionImageView.isHidden = true
                cell.stickerView.load(image: R.image.ic_sticker_add(), contentMode: .center)
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
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.preferredAssetRepresentationMode = .current
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }
    
}

// MARK: - PHPickerViewControllerDelegate
extension StickerManagerViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.presentingViewController?.dismiss(animated: true) {
            guard let provider = results.first?.itemProvider else {
                return
            }
            self.load(itemProvider: provider)
        }
    }
    
}

// MARK: - Private works
extension StickerManagerViewController {
    
    private func load(itemProvider: NSItemProvider) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        let hideHud = {
            DispatchQueue.main.async {
                hud.hide()
            }
        }
        let handleError = { (error: Error?) in
            if let error = error {
                reporter.report(error: error)
            }
            DispatchQueue.main.async {
                showAutoHiddenHud(style: .error, text: R.string.localizable.operation_failed())
            }
        }
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
            itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.gif.identifier) { [weak self] (source, error) in
                hideHud()
                guard
                    let source = source,
                    let image = SDAnimatedImage(contentsOfFile: source.path)
                else {
                    handleError(error)
                    return
                }
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    let vc = StickerAddViewController(source: .image(image))
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        } else if itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] (image, error) in
                hideHud()
                guard let image = image as? UIImage else {
                    handleError(error)
                    return
                }
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    let vc = StickerAddViewController(source: .image(image))
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
    }
    
}
