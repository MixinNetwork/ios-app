import UIKit
import MixinServices

class PeerViewController<ModelType, CellType: PeerCell, SearchResultType: SearchResult>: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var tableView: UITableView!
    
    let queue = OperationQueue()
    let initDataOperation = BlockOperation()
    let headerReuseId = "header"
    
    var sectionTitles = [String]()
    var models = [ModelType]()
    
    var searchResults = [SearchResultType]()
    var searchingKeyword: String?
    
    var isSearching: Bool {
        return searchingKeyword != nil
    }
    
    convenience init() {
        self.init(nib: R.nib.peerView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(CellType.nib, forCellReuseIdentifier: CellType.reuseIdentifier)
        tableView.register(PeerHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseId)
        tableView.dataSource = self
        tableView.delegate = self
        searchBoxView.textField.addTarget(self, action: #selector(textFieldEditingChanged(_:)), for: .editingChanged)
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_contact()
        initData()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        searchResults.forEach { $0.updateTitleAndDescription() }
        if isSearching {
            tableView.reloadData()
        }
    }
    
    @objc func textFieldEditingChanged(_ textField: UITextField) {
        let trimmedLowercaseKeyword = (textField.text ?? "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !trimmedLowercaseKeyword.isEmpty else {
            searchingKeyword = nil
            tableView.reloadData()
            reloadTableViewSelections()
            return
        }
        guard trimmedLowercaseKeyword != searchingKeyword else {
            return
        }
        search(keyword: trimmedLowercaseKeyword)
    }
    
    func initData() {
        initDataOperation.addExecutionBlock { [weak self] in
            let users = UserDAO.shared.contacts()
            guard let weakSelf = self else {
                return
            }
            let catalogedModels = weakSelf.catalog(users: users)
            DispatchQueue.main.sync {
                weakSelf.sectionTitles = catalogedModels.titles
                weakSelf.models = catalogedModels.models
                weakSelf.tableView.reloadData()
            }
        }
        queue.addOperation(initDataOperation)
    }
    
    func catalog(users: [UserItem]) -> (titles: [String], models: [ModelType]) {
        return ([], [])
    }
    
    func search(keyword: String) {
        
    }
    
    func configure(cell: CellType, at indexPath: IndexPath) {
        
    }
    
    func reloadTableViewSelections() {
        tableView.indexPathsForSelectedRows?.forEach {
            tableView.deselectRow(at: $0, animated: false)
        }
    }
    
    func sectionIsEmpty(_ section: Int) -> Bool {
        return self.tableView(tableView, numberOfRowsInSection: section) == 0
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CellType.reuseIdentifier, for: indexPath) as! CellType
        configure(cell: cell, at: indexPath)
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 0
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !isSearching, !sectionTitles.isEmpty, !sectionIsEmpty(section) else {
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! PeerHeaderView
        header.label.text = sectionTitles[section]
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isSearching {
            return .leastNormalMagnitude
        } else if !sectionTitles.isEmpty {
            return sectionIsEmpty(section) ? .leastNormalMagnitude : 36
        } else {
            return .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        
    }
    
}
