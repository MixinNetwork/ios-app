import UIKit
import Photos

class PhotoConversationExtensionViewController: UICollectionViewController, ConversationExtensionViewController {
    
    private let cellReuseId = "cell"
    private let fetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }()
    
    private var assets: PHFetchResult<PHAsset>!
    
    var canBeFullsized: Bool {
        return false
    }
    
    init() {
        let layout = UICollectionViewFlowLayout()
        let separatorLineWidth: CGFloat = 1
        let numberOfItemsPerRow: CGFloat = ScreenSize.isPlusWidth ? 4 : 3
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
        return assets.count + 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! PhotoPickerCell
        if indexPath.row == 0 {
            cell.thumbImageView.backgroundColor = .black
            cell.thumbImageView.image = UIImage(named: "Conversation/ic_camera_large")
            cell.thumbImageView.contentMode = .center
        } else {
            cell.thumbImageView.backgroundColor = .white
            cell.render(asset: assets[indexPath.row - 1])
            cell.thumbImageView.contentMode = .scaleAspectFill
        }
        return cell
    }
    
}

extension PhotoConversationExtensionViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let conversationViewController = conversationViewController else {
            return
        }
        if indexPath.row == 0 {
            conversationViewController.imagePickerController.presentCamera()
        } else {
            let vc = AssetSendViewController.instance(asset: assets[indexPath.row - 1],
                                                      dataSource: conversationViewController.dataSource)
            conversationViewController.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}
