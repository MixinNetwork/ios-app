import UIKit
import WebKit

class PhotoSendViewController: UIViewController, MixinNavigationAnimating {

    @IBOutlet weak var photoImageView: UIImageView!

    private var image: UIImage!
    private weak var dataSource: ConversationDataSource?

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        photoImageView.image = image
    }

    @IBAction func sendAction(_ sender: Any) {
        dataSource?.sendMessage(type: .SIGNAL_IMAGE, value: image.scaleForUpload())
        navigationController?.popViewController(animated: true)
    }

    
    @IBAction func closeAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    

    class func instance(image: UIImage, dataSource: ConversationDataSource?) -> UIViewController {
       let vc = Storyboard.chat.instantiateViewController(withIdentifier: "send_photo") as! PhotoSendViewController
        vc.image = image
        vc.dataSource = dataSource
        return vc
    }

}

