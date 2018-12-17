import UIKit
import Photos

class PhotoConversationExtensionViewController: UICollectionViewController {
    
    private let cellReuseId = "cell"
    private let fetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }()
    private let imageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        return options
    }()
    
    private var assets: PHFetchResult<PHAsset>!
    
    init() {
        let layout = UICollectionViewFlowLayout()
        let separatorLineWidth: CGFloat = 1
        let numberOfItemsPerRow: CGFloat = ScreenSize.isPlusSize ? 4 : 3
        let itemWidth = (UIScreen.main.bounds.width - (numberOfItemsPerRow - 1) * separatorLineWidth) / numberOfItemsPerRow
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumLineSpacing = 1
        layout.minimumInteritemSpacing = 0
        super.init(collectionViewLayout: layout)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = .white
        collectionView.register(UINib(nibName: "PhotoPickerCell", bundle: .main),
                                forCellWithReuseIdentifier: cellReuseId)
        assets = PHAsset.fetchAssets(with: fetchOptions)
        collectionView.reloadData()
    }
    
}

extension PhotoConversationExtensionViewController {
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! PhotoPickerCell
        let asset = assets[indexPath.row]
        cell.localIdentifier = asset.localIdentifier
        let targetSize = cell.thumbImageView.frame.size * 2
        cell.requestId = PHCachingImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: imageRequestOptions) { (image, _) in
            guard cell.localIdentifier == asset.localIdentifier else {
                return
            }
            cell.thumbImageView.image = image
        }
        cell.updateFileTypeView(asset: asset)
        return cell
    }
    
}
