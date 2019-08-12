import UIKit

class ConversationExtensionViewController: UIViewController, ConversationAccessible {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    
    var fixedExtensions = [FixedExtension]() {
        didSet {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    var apps = [App]() {
        didSet {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
    private let cellReuseId = "extension"
    private let itemCountPerLine: CGFloat = 4
    
    private var availableWidth: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateCollectionViewSectionInsetIfNeeded()
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCollectionViewSectionInsetIfNeeded()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let width = view.bounds.width - view.safeAreaInsets.horizontal
        if availableWidth != width {
            availableWidth = width
            let spacing = (width - itemCountPerLine * collectionViewLayout.itemSize.width) / (itemCountPerLine + 1)
            collectionViewLayout.sectionInset.left = spacing
            collectionViewLayout.sectionInset.right = spacing
            collectionViewLayout.minimumInteritemSpacing = spacing
        }
    }
    
    private func updateCollectionViewSectionInsetIfNeeded() {
        if view.safeAreaInsets.bottom < 20 {
            collectionViewLayout.sectionInset.bottom = 20
        } else {
            collectionViewLayout.sectionInset.bottom = 0
        }
    }
    
}

extension ConversationExtensionViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // TODO: use separated sections for these
        return fixedExtensions.count + apps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! ConversationExtensionCell
        if indexPath.row < fixedExtensions.count {
            let ext = fixedExtensions[indexPath.row]
            cell.imageView.image = ext.image
            cell.label.text = ext.title
        } else {
            let app = apps[indexPath.row - fixedExtensions.count]
            cell.imageView.sd_setImage(with: URL(string: app.iconUrl), completed: nil)
            cell.label.text = app.name
        }
        return cell
    }
    
}

extension ConversationExtensionViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row < fixedExtensions.count {
            let ext = fixedExtensions[indexPath.row]
            switch ext {
            case .camera:
                GalleryVideoItemViewController.currentPipController?.pauseAction(self)
                conversationViewController?.imagePickerController.presentCamera()
            case .file:
                GalleryVideoItemViewController.currentPipController?.pauseAction(self)
                conversationViewController?.documentAction()
            case .transfer:
                conversationViewController?.transferAction()
            case .contact:
                conversationViewController?.contactAction()
            case .call:
                GalleryVideoItemViewController.currentPipController?.pauseAction(self)
                conversationViewController?.callAction()
            }
            if ext.dismissPanelAfterSent {
                (parent as? ConversationInputViewController)?.dismissCustomInput(minimize: true)
            }
        } else {
            let app = apps[indexPath.row - fixedExtensions.count]
            if let url = URL(string: app.homeUri), let conversationId = dataSource?.conversationId {
                UIApplication.logEvent(eventName: "open_app", parameters: ["source": "ConversationExtension", "identityNumber": app.appNumber])
                WebWindow.instance(conversationId: conversationId, app: app)
                    .presentPopupControllerAnimated(url: url)
            }
        }
    }
    
}


extension ConversationExtensionViewController {
    
    enum FixedExtension {
        
        case camera
        case file
        case transfer
        case contact
        case call
        
        var image: UIImage? {
            switch self {
            case .camera:
                return R.image.conversation.ic_extension_camera()
            case .file:
                return R.image.conversation.ic_extension_file()
            case .transfer:
                return R.image.conversation.ic_extension_transfer()
            case .contact:
                return R.image.conversation.ic_extension_contact()
            case .call:
                return R.image.conversation.ic_extension_call()
            }
        }
        
        var title: String {
            switch self {
            case .camera:
                return Localized.CHAT_MENU_CAMERA
            case .file:
                return Localized.CHAT_MENU_FILE
            case .transfer:
                return Localized.CHAT_MENU_TRANSFER
            case .contact:
                return Localized.CHAT_MENU_CONTACT
            case .call:
                return Localized.CHAT_MENU_CALL
            }
        }
        
        var dismissPanelAfterSent: Bool {
            return self == .transfer || self == .call
        }
        
    }
    
}
