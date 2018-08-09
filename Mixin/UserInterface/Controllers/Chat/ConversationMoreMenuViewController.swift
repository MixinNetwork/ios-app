import UIKit

class ConversationMoreMenuViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var fixedCollectionView: UICollectionView!
    @IBOutlet weak var appsCollectionView: UICollectionView!
        
    var fixedJobs = [Job]() {
        didSet {
            DispatchQueue.main.async {
                self.fixedCollectionView.reloadData()
            }
        }
    }
    var apps = [App]() {
        didSet {
            DispatchQueue.main.async {
                self.appsCollectionView.reloadData()
            }
        }
    }
    var contentHeight: CGFloat {
        return apps.count > 0 ? appsCollectionView.frame.maxY : fixedCollectionView.frame.maxY
    }
    
    private let cellReuseId = "ExtensionCell"
    
    private var conversationViewController: ConversationViewController? {
        return parent as? ConversationViewController
    }
    
    private var conversationId: String? {
        return conversationViewController?.conversationId
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.shadowColor = UIColor.black.cgColor
        fixedCollectionView.register(UINib(nibName: "ConversationExtensionCell", bundle: .main), forCellWithReuseIdentifier: cellReuseId)
        fixedCollectionView.dataSource = self
        fixedCollectionView.delegate = self
        appsCollectionView.register(UINib(nibName: "ConversationExtensionCell", bundle: .main), forCellWithReuseIdentifier: cellReuseId)
        appsCollectionView.dataSource = self
        appsCollectionView.delegate = self
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.shadowPath = UIBezierPath(roundedRect: view.bounds, cornerRadius: 8).cgPath
    }
    
}

extension ConversationMoreMenuViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == fixedCollectionView {
            return fixedJobs.count
        } else {
            return apps.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! ConversationExtensionCell
        if collectionView == fixedCollectionView {
            let job = fixedJobs[indexPath.row]
            cell.imageView.image = job.image
            cell.label.text = job.title
        } else {
            let app = apps[indexPath.row]
            if let url = URL(string: app.iconUrl) {
                cell.imageView.sd_setImage(with: url, completed: nil)
            }
            cell.label.text = app.name
        }
        return cell
    }
    
}

extension ConversationMoreMenuViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        conversationViewController?.toggleMoreMenu(delay: 0)
        if collectionView == fixedCollectionView {
            let job = fixedJobs[indexPath.row]
            switch job {
            case .camera:
                conversationViewController?.imagePickerController.presentCamera()
            case .photo:
                conversationViewController?.pickPhotoOrVideoAction()
            case .file:
                conversationViewController?.documentAction()
            case .transfer:
                conversationViewController?.transferAction()
            case .contact:
                conversationViewController?.contactAction()
            }
        } else {
            let app = apps[indexPath.row]
            guard let url = URL(string: app.homeUri), let conversationId = self.conversationId else {
                return
            }
            WebWindow.instance(conversationId: conversationId).presentPopupControllerAnimated(url: url)
        }
    }
    
}

extension ConversationMoreMenuViewController {
    
    enum Job {
        case camera
        case photo
        case file
        case transfer
        case contact
        
        var image: UIImage {
            switch self {
            case .camera:
                return #imageLiteral(resourceName: "ic_conversation_camera")
            case .photo:
                return #imageLiteral(resourceName: "ic_conversation_photo")
            case .file:
                return #imageLiteral(resourceName: "ic_conversation_file")
            case .transfer:
                return #imageLiteral(resourceName: "ic_conversation_transfer")
            case .contact:
                return #imageLiteral(resourceName: "ic_conversation_contact")
            }
        }
        
        var title: String {
            switch self {
            case .camera:
                return Localized.CHAT_MENU_CAMERA
            case .photo:
                return Localized.CHAT_MENU_PHOTO
            case .file:
                return Localized.CHAT_MENU_FILE
            case .transfer:
                return Localized.CHAT_MENU_TRANSFER
            case .contact:
                return Localized.CHAT_MENU_CONTACT
            }
        }
    }
    
}
