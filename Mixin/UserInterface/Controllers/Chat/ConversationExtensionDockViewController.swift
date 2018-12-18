import UIKit

class ConversationExtensionDockViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var fixedExtensions = [FixedExtension]() {
        didSet {
            collectionView.reloadSections(IndexSet(integer: 0))
            loadDefaultExtensionIfNeeded()
        }
    }
    
    var apps = [App]() {
        didSet {
            collectionView.reloadSections(IndexSet(integer: 1))
            loadDefaultExtensionIfNeeded()
        }
    }
    
    var conversationViewController: ConversationViewController? {
        return parent as? ConversationViewController
    }
    
    private let cellReuseId = "extension"
    
    private var conversationId: String? {
        return conversationViewController?.conversationId
    }
    
    private lazy var photoViewController = PhotoConversationExtensionViewController()
    private lazy var callViewController = CallConversationExtensionViewController.instance()
    private lazy var contactViewController = ContactConversationExtensionViewController.instance()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
}

extension ConversationExtensionDockViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? fixedExtensions.count : apps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! ConversationExtensionCell
        if indexPath.section == 0 {
            cell.imageView.image = fixedExtensions[indexPath.row].image
            cell.imageView.contentMode = .center
        } else {
            cell.imageView.contentMode = .scaleAspectFit
            if let url = URL(string: apps[indexPath.row].iconUrl) {
                cell.imageView.sd_setImage(with: url, completed: nil)
            }
        }
        return cell
    }
    
}

extension ConversationExtensionDockViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            let ext = fixedExtensions[indexPath.row]
            if ext == .transfer {
                conversationViewController?.transferAction()
                return false
            } else if ext == .file {
                conversationViewController?.pickFileAction()
                return false
            } else {
                removeAllSelections()
                return true
            }
        } else {
            removeAllSelections()
            return true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let ext = fixedExtensions[indexPath.row]
            switch ext {
            case .photo:
                conversationViewController?.loadExtension(viewController: photoViewController)
            case .file, .transfer:
                break
            case .contact:
                conversationViewController?.loadExtension(viewController: contactViewController)
            case .call:
                conversationViewController?.loadExtension(viewController: callViewController)
            }
        } else {
            let app = apps[indexPath.row]
            if let url = URL(string: app.homeUri) {
                conversationViewController?.loadExtension(url: url)
            }
        }
    }
    
}

extension ConversationExtensionDockViewController {
    
    private func loadDefaultExtensionIfNeeded() {
        guard let selectedIndexPaths = collectionView.indexPathsForSelectedItems, selectedIndexPaths.isEmpty, !fixedExtensions.isEmpty || !apps.isEmpty else {
            return
        }
        func loadIndexPath(_ indexPath: IndexPath) {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .left)
            collectionView(collectionView, didSelectItemAt: indexPath)
        }
        if !fixedExtensions.isEmpty {
            loadIndexPath(IndexPath(item: 0, section: 0))
        } else if !apps.isEmpty {
            loadIndexPath(IndexPath(item: 0, section: 1))
        }
    }
    
    private func removeAllSelections() {
        guard let indexPaths = collectionView.indexPathsForSelectedItems else {
            return
        }
        for indexPath in indexPaths {
            collectionView.deselectItem(at: indexPath, animated: false)
        }
    }
    
    enum FixedExtension {
        
        case photo
        case file
        case transfer
        case contact
        case call
        
        var image: UIImage {
            switch self {
            case .photo:
                return UIImage(named: "Conversation/ic_camera")!
            case .file:
                return UIImage(named: "Conversation/ic_file")!
            case .transfer:
                return UIImage(named: "Conversation/ic_transfer")!
            case .contact:
                return UIImage(named: "Conversation/ic_contact")!
            case .call:
                return UIImage(named: "Conversation/ic_call")!
            }
        }
        
    }
    
}
