import UIKit

class TransactionHistoryFilterPickerViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var segmentControlWrapperView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var trayWrapperView: UIView!
    
    @IBOutlet weak var segmentControlWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var showSelectionConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideSelectionConstraint: NSLayoutConstraint!
    
    let queue = OperationQueue()
    
    private(set) var isShowingSelections = false
    
    private let trayView = R.nib.authenticationPreviewDoubleButtonTrayView(withOwner: nil)!
    
    var searchingKeyword: String?
    
    var isSearching: Bool {
        searchingKeyword != nil
    }
    
    init() {
        let nib = R.nib.transactionHistoryFilterPickerView
        super.init(nibName: nib.name, bundle: nib.bundle)
        queue.maxConcurrentOperationCount = 1
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBoxView.textField.addTarget(
            self,
            action: #selector(searchTextFieldEditingChanged(_:)),
            for: .editingChanged
        )
        searchBoxView.textField.delegate = self
        
        trayWrapperView.addSubview(trayView)
        trayView.snp.makeEdgesEqualToSuperview()
        trayView.leftButton.setTitle(R.string.localizable.reset(), for: .normal)
        trayView.leftButton.addTarget(self, action: #selector(reset(_:)), for: .touchUpInside)
        trayView.rightButton.setTitle(R.string.localizable.apply(), for: .normal)
        trayView.rightButton.addTarget(self, action: #selector(apply(_:)), for: .touchUpInside)
    }
    
    @objc func reset(_ sender: Any) {
        
    }
    
    @objc func apply(_ sender: Any) {
        
    }
    
    @objc func searchTextFieldEditingChanged(_ textField: UITextField) {
        let trimmedLowercaseKeyword = (textField.text ?? "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !trimmedLowercaseKeyword.isEmpty else {
            stopSearching()
            return
        }
        guard trimmedLowercaseKeyword != searchingKeyword else {
            return
        }
        search(keyword: trimmedLowercaseKeyword)
    }
    
    func stopSearching() {
        searchingKeyword = nil
        tableView.reloadData()
        reloadTableViewSelections()
    }
    
    func search(keyword: String) {
        
    }
    
    func hideSegmentControlWrapperView() {
        segmentControlWrapperHeightConstraint.constant = 15
        view.layoutIfNeeded()
    }
    
    func hideSelections() {
        guard isShowingSelections else {
            return
        }
        isShowingSelections = false
        hideSelectionConstraint.priority = .defaultHigh
        showSelectionConstraint.priority = .defaultLow
        UIView.animate(withDuration: 0.3, animations: view.layoutIfNeeded)
    }
    
    func showSelections(animated: Bool) {
        guard !isShowingSelections else {
            return
        }
        isShowingSelections = true
        hideSelectionConstraint.priority = .defaultLow
        showSelectionConstraint.priority = .defaultHigh
        if animated {
            UIView.animate(withDuration: 0.3, animations: view.layoutIfNeeded)
        } else {
            view.layoutIfNeeded()
        }
    }
    
    func reloadTableViewSelections() {
        tableView.indexPathsForSelectedRows?.forEach {
            tableView.deselectRow(at: $0, animated: false)
        }
    }
    
}

extension TransactionHistoryFilterPickerViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}
