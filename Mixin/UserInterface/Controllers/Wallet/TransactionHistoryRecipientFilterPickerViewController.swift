import UIKit
import MixinServices

protocol TransactionHistoryRecipientFilterPickerViewControllerDelegate: AnyObject {
    
    func transactionHistoryRecipientFilterPickerViewController(
        _ controller: TransactionHistoryRecipientFilterPickerViewController,
        didPickUsers users: [UserItem],
        addresses: [AddressItem]
    )
    
}

final class TransactionHistoryRecipientFilterPickerViewController: TransactionHistoryFilterPickerViewController {
    
    enum Segment: Int, CaseIterable {
        case user
        case address
    }
    
    private enum ReuseIdentifier {
        static let selectedPeer = "sp"
        static let selectedToken = "st"
    }
    
    weak var delegate: TransactionHistoryRecipientFilterPickerViewControllerDelegate?
    
    private typealias SelectionSection = Segment
    
    private let segments: Set<Segment>
    private let segmentButtonHeight: CGFloat = 38
    
    private weak var userSegmentButton: UIButton?
    private weak var addressSegmentButton: UIButton?
    
    private var currentSegment: Segment
    
    private var users: [UserItem] = []
    private var selectedUserIDs: Set<String> = []
    private var selectedUsers: [UserItem] = []
    
    private var addresses: [AddressItem] = []
    private var selectedAddressIDs: Set<String> = []
    private var selectedAddresses: [AddressItem] = []
    
    private var userSearchResults: [UserItem] = []
    private var addressSearchResults: [AddressItem] = []
    
    private var userModels: [UserItem] {
        isSearching ? userSearchResults : users
    }
    private var addressModels: [AddressItem] {
        isSearching ? addressSearchResults : addresses
    }
    
    init(segments: Set<Segment>, users: [UserItem], addresses: [AddressItem]) {
        self.segments = segments
        self.currentSegment = segments.contains(.user) ? .user : .address
        super.init()
        if segments.contains(.user) {
            self.selectedUserIDs = Set(users.map(\.userId))
            self.selectedUsers = users
        }
        if segments.contains(.address) {
            self.selectedAddressIDs = Set(addresses.map(\.addressId))
            self.selectedAddresses = addresses
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if segments.isEmpty {
            hideSegmentControlWrapperView()
        } else {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.spacing = 10
            segmentControlWrapperView.addSubview(stackView)
            stackView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(25)
                make.leading.equalToSuperview().offset(20)
                make.height.equalTo(segmentButtonHeight)
            }
            if segments.contains(.user) {
                let button = makeSegmentButton(title: R.string.localizable.contact())
                stackView.addArrangedSubview(button)
                button.addTarget(self, action: #selector(switchToUsers(_:)), for: .touchUpInside)
                button.isSelected = true
                userSegmentButton = button
                searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_contact()
            }
            if segments.contains(.address) {
                let button = makeSegmentButton(title: R.string.localizable.address())
                stackView.addArrangedSubview(button)
                button.addTarget(self, action: #selector(switchToAddress(_:)), for: .touchUpInside)
                addressSegmentButton = button
                if !segments.contains(.user) {
                    button.isSelected = true
                    searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_address()
                }
            }
        }
        
        tableView.register(CheckmarkPeerCell.nib, forCellReuseIdentifier: CheckmarkPeerCell.reuseIdentifier)
        tableView.register(R.nib.checkmarkTokenCell)
        tableView.dataSource = self
        tableView.delegate = self
        
        collectionView.register(SelectedPeerCell.self, forCellWithReuseIdentifier: ReuseIdentifier.selectedPeer)
        collectionView.register(SelectedTokenCell.self, forCellWithReuseIdentifier: ReuseIdentifier.selectedToken)
        collectionView.dataSource = self
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        if selectedUsers.count + selectedAddresses.count > 0 {
            showSelections(animated: false)
        }
        
        if segments.contains(.user) {
            queue.addOperation { [weak self] in
                let users = UserDAO.shared.contacts()
                DispatchQueue.main.sync {
                    // Do not check cancellation, init op is not cancellable
                    guard let self else {
                        return
                    }
                    self.users = users
                    if self.currentSegment == .user {
                        self.reloadCurrentSegment()
                    }
                }
            }
        }
        if segments.contains(.address) {
            queue.addOperation() { [weak self] in
                let addresses = AddressDAO.shared.addressItems()
                DispatchQueue.main.sync {
                    // Do not check cancellation, init op is not cancellable
                    guard let self else {
                        return
                    }
                    self.addresses = addresses
                    if self.currentSegment == .address {
                        self.reloadCurrentSegment()
                    }
                }
            }
        }
    }
    
    override func reloadTableViewSelections() {
        super.reloadTableViewSelections()
        var indexPaths: [IndexPath] = []
        switch currentSegment {
        case .user:
            for (row, user) in userModels.enumerated() where selectedUserIDs.contains(user.userId) {
                let indexPath = IndexPath(row: row, section: 0)
                indexPaths.append(indexPath)
            }
        case .address:
            for (row, address) in addressModels.enumerated() where selectedAddressIDs.contains(address.addressId) {
                let indexPath = IndexPath(row: row, section: 0)
                indexPaths.append(indexPath)
            }
        }
        for indexPath in indexPaths {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }
    
    override func reset(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.transactionHistoryRecipientFilterPickerViewController(self, didPickUsers: [], addresses: [])
    }
    
    override func apply(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.transactionHistoryRecipientFilterPickerViewController(self, didPickUsers: selectedUsers, addresses: selectedAddresses)
    }
    
    override func search(keyword: String) {
        queue.cancelAllOperations()
        let op = BlockOperation()
        switch currentSegment {
        case .user:
            let users = self.users
            op.addExecutionBlock { [unowned op, weak self] in
                let searchResults = users.filter {
                    $0.matches(lowercasedKeyword: keyword)
                }
                DispatchQueue.main.sync {
                    guard let self, !op.isCancelled, self.currentSegment == .user else {
                        return
                    }
                    self.searchingKeyword = keyword
                    self.userSearchResults = searchResults
                    self.tableView.reloadData()
                    self.reloadTableViewSelections()
                }
            }
        case .address:
            let addresses = self.addresses
            op.addExecutionBlock { [unowned op, weak self] in
                let searchResults = addresses.filter {
                    $0.matches(lowercasedKeyword: keyword)
                }
                DispatchQueue.main.sync {
                    guard let self, !op.isCancelled, self.currentSegment == .address else {
                        return
                    }
                    self.searchingKeyword = keyword
                    self.addressSearchResults = searchResults
                    self.tableView.reloadData()
                    self.reloadTableViewSelections()
                }
            }
        }
        queue.addOperation(op)
    }
    
    @objc private func switchToUsers(_ sender: Any) {
        guard currentSegment != .user else {
            return
        }
        currentSegment = .user
        userSegmentButton?.isSelected = true
        addressSegmentButton?.isSelected = false
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_contact()
        searchBoxView.textField.text = nil
        searchingKeyword = nil
        reloadCurrentSegment()
    }
    
    @objc private func switchToAddress(_ sender: Any) {
        guard currentSegment != .address else {
            return
        }
        currentSegment = .address
        userSegmentButton?.isSelected = false
        addressSegmentButton?.isSelected = true
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_address()
        searchBoxView.textField.text = nil
        searchingKeyword = nil
        reloadCurrentSegment()
    }
    
    private func makeSegmentButton(title: String) -> OutlineButton {
        let button = OutlineButton()
        button.layer.masksToBounds = true
        button.layer.cornerRadius = segmentButtonHeight / 2
        button.setTitle(title, for: .normal)
        button.setTitleColor(R.color.text(), for: .normal)
        button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        return button
    }
    
    private func reloadCurrentSegment() {
        tableView.rowHeight = switch currentSegment {
        case .user:
            70
        case .address:
            UITableView.automaticDimension
        }
        tableView.reloadData()
        reloadTableViewSelections()
    }
    
}

extension TransactionHistoryRecipientFilterPickerViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch currentSegment {
        case .user:
            userModels.count
        case .address:
            addressModels.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch currentSegment {
        case .user:
            let cell = tableView.dequeueReusableCell(withIdentifier: CheckmarkPeerCell.reuseIdentifier) as! CheckmarkPeerCell
            let user = userModels[indexPath.row]
            cell.render(user: user)
            cell.setSelected(selectedUserIDs.contains(user.userId), animated: false)
            return cell
        case .address:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.checkmark_token, for: indexPath)!
            let address = addressModels[indexPath.row]
            cell.load(address: address)
            return cell
        }
    }
    
}

extension TransactionHistoryRecipientFilterPickerViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch currentSegment {
        case .user:
            let user = userModels[indexPath.row]
            let (inserted, _) = selectedUserIDs.insert(user.userId)
            if inserted {
                let indexPath = IndexPath(item: selectedUsers.count, section: SelectionSection.user.rawValue)
                selectedUsers.append(user)
                collectionView.insertItems(at: [indexPath])
            }
        case .address:
            let address = addressModels[indexPath.row]
            let (inserted, _) = selectedAddressIDs.insert(address.addressId)
            if inserted {
                let indexPath = IndexPath(item: selectedAddresses.count, section: SelectionSection.address.rawValue)
                selectedAddresses.append(address)
                collectionView.insertItems(at: [indexPath])
            }
        }
        showSelections(animated: true)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        switch currentSegment {
        case .user:
            let user = userModels[indexPath.row]
            selectedUserIDs.remove(user.userId)
            if let index = selectedUsers.firstIndex(where: { $0.userId == user.userId }) {
                selectedUsers.remove(at: index)
                let indexPath = IndexPath(item: index, section: SelectionSection.user.rawValue)
                collectionView.deleteItems(at: [indexPath])
            }
            if selectedUserIDs.isEmpty {
                hideSelections()
            }
        case .address:
            let address = addressModels[indexPath.row]
            selectedAddressIDs.remove(address.addressId)
            if let index = selectedAddresses.firstIndex(where: { $0.addressId == address.addressId }) {
                selectedAddresses.remove(at: index)
                let indexPath = IndexPath(item: index, section: SelectionSection.address.rawValue)
                collectionView.deleteItems(at: [indexPath])
            }
            if selectedAddressIDs.isEmpty {
                hideSelections()
            }
        }
    }
    
}

extension TransactionHistoryRecipientFilterPickerViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        SelectionSection.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch SelectionSection(rawValue: section)! {
        case .user:
            selectedUsers.count
        case .address:
            selectedAddresses.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch SelectionSection(rawValue: indexPath.section)! {
        case .user:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReuseIdentifier.selectedPeer, for: indexPath) as! SelectedPeerCell
            let user = selectedUsers[indexPath.item]
            cell.render(item: user)
            cell.delegate = self
            return cell
        case .address:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReuseIdentifier.selectedToken, for: indexPath) as! SelectedTokenCell
            let address = selectedAddresses[indexPath.item]
            cell.load(address: address)
            cell.delegate = self
            return cell
        }
    }
    
}

extension TransactionHistoryRecipientFilterPickerViewController: SelectedItemCellDelegate {
    
    func selectedItemCellDidSelectRemove(_ cell: UICollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        switch SelectionSection(rawValue: indexPath.section)! {
        case .user:
            let deselected = selectedUsers.remove(at: indexPath.row)
            selectedUserIDs.remove(deselected.userId)
            collectionView.deleteItems(at: [indexPath])
            if currentSegment == .user {
                if let row = userModels.firstIndex(where: { $0.userId == deselected.userId }) {
                    let indexPath = IndexPath(row: row, section: 0)
                    tableView.deselectRow(at: indexPath, animated: true)
                }
                if selectedUserIDs.isEmpty {
                    hideSelections()
                }
            }
        case .address:
            let deselected = selectedAddresses.remove(at: indexPath.row)
            selectedAddressIDs.remove(deselected.addressId)
            collectionView.deleteItems(at: [indexPath])
            if currentSegment == .address {
                if let row = addressModels.firstIndex(where: { $0.addressId == deselected.addressId }) {
                    let indexPath = IndexPath(row: row, section: 0)
                    tableView.deselectRow(at: indexPath, animated: true)
                }
                if selectedAddressIDs.isEmpty {
                    hideSelections()
                }
            }
        }
    }
    
}
