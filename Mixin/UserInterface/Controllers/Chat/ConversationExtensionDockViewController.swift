import UIKit

class ConversationExtensionDockViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var fixedExtensions = [FixedExtension]() {
        didSet {
            collectionView.reloadSections(IndexSet(integer: Section.fixed.rawValue))
        }
    }
    
    var apps = [App]() {
        didSet {
            collectionView.reloadSections(IndexSet(integer: Section.apps.rawValue))
        }
    }
    
    var conversationViewController: ConversationViewController {
        return parent as! ConversationViewController
    }
    
    var defaultExtensionSection = Section.fixed
    
    private let cellReuseId = "extension"
    
    private var lastSelectedApp: App?
    private var conversationId: String {
        return conversationViewController.conversationId
    }
    private var selectedIndexPaths: [IndexPath] {
        return collectionView.indexPathsForSelectedItems ?? []
    }
    private var webViewControllerDidLoaded = false
    
    private lazy var photoViewController = PhotoConversationExtensionViewController.instance()
    private lazy var callViewController = CallConversationExtensionViewController.instance()
    private lazy var contactViewController = ContactConversationExtensionViewController.instance()
    private lazy var webViewController: WebViewController = {
        webViewControllerDidLoaded = true
        return WebViewController()
    }()
    
    deinit {
        if webViewControllerDidLoaded {
            webViewController.unload()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "ConversationDockCell", bundle: .main)
        collectionView.register(nib, forCellWithReuseIdentifier: cellReuseId)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    func loadDefaultExtensionIfNeeded() {
        guard selectedIndexPaths.isEmpty else {
            return
        }
        func load(section: Int) {
            let indexPath = IndexPath(item: 0, section: section)
            self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredHorizontally)
            self.collectionView(self.collectionView, didSelectItemAt: indexPath)
        }
        switch defaultExtensionSection {
        case .fixed:
            if fixedExtensions.isEmpty {
                fallthrough
            } else {
                load(section: Section.fixed.rawValue)
            }
        case .apps:
            if !apps.isEmpty {
                load(section: Section.fixed.rawValue)
            }
        }
    }
    
}

extension ConversationExtensionDockViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == Section.fixed.rawValue ? fixedExtensions.count : apps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! ConversationDockCell
        if indexPath.section == Section.fixed.rawValue {
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
        if indexPath.section == Section.fixed.rawValue {
            let ext = fixedExtensions[indexPath.row]
            if ext == .transfer {
                conversationViewController.transferAction()
                return false
            } else if ext == .file {
                conversationViewController.pickFileAction()
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
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == Section.fixed.rawValue {
            let ext = fixedExtensions[indexPath.row]
            switch ext {
            case .photo:
                conversationViewController.loadExtension(viewController: photoViewController)
            case .file, .transfer:
                break
            case .contact:
                conversationViewController.loadExtension(viewController: contactViewController)
            case .call:
                conversationViewController.loadExtension(viewController: callViewController)
            }
        } else {
            let app = apps[indexPath.row]
            webViewController.conversationId = conversationId
            if app !== lastSelectedApp, let url = URL(string: app.homeUri) {
                webViewController.load(url: url)
            }
            conversationViewController.loadExtension(viewController: webViewController)
            lastSelectedApp = app
        }
    }
    
}

extension ConversationExtensionDockViewController {
    
    private func removeAllSelections() {
        guard let indexPaths = collectionView.indexPathsForSelectedItems else {
            return
        }
        for indexPath in indexPaths {
            collectionView.deselectItem(at: indexPath, animated: false)
        }
    }
    
    enum Section: Int {
        case fixed = 0
        case apps = 1
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
