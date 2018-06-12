import UIKit
import FLAnimatedImage

class StickerAddViewController: UIViewController {

    @IBOutlet weak var stickerImageView: FLAnimatedImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    class func instance() -> UIViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "sticker_add") as! StickerAddViewController

        return ContainerViewController.instance(viewController: vc, title: "Add Sticker")
    }

}
