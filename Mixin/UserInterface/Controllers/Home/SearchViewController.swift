import UIKit

class SearchViewController: UIViewController {

    enum ReuseId {
        static let header = "header"
        static let contact = "contact"
        static let conversation = "conversation"
        static let asset = "asset"
        static let footer = "footer"
    }
    
    @IBOutlet weak var searchBox: SearchBoxView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    private let searchImageView = UIImageView(image: #imageLiteral(resourceName: "ic_search"))
    private let headerHeight: CGFloat = 41
    
    private var allContacts = [UserItem]()
    private var users = [UserItem]()
    private var assets = [AssetItem]()
    private var conversations = [ConversationItem]()
    private var searchQueue = OperationQueue()
    private var contactsLoadingQueue = OperationQueue()
    
    private var textField: UITextField {
        return searchBox.textField
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchQueue.maxConcurrentOperationCount = 1
        contactsLoadingQueue.maxConcurrentOperationCount = 1
        tableView.register(GeneralTableViewHeader.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.register(UINib(nibName: "SearchResultContactCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.contact)
        tableView.register(UINib(nibName: "ConversationCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.conversation)
        tableView.register(UINib(nibName: "AssetCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.asset)
        tableView.register(SearchFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.footer)
        let tableHeaderView = UIView()
        tableHeaderView.frame = CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude)
        tableView.tableHeaderView = tableHeaderView
        tableView.tableFooterView = UIView()
//        tableView.dataSource = self
//        tableView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(contactsDidChange(_:)), name: .ContactsDidChange, object: nil)
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        guard !super.becomeFirstResponder() else {
            return false
        }
        return textField.becomeFirstResponder()
    }
    
    @IBAction func searchAction(_ sender: Any) {
        
    }

    func prepare() {

    }
    
    @objc func contactsDidChange(_ notification: Notification) {

    }
    
}
