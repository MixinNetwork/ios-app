import UIKit
import Photos

class MediaPreviewViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    func load(asset: PHAsset) {
        PHImageManager.default().requestImage(for: asset, targetSize: imageView.bounds.size, contentMode: .aspectFill, options: nil) { (image, _) in
            self.imageView.image = image
        }
    }
    
}
