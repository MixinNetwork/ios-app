import UIKit

class ConversationExtensionViewController: UIViewController {
    
    @IBOutlet weak var dockCollectionView: UICollectionView!
    @IBOutlet weak var containerView: UIView!
    
    var fixedExtensions = [ConversationExtension]() {
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
    
    private let cellReuseId = "extension"
    
    private var currentExtension: ConversationExtension?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dockCollectionView.dataSource = self
    }
    
    private func conversationExtension(at indexPath: IndexPath) -> ConversationExtension {
        if indexPath.section == 0 {
            return fixedExtensions[indexPath.row]
        } else {
            return additionalExtensions[indexPath.row]
        }
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

extension ConversationExtensionViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? fixedExtensions.count : additionalExtensions.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! ConversationExtensionCell
        cell.imageView.image = conversationExtension(at: indexPath).icon
        return cell
    }
    
}

extension ConversationExtensionViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let ext = conversationExtension(at: indexPath)
        currentExtension = ext
        switch ext.content {
        case .action(let action):
            break
        case .url(let url):
            break
        case .viewController(let controller):
            for vc in children {
                vc.willMove(toParent: nil)
                vc.view.removeFromSuperview()
                vc.removeFromParent()
            }
            addChild(controller)
            containerView.addSubview(controller.view)
            controller.view.snp.makeConstraints({ (make) in
                make.edges.equalToSuperview()
            })
            controller.didMove(toParent: self)
        }
    }
    
}
