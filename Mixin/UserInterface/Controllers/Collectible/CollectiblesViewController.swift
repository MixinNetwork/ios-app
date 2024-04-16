import UIKit

final class CollectiblesViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.checkEmpty(dataCount: 0,
                                  text: R.string.localizable.no_collectibles(),
                                  photo: R.image.emptyIndicator.ic_shared_media()!)
    }
    
    @IBAction func scanQRCode(_ sender: Any) {
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
    }
    
}
