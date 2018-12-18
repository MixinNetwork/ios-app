import UIKit

class ConversationExtensionContainerViewController: UIViewController {
    
    @IBOutlet weak var dockCollectionView: UICollectionView!
    @IBOutlet weak var containerView: UIView!
    
    var fixedExtensions = [FixedConversationExtension]() {
        didSet {
            dockCollectionView.reloadSections(IndexSet(integer: 0))
            loadDefaultExtensionIfNeeded()
        }
    }
    
    var additionalExtensions = [ConversationExtension]() {
        didSet {
            dockCollectionView.reloadSections(IndexSet(integer: 1))
            loadDefaultExtensionIfNeeded()
        }
    }
    
    var conversationViewController: ConversationViewController? {
        return parent as? ConversationViewController
    }
    
    private let cellReuseId = "extension"
    
    private var currentExtension: ConversationExtension?
    
    private var conversationId: String? {
        return conversationViewController?.conversationId
    }
    
    private lazy var photoViewController = PhotoConversationExtensionViewController()
    private lazy var callViewController = CallConversationExtensionViewController.instance()
    private lazy var contactViewController = ContactConversationExtensionViewController.instance()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dockCollectionView.allowsMultipleSelection = true
        dockCollectionView.dataSource = self
        dockCollectionView.delegate = self
    }
    
    private func loadDefaultExtensionIfNeeded() {
        guard currentExtension == nil, !fixedExtensions.isEmpty || !additionalExtensions.isEmpty else {
            return
        }
        func loadIndexPath(_ indexPath: IndexPath) {
            dockCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: .left)
            collectionView(dockCollectionView, didSelectItemAt: indexPath)
        }
        if !fixedExtensions.isEmpty {
            loadIndexPath(IndexPath(item: 0, section: 0))
        } else if !additionalExtensions.isEmpty {
            loadIndexPath(IndexPath(item: 0, section: 1))
        }
    }
    
}

extension ConversationExtensionContainerViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? fixedExtensions.count : additionalExtensions.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! ConversationExtensionCell
        if indexPath.section == 0 {
            cell.imageView.image = fixedExtensions[indexPath.row].image
        } else {
            cell.imageView.image = additionalExtensions[indexPath.row].icon
        }
        return cell
    }
    
}

extension ConversationExtensionContainerViewController: UICollectionViewDelegate {
    
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
                if let indexPaths = collectionView.indexPathsForSelectedItems {
                    for indexPath in indexPaths {
                        collectionView.deselectItem(at: indexPath, animated: false)
                    }
                }
                return true
            }
        } else {
            return true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let ext = fixedExtensions[indexPath.row]
            switch ext {
            case .photo:
                replaceEmbeddedViewController(with: photoViewController)
            case .file:
                break
            case .transfer:
                break
            case .contact:
                replaceEmbeddedViewController(with: contactViewController)
            case .call:
                replaceEmbeddedViewController(with: callViewController)
            }
        } else {
            let ext = additionalExtensions[indexPath.row]
            currentExtension = ext
            switch ext.content {
            case .embed(let controller):
                replaceEmbeddedViewController(with: controller)
            case .present(let controller):
                present(controller, animated: true, completion: nil)
            case .action(let action):
                break
            case .url(let url):
                break
            }
        }
    }
    
}

extension ConversationExtensionContainerViewController {
    
    private func replaceEmbeddedViewController(with vc: UIViewController) {
        for child in children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
        addChild(vc)
        containerView.addSubview(vc.view)
        vc.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        vc.didMove(toParent: self)
    }
    
}
