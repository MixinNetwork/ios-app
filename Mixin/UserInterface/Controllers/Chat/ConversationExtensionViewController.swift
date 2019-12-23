import UIKit
import MixinServices

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
    var apps = [(app: App, user: UserItem?)]() {
        didSet {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.extension, for: indexPath)!
        if indexPath.row < fixedExtensions.count {
            let ext = fixedExtensions[indexPath.row]
            cell.imageView.image = ext.image
            cell.label.text = ext.title
            cell.avatarImageView.isHidden = true
            cell.backgroundImageView.isHidden = true
        } else {
            let appAndUser = apps[indexPath.row - fixedExtensions.count]
            let app = appAndUser.app
            cell.imageView.sd_setImage(with: URL(string: app.iconUrl))
            cell.label.text = app.name
            if let user = appAndUser.user {
                cell.avatarImageView.setImage(with: user)
                cell.avatarImageView.isHidden = false
            } else {
                cell.avatarImageView.isHidden = true
            }
            cell.backgroundImageView.isHidden = false
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
                UIApplication.homeContainerViewController?.pipController?.pauseAction(self)
                conversationViewController?.imagePickerController.presentCamera()
            case .file:
                UIApplication.homeContainerViewController?.pipController?.pauseAction(self)
                conversationViewController?.documentAction()
            case .transfer:
                conversationViewController?.transferAction()
            case .contact:
                conversationViewController?.contactAction()
            case .call:
                UIApplication.homeContainerViewController?.pipController?.pauseAction(self)
                conversationViewController?.callAction()
            }
            if ext.dismissPanelAfterSent {
                (parent as? ConversationInputViewController)?.dismissCustomInput(minimize: true)
            }
        } else {
            let app = apps[indexPath.row - fixedExtensions.count].app
            if let conversationId = dataSource?.conversationId, let parent = conversationViewController {
                let userInfo = ["source": "ConversationExtension", "identityNumber": app.appNumber]
                Reporter.report(event: .openApp, userInfo: userInfo)
                WebViewController.presentInstance(with: .init(conversationId: conversationId, app: app), asChildOf: parent)
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
