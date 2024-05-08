import UIKit
import MixinServices

final class InscriptionViewController: UIViewController {
    
    let tableView = UITableView()
    var tableHeaderView: InfiniteTopView!
    
    private var inscription: InscriptionItem
    private var snapshot: SafeSnapshotItem
    private var columns: [Column] = []
    
    init(inscription: InscriptionItem, snapshot: SafeSnapshotItem) {
        self.inscription = inscription
        self.snapshot = snapshot
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func loadView() {
        self.view = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView = R.nib.snapshotTableHeaderView(withOwner: self)
        tableView.tableHeaderView = tableHeaderView
        
        // TODO
    }
    
    class func instance(inscription: InscriptionItem, snapshot: SafeSnapshotItem) -> UIViewController {
        let snapshot = InscriptionViewController(inscription: inscription, snapshot: snapshot)
        // FIX ME
        let container = ContainerViewController.instance(viewController: snapshot, title: R.string.localizable.transaction())
        return container
    }
    
}

extension InscriptionViewController {
    
    private struct Column {
        
        enum Key {
            
            case hash
            case id
            case token
            
            var localized: String {
                switch self {
                case .hash:
                    return "Hash"
                case .id:
                    return "ID"
                case .token:
                    return "Token"
                }
            }
            
        }
        
        struct Style: OptionSet {
            
            let rawValue: Int
            
            static let unavailable = Style(rawValue: 1 << 0)
            static let disclosureIndicator = Style(rawValue: 1 << 1)
            
        }
        
        let key: Key
        let value: String
        let style: Style
        
        var allowsCopy: Bool {
            let copyAllowedKeys: Set<Key> = [
                .hash, .id
            ]
            return copyAllowedKeys.contains(key)
        }
        
        init(key: Key, value: String, style: Style = []) {
            self.key = key
            self.value = value
            self.style = style
        }
        
    }
}
