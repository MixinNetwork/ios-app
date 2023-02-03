import UIKit
import Photos
import PhotosUI

class PhotoInputViewController: UIViewController, ConversationInputAccessible {
    
    enum Section: Int, CaseIterable {
        case allPhotos = 0
        case smartAlbums
        case userCollections
    }
    
    @IBOutlet weak var albumsCollectionView: UICollectionView!
    @IBOutlet weak var albumsCollectionLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var limitedAuthorizationControlWrapperView: UIView!
    
    var isAuthorizationLimited = false {
        didSet {
            loadViewIfNeeded()
            limitedAuthorizationControlWrapperView.isHidden = !isAuthorizationLimited
        }
    }
    
    private weak var selectedPhotoInputItemsViewControllerIfLoaded: SelectedPhotoInputItemsViewController?
    private lazy var selectedPhotoInputItemsViewController: SelectedPhotoInputItemsViewController = {
        let controller = R.storyboard.chat.selected_photo_input_items()!
        controller.delegate = self
        selectedPhotoInputItemsViewControllerIfLoaded = controller
        return controller
    }()
    private var allPhotos: PHFetchResult<PHAsset>?
    private var smartAlbums: PHFetchResult<PHAssetCollection>?
    private var sortedSmartAlbums: [PHAssetCollection]?
    private var userCollections: PHFetchResult<PHCollection>?
    private var gridViewController: PhotoInputGridViewController!
    private(set) var selectedAssets: [PHAsset] = []
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        albumsCollectionView.dataSource = self
        albumsCollectionView.delegate = self
        DispatchQueue.global().async { [weak self] in
            let allPhotos: PHFetchResult<PHAsset>?
            if let collection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject {
                allPhotos = PHAsset.fetchAssets(in: collection, options: nil)
            } else {
                allPhotos = nil
            }
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
            let sortedSmartAlbums = sortedAssetCollections(from: smartAlbums)
            let userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
            guard let weakSelf = self else {
                return
            }
            PHPhotoLibrary.shared().register(weakSelf)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.allPhotos = allPhotos
                weakSelf.smartAlbums = smartAlbums
                weakSelf.sortedSmartAlbums = sortedSmartAlbums
                weakSelf.userCollections = userCollections
                weakSelf.albumsCollectionView.reloadData()
                let firstItem = IndexPath(item: 0, section: 0)
                weakSelf.albumsCollectionView.selectItem(at: firstItem, animated: false, scrollPosition: .left)
                weakSelf.reloadGrid(at: firstItem)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let vc = segue.destination as? PhotoInputGridViewController {
            vc.fetchResult = allPhotos
            gridViewController = vc
            gridViewController.delegate = self
            gridViewController.photoInputViewController = self
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let previous = previousTraitCollection, previous.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory else {
            return
        }
        albumsCollectionLayout.invalidateLayout()
        albumsCollectionView.reloadData()
    }
    
    @IBAction func pickFromLibrary(_ sender: Any) {
        guard #available(iOS 14, *) else {
            return
        }
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.preferredAssetRepresentationMode = .current
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }
    
    @IBAction func managePhotoAuthorization(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if #available(iOS 14, *) {
            sheet.addAction(UIAlertAction(title: R.string.localizable.select_more_photos(), style: .default, handler: { _ in
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
            }))
        }
        sheet.addAction(UIAlertAction(title: R.string.localizable.change_settings(), style: .default, handler: { _ in
            UIApplication.openAppSettings()
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    private func reloadGrid(at indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .allPhotos:
            gridViewController.firstCellIsCamera = true
            gridViewController.fetchResult = allPhotos
        case .smartAlbums:
            gridViewController.firstCellIsCamera = false
            if let collection = sortedSmartAlbums?[indexPath.row] {
                gridViewController.fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
            }
        case .userCollections:
            gridViewController.firstCellIsCamera = false
            if let collection = userCollections?[indexPath.row] as? PHAssetCollection {
                gridViewController.fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
            } else {
                gridViewController.fetchResult = nil
            }
        }
    }
    
}

extension PhotoInputViewController: ConversationInputInteractiveResizableViewController {
    
    var interactiveResizableScrollView: UIScrollView {
        return gridViewController.collectionView
    }
    
}

extension PhotoInputViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .allPhotos:
            return 1
        case .smartAlbums:
            return sortedSmartAlbums?.count ?? 0
        case .userCollections:
            return userCollections?.count ?? 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.photo_album, for: indexPath)!
        switch Section(rawValue: indexPath.section)! {
        case .allPhotos:
            cell.textLabel.text = R.string.localizable.all_photos()
        case .smartAlbums:
            cell.textLabel.text = sortedSmartAlbums?[indexPath.row].localizedTitle ?? ""
        case .userCollections:
            cell.textLabel.text = userCollections?[indexPath.row].localizedTitle ?? ""
        }
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Section.allCases.count
    }
    
}

extension PhotoInputViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        reloadGrid(at: indexPath)
    }
    
}

extension PhotoInputViewController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.sync {
            self.dismissSelectedPhotoInputItemsViewControllerIfNeeded()
            if let allPhotos = self.allPhotos, let changeDetails = changeInstance.changeDetails(for: allPhotos) {
                self.allPhotos = changeDetails.fetchResultAfterChanges
            }
            if let smartAlbums = self.smartAlbums, let changeDetails = changeInstance.changeDetails(for: smartAlbums) {
                self.smartAlbums = changeDetails.fetchResultAfterChanges
                self.sortedSmartAlbums = sortedAssetCollections(from: smartAlbums)
            }
            if let userCollections = self.userCollections, let changeDetails = changeInstance.changeDetails(for: userCollections) {
                self.userCollections = changeDetails.fetchResultAfterChanges
            }
        }
    }
    
}

@available(iOS 14, *)
extension PhotoInputViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true) {
            guard let provider = results.first?.itemProvider else {
                return
            }
            let vc = R.storyboard.chat.media_preview()!
            guard vc.canLoad(itemProvider: provider) else {
                showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_share_content())
                return
            }
            vc.load(itemProvider: provider)
            vc.conversationInputViewController = self.conversationInputViewController
            vc.transitioningDelegate = PopupPresentationManager.shared
            vc.modalPresentationStyle = .custom
            self.present(vc, animated: true, completion: nil)
        }
    }
    
}

extension PhotoInputViewController: PhotoInputGridViewControllerDelegate {
    
    func photoInputGridViewController(_ controller: PhotoInputGridViewController, didSelect asset: PHAsset) {
        guard !selectedAssets.contains(asset) else {
            return
        }
        if selectedAssets.isEmpty {
            presentSelectedPhotoInputItemsViewControllerAnimated()
        }
        selectedAssets.append(asset)
        selectedPhotoInputItemsViewController.add(asset)
    }
    
    func photoInputGridViewController(_ controller: PhotoInputGridViewController, didDeselect asset: PHAsset) {
        guard let index = selectedAssets.firstIndex(of: asset) else {
            return
        }
        selectedAssets.remove(at: index)
        if selectedAssets.isEmpty {
            dismissSelectedPhotoInputItemsViewControllerAnimated()
        } else {
            selectedPhotoInputItemsViewController.remove(asset)
        }
    }
    
    func photoInputGridViewControllerDidTapCamera(_ controller: PhotoInputGridViewController) {
        dismissSelectedPhotoInputItemsViewControllerIfNeeded()
    }
    
}

extension PhotoInputViewController: SelectedPhotoInputItemsViewControllerDelegate {
    
    func selectedPhotoInputItemsViewController(_ controller: SelectedPhotoInputItemsViewController, didSend assets: [PHAsset]) {
        sendItems(assets: assets)
    }
    
    func selectedPhotoInputItemsViewController(_ controller: SelectedPhotoInputItemsViewController, didCancelSend assets: [PHAsset]) {
        conversationInputViewController?.dismiss()
    }
    
    func selectedPhotoInputItemsViewController(_ controller: SelectedPhotoInputItemsViewController, didDeselect asset: PHAsset) {
        guard let index = selectedAssets.firstIndex(of: asset) else {
            return
        }
        selectedAssets.remove(at: index)
        gridViewController.updateVisibleCellBadge()
        if selectedAssets.isEmpty {
            dismissSelectedPhotoInputItemsViewControllerAnimated()
        }
    }
   
    func selectedPhotoInputItemsViewController(_ controller: SelectedPhotoInputItemsViewController, didSelectAssetAt index: Int) {
        conversationInputViewController?.setPreferredContentHeightAnimated(.regular)
        let window = SelectedPhotoInputItemsPreviewWindow.instance()
        window.load(assets: selectedAssets, initIndex: index)
        window.delegate = self
        window.presentPopupControllerAnimated()
    }
    
}

extension PhotoInputViewController: SelectedPhotoInputItemsPreviewWindowDelegate {

    func selectedPhotoInputItemsPreviewWindow(_ window: SelectedPhotoInputItemsPreviewWindow, willDismissWindow assets: [PHAsset]) {
        if assets.isEmpty {
            selectedAssets.removeAll()
            dismissSelectedPhotoInputItemsViewControllerAnimated()
        } else {
            selectedAssets = assets
            selectedPhotoInputItemsViewController.updateAssets(assets)
        }
        gridViewController.updateVisibleCellBadge()
    }
    
    func selectedPhotoInputItemsPreviewWindow(_ window: SelectedPhotoInputItemsPreviewWindow, didTapSendItems assets: [PHAsset]) {
        sendItems(assets: assets)
    }
    
    func selectedPhotoInputItemsPreviewWindow(_ window: SelectedPhotoInputItemsPreviewWindow, didTapSendFiles assets: [PHAsset]) {
        sendAsFiles(assets: assets)
    }
    
}

extension PhotoInputViewController {
    
    private func sendItems(assets: [PHAsset]) {
        guard let controller = conversationInputViewController else {
            return
        }
        assets.forEach(controller.send(asset:))
        selectedAssets.removeAll()
        gridViewController.updateVisibleCellBadge()
        dismissSelectedPhotoInputItemsViewControllerAnimated()
    }
    
    private func sendAsFiles(assets: [PHAsset]) {
        guard let controller = conversationInputViewController else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        requestURLs(for: assets) { [weak self] urls in
            hud.hide()
            guard let self = self else {
                return
            }
            urls.forEach(controller.sendFile(url:))
            self.selectedAssets.removeAll()
            self.gridViewController.updateVisibleCellBadge()
            self.dismissSelectedPhotoInputItemsViewControllerAnimated()
        }
    }
    
    func dismissSelectedPhotoInputItemsViewControllerIfNeeded() {
        guard let controller = selectedPhotoInputItemsViewControllerIfLoaded, controller.parent != nil else {
            return
        }
        selectedAssets.removeAll()
        gridViewController.updateVisibleCellBadge()
        gridViewController.view.isUserInteractionEnabled = false
        controller.removeAllAssets()
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        controller.view.snp.removeConstraints()
        gridViewController.view.isUserInteractionEnabled = true
    }
    
    private func presentSelectedPhotoInputItemsViewControllerAnimated() {
        guard
            selectedPhotoInputItemsViewController.parent == nil,
            let conversationInputViewController = conversationInputViewController,
            let inputBarView = conversationInputViewController.inputBarView,
            let conversationViewController = conversationInputViewController.parent
        else {
            return
        }
        gridViewController.view.isUserInteractionEnabled = false
        let controller = selectedPhotoInputItemsViewController
        let viewHeight = selectedPhotoInputItemsViewController.viewHeight
        addChild(controller)
        view.insertSubview(controller.view, at: 0)
        controller.view.snp.makeConstraints({ (make) in
            make.left.right.equalToSuperview()
            make.top.equalTo(inputBarView.snp.bottom).offset(0)
        })
        view.layoutIfNeeded()
        controller.view.snp.updateConstraints { make in
            make.top.equalTo(inputBarView.snp.bottom).offset(-viewHeight)
        }
        UIView.animate(withDuration: 0.3, delay: 0, options: .overdampedCurve) {
            self.view.layoutIfNeeded()
        } completion: { _ in
            conversationViewController.addChild(controller)
            conversationViewController.view.addSubview(controller.view)
            controller.view.snp.remakeConstraints({ (make) in
                make.left.right.equalToSuperview()
                make.top.equalTo(inputBarView.snp.bottom).offset(-viewHeight)
            })
            self.gridViewController.view.isUserInteractionEnabled = true
        }
    }
    
    private func dismissSelectedPhotoInputItemsViewControllerAnimated() {
        guard
            selectedPhotoInputItemsViewController.parent != nil,
            let conversationInputViewController = conversationInputViewController,
            let inputBarView = conversationInputViewController.inputBarView
        else {
            return
        }
        gridViewController.view.isUserInteractionEnabled = false
        let controller = selectedPhotoInputItemsViewController
        let viewHeight = selectedPhotoInputItemsViewController.viewHeight
        addChild(controller)
        view.insertSubview(controller.view, at: 0)
        controller.view.snp.remakeConstraints({ (make) in
            make.left.right.equalToSuperview()
            make.top.equalTo(inputBarView.snp.bottom).offset(-viewHeight)
        })
        view.layoutIfNeeded()
        controller.view.snp.updateConstraints { make in
            make.top.equalTo(inputBarView.snp.bottom).offset(0)
        }
        UIView.animate(withDuration: 0.3, delay: 0, options: .overdampedCurve) {
            self.view.layoutIfNeeded()
        } completion: { _ in
            controller.removeAllAssets()
            controller.view.removeFromSuperview()
            controller.removeFromParent()
            controller.view.snp.removeConstraints()
            self.gridViewController.view.isUserInteractionEnabled = true
        }
    }
    
    private func requestURLs(for assets: [PHAsset], completion: @escaping ((_ urls : [URL]) -> Void)) {
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "one.mixin.messager.PhotoInputViewController.requestPHAssetsURLs", attributes: .concurrent)
        var urls: [URL?] = Array(repeating: nil, count: assets.count)
        for (index, asset) in assets.enumerated() {
            group.enter()
            queue.async(group: group) {
                if asset.mediaType == .image {
                    let options = PHContentEditingInputRequestOptions()
                    options.canHandleAdjustmentData = { (adjustmeta: PHAdjustmentData) -> Bool in true }
                    asset.requestContentEditingInput(with: options, completionHandler: { (contentEditingInput, info) in
                        urls.insert(contentEditingInput?.fullSizeImageURL, at: index)
                        group.leave()
                    })
                } else if asset.mediaType == .video {
                    let options: PHVideoRequestOptions = PHVideoRequestOptions()
                    options.version = .original
                    PHImageManager.default().requestAVAsset(forVideo: asset, options: options, resultHandler: { (asset, audioMix, info) in
                        urls.insert((asset as? AVURLAsset)?.url, at: index)
                        group.leave()
                    })
                }
            }
        }
        group.notify(queue: .main) {
            completion(urls.compactMap { $0 })
        }
    }
    
}

fileprivate let collectionSubtypeOrder: [PHAssetCollectionSubtype: Int] = {
    var idx = -1
    var autoIncrement: Int {
        idx += 1
        return idx
    }
    return [
        .smartAlbumFavorites: autoIncrement,
        .smartAlbumVideos: autoIncrement,
        .smartAlbumScreenshots: autoIncrement,
        .smartAlbumSelfPortraits: autoIncrement,
        .smartAlbumPanoramas: autoIncrement,
        .smartAlbumSlomoVideos: autoIncrement,
        .smartAlbumTimelapses: autoIncrement,
        .smartAlbumAnimated: autoIncrement
    ]
}()

fileprivate func sortedAssetCollections(from: PHFetchResult<PHAssetCollection>) -> [PHAssetCollection] {
    var collections = [PHAssetCollection?](repeating: nil, count: from.count)
    from.enumerateObjects { (obj, idx, nil) in
        collections[idx] = obj
    }
    return collections
        .compactMap({ $0 })
        .filter({
            collectionSubtypeOrder[$0.assetCollectionSubtype] != nil
        })
        .sorted(by: { (one, another) -> Bool in
            let oneOrder = collectionSubtypeOrder[one.assetCollectionSubtype]!
            let anotherOrder = collectionSubtypeOrder[another.assetCollectionSubtype]!
            return oneOrder < anotherOrder
        })
}
