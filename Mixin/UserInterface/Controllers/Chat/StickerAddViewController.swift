import UIKit
import FLAnimatedImage

class StickerAddViewController: UIViewController {

    @IBOutlet weak var stickerImageView: FLAnimatedImageView!

    private var message: MessageItem?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let url = message?.assetUrl ?? message?.mediaUrl {
            stickerImageView.sd_setImage(with: URL(string: url))
        }
        if let assetUrl = message?.assetUrl {
            stickerImageView.sd_setImage(with: URL(string: assetUrl))
        } else if let mediaUrl = message?.mediaUrl {
            stickerImageView.sd_setImage(with: MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl))
        }
    }

    class func instance(message: MessageItem) -> UIViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "sticker_add") as! StickerAddViewController
        vc.message = message
        return ContainerViewController.instance(viewController: vc, title: Localized.STICKER_ADD_TITLE)
    }

    class func instance() -> UIViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "sticker_add") as! StickerAddViewController
        return ContainerViewController.instance(viewController: vc, title: Localized.STICKER_ADD_TITLE)
    }

}
