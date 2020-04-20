import UIKit

class PopupSearchableTableViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var tableView: UITableView!
    
    private var lastKeyword = ""
    
    private var keywordTextField: UITextField {
        return searchBoxView.textField
    }
    
    private var keyword: String {
        return (keywordTextField.text ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isSearching: Bool {
        return !keyword.isEmpty
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        keywordTextField.addTarget(self,
                                   action: #selector(searchAction(_:)),
                                   for: .editingChanged)
        
        updatePreferredContentSizeHeight()
        tableView.tableFooterView = UIView()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func searchAction(_ sender: Any) {
        let keyword = self.keyword
        guard keywordTextField.markedTextRange == nil else {
            if tableView.isDragging {
                tableView.reloadData()
            }
            return
        }
        guard !keyword.isEmpty else {
            tableView.reloadData()
            lastKeyword = ""
            return
        }
        guard keyword != lastKeyword else {
            return
        }
        lastKeyword = keyword
        updateSearchResults(keyword: keyword)
        tableView.reloadData()
    }
    
    func updateSearchResults(keyword: String) {
        
    }
    
    private func updatePreferredContentSizeHeight() {
        let window = AppDelegate.current.mainWindow
        preferredContentSize.height = window.bounds.height - window.safeAreaInsets.top - 56
    }
    
}
