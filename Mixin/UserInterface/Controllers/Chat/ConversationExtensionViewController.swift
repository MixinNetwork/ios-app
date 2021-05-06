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
    
    private let numberOfItemsEachLine: CGFloat = 4
    private let itemIconWidth: CGFloat = 60
    
    private var lastLayoutWidth: CGFloat = 0
    
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
        let layoutWidth = view.bounds.width - view.safeAreaInsets.horizontal
        if lastLayoutWidth != layoutWidth {
            let spacing = layoutWidth - numberOfItemsEachLine * itemIconWidth
            let inset = floor(spacing / (numberOfItemsEachLine * 2 + 2))
            collectionViewLayout.sectionInset.left = inset
            collectionViewLayout.sectionInset.right = inset
            collectionViewLayout.itemSize.width = itemIconWidth + 2 * inset
            lastLayoutWidth = layoutWidth
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
        fixedExtensions.count + apps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.extension, for: indexPath)!
        if indexPath.row < fixedExtensions.count {
            let ext = fixedExtensions[indexPath.row]
            cell.imageView.image = ext.image
            cell.imageView.contentMode = .center
            cell.label.text = ext.title
            cell.avatarImageView.isHidden = true
        } else {
            let appAndUser = apps[indexPath.row - fixedExtensions.count]
            let app = appAndUser.app
            cell.imageView.contentMode = .scaleAspectFit
            cell.imageView.sd_setImage(with: URL(string: app.iconUrl))
            cell.label.text = app.name
            if let user = appAndUser.user {
                cell.avatarImageView.setImage(with: user)
                cell.avatarImageView.isHidden = false
            } else {
                cell.avatarImageView.isHidden = true
            }
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
                conversationViewController?.presentDocumentPicker()
            case .transfer:
                conversationViewController?.showTransfer()
            case .contact:
                conversationViewController?.showContactSelector()
            case .call:
                UIApplication.homeContainerViewController?.pipController?.pauseAction(self)
                conversationViewController?.callOwnerUserIfPresent()
            case .groupCall:
                UIApplication.homeContainerViewController?.pipController?.pauseAction(self)
                conversationViewController?.startOrJoinGroupCall()
            case .location:
                conversationViewController?.showLocationPicker()
            }
            if ext.dismissPanelAfterSent {
                (parent as? ConversationInputViewController)?.dismissCustomInput(minimize: true)
            }
        } else {
            let app = apps[indexPath.row - fixedExtensions.count].app
            if let conversationId = composer?.conversationId, let parent = conversationViewController {
                let userInfo = ["source": "ConversationExtension", "identityNumber": app.appNumber]
                reporter.report(event: .openApp, userInfo: userInfo)
                MixinWebViewController.presentInstance(with: .init(conversationId: conversationId, app: app), asChildOf: parent)
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
        case groupCall
        case location
        
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
            case .call, .groupCall:
                return R.image.conversation.ic_extension_call()
            case .location:
                return R.image.conversation.ic_extension_location()
            }
        }
        
        var title: String {
            switch self {
            case .camera:
                return R.string.localizable.chat_menu_camera()
            case .file:
                return R.string.localizable.chat_menu_file()
            case .transfer:
                return R.string.localizable.chat_menu_transfer()
            case .contact:
                return R.string.localizable.chat_menu_contact()
            case .call:
                return R.string.localizable.chat_menu_call()
            case .groupCall:
                return R.string.localizable.chat_menu_group_call()
            case .location:
                return R.string.localizable.chat_menu_location()
            }
        }
        
        var dismissPanelAfterSent: Bool {
            [.transfer, .call, .groupCall].contains(self)
        }
        
    }
    
}
