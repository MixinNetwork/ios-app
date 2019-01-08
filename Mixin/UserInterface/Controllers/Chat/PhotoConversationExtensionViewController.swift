import UIKit
import Photos

class PhotoConversationExtensionViewController: UIViewController, ConversationExtensionViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var requestPermissionButton: UIButton!
    
    private let cellReuseId = "cell"
    private let fetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }()
    
    private var assets: PHFetchResult<PHAsset>?
    
    var canBeFullsized: Bool {
        return false
    }
    
    static func instance() -> PhotoConversationExtensionViewController {
        return Storyboard.chat.instantiateViewController(withIdentifier: "extension_photo") as! PhotoConversationExtensionViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let separatorLineWidth: CGFloat = 1
            let numberOfItemsPerRow: CGFloat = ScreenSize.isPlusWidth ? 4 : 3
            let itemWidth = (UIScreen.main.bounds.width - (numberOfItemsPerRow - 1) * separatorLineWidth) / numberOfItemsPerRow
            layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
            layout.minimumLineSpacing = 1
            layout.minimumInteritemSpacing = 0
        }
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UINib(nibName: "PhotoPickerCell", bundle: .main),
                                forCellWithReuseIdentifier: cellReuseId)
        PHPhotoLibrary.requestAuthorization { (status) in
            let isAuthroized = status == .authorized
            if isAuthroized {
                self.assets = PHAsset.fetchAssets(with: self.fetchOptions)
            } else {
                self.assets = nil
            }
            DispatchQueue.main.sync {
                self.requestPermissionButton.isHidden = isAuthroized
                self.collectionView.reloadData()
            }
        }
    }
    
    @IBAction func requestPermissionAction(_ sender: Any) {
        UIApplication.openAppSettings()
    }
    
}

extension PhotoConversationExtensionViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let isAuthorized = PHPhotoLibrary.authorizationStatus() == .authorized
        if isAuthorized, let assets = assets {
            return assets.count + 1
        } else {
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! PhotoPickerCell
        if indexPath.row == 0 {
            cell.thumbImageView.backgroundColor = .black
            cell.thumbImageView.image = UIImage(named: "Conversation/ic_camera_large")
            cell.thumbImageView.contentMode = .center
        } else if let assets = assets {
            cell.thumbImageView.backgroundColor = .white
            cell.render(asset: assets[indexPath.row - 1])
            cell.thumbImageView.contentMode = .scaleAspectFill
        }
        return cell
    }
    
}

extension PhotoConversationExtensionViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let conversationViewController = conversationViewController, let assets = assets else {
            return
        }
        if indexPath.row == 0 {
            conversationViewController.imagePickerController.presentCamera()
        } else {
            let vc = AssetSendViewController.instance(asset: assets[indexPath.row - 1],
                                                      dataSource: conversationViewController.dataSource)
            vc.delegate = conversationViewController
            conversationViewController.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}
