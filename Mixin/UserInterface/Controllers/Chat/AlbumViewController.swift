import UIKit
import Photos

class AlbumViewController: UITableViewController {

    private var allAlbums = [SmartAlbum]()
    private var isFilterCustomSticker = false
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        container?.leftButton.setImage(R.image.ic_title_close(), for: .normal)
    }
    
    private func loadAlbums() {
        DispatchQueue.global().async {
            var allAlbums = [SmartAlbum?]()
            if let cameraRollAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject {
                allAlbums.append(SmartAlbum(collection: cameraRollAlbum, isCameraRoll: true))
            }
            PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil).enumerateObjects { (collection, _, _) in
                allAlbums.append(SmartAlbum(collection: collection))
            }
            PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil).enumerateObjects { (collection, _, _) in
                allAlbums.append(SmartAlbum(collection: collection))
            }
            self.allAlbums = allAlbums.compactMap{ $0 }.sorted(by: { (preAlbum, nextAlbum) -> Bool in
                guard preAlbum.order == nextAlbum.order else {
                    return preAlbum.order > nextAlbum.order
                }
                return preAlbum.title.compare(nextAlbum.title) == .orderedAscending
            })
            DispatchQueue.main.sync {
                self.tableView?.reloadData()
            }
        }
    }

    class func instance(isFilterCustomSticker: Bool = false) -> UIViewController {
        let vc = R.storyboard.photo.album()!
        vc.loadAlbums()
        vc.isFilterCustomSticker = isFilterCustomSticker
        return ContainerViewController.instance(viewController: vc, title: Localized.IMAGE_PICKER_TITLE_ALBUMS)
    }

}

extension AlbumViewController: ContainerViewControllerDelegate {

    func barLeftButtonTappedAction() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
}

extension AlbumViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allAlbums.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell_identifier_album") as! AlbumCell
        let album = allAlbums[indexPath.row]
        cell.localIdentifier = album.identifier
        cell.requestId = PHCachingImageManager.default().requestImage(for: album.lastAsset, targetSize: cell.thumbImageView.frame.size, contentMode: .aspectFill, options: nil) { (image, _) in
            guard cell.localIdentifier == album.identifier else {
                return
            }
            cell.thumbImageView.image = image
        }
        cell.titleLabel.text = album.title
        cell.countLabel.text = "\(album.assetCount)"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let album = allAlbums[indexPath.row]
        let pickerViewController = PickerViewController.instance(collection: album.assetCollection, isFilterCustomSticker: isFilterCustomSticker, scrollToOffset: CGPoint.zero)
        let vc = ContainerViewController.instance(viewController: pickerViewController, title: album.title)
        navigationController?.pushViewController(vc, animated: true)
    }

}

class AlbumCell: ModernSelectedBackgroundCell {

    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!

    var requestId: PHImageRequestID = -1
    var localIdentifier: String!

    override func prepareForReuse() {
        super.prepareForReuse()
        PHCachingImageManager.default().cancelImageRequest(requestId)
    }

}

fileprivate struct SmartAlbum {

    let title: String
    let assetCount: Int
    let identifier: String
    let isCameraRoll: Bool
    let fetchResult: PHFetchResult<PHAsset>
    let assetCollection: PHAssetCollection
    let lastAsset: PHAsset
    let order: Int

    init?(collection: PHAssetCollection, isCameraRoll: Bool = false) {
        let assets = PHAsset.fetchAssets(in: collection, options: nil)
        guard let lastAsset = assets.lastObject else {
            return nil
        }
        if collection.assetCollectionType == .smartAlbum {
            switch collection.assetCollectionSubtype {
            case .smartAlbumUserLibrary:
                if !isCameraRoll {
                    return nil
                }
                order = 9
            case .smartAlbumFavorites:
                order = 8
            case .smartAlbumVideos:
                order = 7
            case .smartAlbumSelfPortraits:
                order = 6
            case .smartAlbumPanoramas:
                order = 5
            case .smartAlbumSlomoVideos:
                order = 4
            case .smartAlbumTimelapses:
                order = 3
            case .smartAlbumBursts:
                order = 2
            case .smartAlbumScreenshots:
                order = 1
            default:
                return nil
            }
        } else {
            order = 0
        }
        self.title = collection.localizedTitle ?? ""
        self.assetCount = assets.count
        self.identifier = collection.localIdentifier
        self.isCameraRoll = isCameraRoll
        self.fetchResult = assets
        self.assetCollection = collection
        self.lastAsset = lastAsset
    }
}
