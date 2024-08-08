import UIKit
import MixinServices

class PeerViewController<ModelType, CellType: PeerCell, SearchResultType: SearchResult>: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    class var showSelectionsOnTop: Bool {
        false
    }
    
    class var tableViewStyle: UITableView.Style {
        .plain
    }
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var centerWrapperView: UIView!
    
    @IBOutlet weak var searchBoxTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var centerWrapperViewHeightConstraint: NSLayoutConstraint!
    
    weak var centerWrapperViewBottomConstraint: NSLayoutConstraint!
    
    let queue = OperationQueue()
    let tableView: UITableView
    let initDataOperation = BlockOperation()
    let headerReuseId = "header"
    let selectedPeerReuseID = "selected_peer"
    
    lazy var collectionViewLayout = UICollectionViewFlowLayout()
    lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
    
    var sectionTitles = [String]()
    var models = [ModelType]()
    
    var searchResults = [[SearchResultType]]()
    var searchingKeyword: String?
    
    var isSearching: Bool {
        return searchingKeyword != nil
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        tableView = UITableView(frame: .zero, style: Self.tableViewStyle)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        tableView = UITableView(frame: .zero, style: Self.tableViewStyle)
        super.init(coder: coder)
    }
    
    convenience init() {
        let nib = R.nib.peerView
        self.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        centerWrapperViewBottomConstraint = tableView.topAnchor.constraint(equalTo: centerWrapperView.bottomAnchor)
        centerWrapperViewBottomConstraint.isActive = true
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight = 70
        tableView.register(CellType.nib, forCellReuseIdentifier: CellType.reuseIdentifier)
        tableView.register(PeerHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseId)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.sectionIndexColor = R.color.text_tertiary()!
        if Self.showSelectionsOnTop {
            collectionViewLayout.itemSize = CGSize(width: 66, height: 80)
            collectionViewLayout.minimumInteritemSpacing = 0
            collectionViewLayout.scrollDirection = .horizontal
            collectionView.backgroundColor = .background
            collectionView.alwaysBounceHorizontal = true
            collectionView.showsHorizontalScrollIndicator = false
            centerWrapperView.addSubview(collectionView)
            collectionView.snp.makeConstraints { (make) in
                make.centerY.equalToSuperview()
                make.leading.equalToSuperview().offset(20)
                make.trailing.equalToSuperview().offset(-20)
                make.height.equalTo(80)
            }
            collectionView.register(SelectedPeerCell.self,
                                    forCellWithReuseIdentifier: selectedPeerReuseID)
        }
        searchBoxView.textField.addTarget(self, action: #selector(textFieldEditingChanged(_:)), for: .editingChanged)
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_contact()
        initData()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        enumerateSearchResults { result, _, _ in
            result.updateTitleAndDescription()
        }
        if isSearching {
            tableView.reloadData()
        }
    }
    
    @objc func textFieldEditingChanged(_ textField: UITextField) {
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
                weakSelf.reloadTableViewSelections()
            }
        }
        queue.addOperation(initDataOperation)
    }
    
    func catalog(users: [UserItem]) -> (titles: [String], models: [ModelType]) {
        return ([], [])
    }
    
    func stopSearching() {
        searchingKeyword = nil
        tableView.reloadData()
        reloadTableViewSelections()
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
    
    func setCollectionViewHidden(_ hidden: Bool, animated: Bool) {
        centerWrapperViewHeightConstraint.constant = hidden ? 0 : 90
        if animated {
            UIView.animate(withDuration: 0.3, animations: view.layoutIfNeeded)
        } else {
            UIView.performWithoutAnimation(view.layoutIfNeeded)
        }
    }
    
    func enumerateSearchResults(_ block: (SearchResultType, IndexPath, inout Bool) -> Void) {
        for (section, searchResult) in searchResults.enumerated() {
            for (row, result) in searchResult.enumerated() {
                let indexPath = IndexPath(row: row, section: section)
                var stop = false
                block(result, indexPath, &stop)
                if stop {
                    return
                }
            }
        }
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
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isSearching {
            return .leastNormalMagnitude
        } else if !sectionTitles.isEmpty {
            return sectionIsEmpty(section) ? .leastNormalMagnitude : 36
        } else {
            return .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !isSearching, !sectionTitles.isEmpty, !sectionIsEmpty(section) else {
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! PeerHeaderView
        header.label.text = sectionTitles[section]
        return header
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
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
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        nil
    }
    
}
