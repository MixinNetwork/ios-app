import UIKit

class StickerStoreViewController: UIViewController {

    @IBOutlet weak var mainCollectionView: UICollectionView!
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.chat.sticker_store()!
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func settingAction(_ sender: Any) {
        
    }
    
}
