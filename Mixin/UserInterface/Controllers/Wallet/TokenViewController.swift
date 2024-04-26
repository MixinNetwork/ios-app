import UIKit
import MixinServices

final class TokenViewController: SafeSnapshotListViewController {
    
    private let tableHeaderView = R.nib.tokenTableHeaderView(withOwner: nil)!
    
    private(set) var token: TokenItem
    
    private var performSendOnAppear: Bool
    
    private lazy var filterController = SnapshotFilterViewController(sort: .createdAt)
    private lazy var noTransactionFooterView = Bundle.main.loadNibNamed("NoTransactionFooterView", owner: self, options: nil)?.first as! UIView
    
    init(token: TokenItem, performSendOnAppear: Bool) {
        self.token = token
        self.performSendOnAppear = performSendOnAppear
        super.init(displayFilter: .token(id: token.assetID))
        self.tokens[token.assetID] = token
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func instance(token: TokenItem, performSendOnAppear: Bool = false) -> UIViewController {
        let controller = TokenViewController(token: token, performSendOnAppear: performSendOnAppear)
        let container = ContainerViewController.instance(viewController: controller, title: token.name)
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.render(token: token)
        tableHeaderView.transferActionView.delegate = self
        tableHeaderView.filterButton.addTarget(self, action: #selector(presentFilter(_:)), for: .touchUpInside)
        tableHeaderView.tokenInfoButton.addTarget(self, action: #selector(showTokenInfo(_:)), for: .touchUpInside)
        let revealOutputsGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(revealOutputs(_:)))
        revealOutputsGestureRecognizer.numberOfTapsRequired = 5
        tableHeaderView.assetIconView.addGestureRecognizer(revealOutputsGestureRecognizer)
        reloadToken()
        NotificationCenter.default.addObserver(self, selector: #selector(balanceDidUpdate(_:)), name: UTXOService.balanceDidUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(assetsDidChange(_:)), name: TokenDAO.tokensDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(chainsDidChange(_:)), name: ChainDAO.chainsDidChangeNotification, object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshTokenJob(assetID: token.assetID))
        if #unavailable(iOS 15) {
            tableHeaderView.sizeToFit()
            tableView.tableHeaderView = tableHeaderView
        }
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        if #available(iOS 15.0, *) {
            view.layoutIfNeeded()
            tableHeaderView.sizeToFit()
            tableView.tableHeaderView = tableHeaderView
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #unavailable(iOS 15) {
            view.layoutIfNeeded()
            tableHeaderView.sizeToFit()
            tableView.tableHeaderView = tableHeaderView
        }
        if performSendOnAppear {
            performSendOnAppear = false
            DispatchQueue.main.async(execute: send)
        }
    }
    
    override func updateEmptyIndicator(numberOfItems: Int) {
        if numberOfItems == 0 {
            tableHeaderView.transactionsHeaderView.isHidden = false
            noTransactionFooterView.frame.size.height = tableView.frame.height
            - tableView.contentSize.height
            - tableView.adjustedContentInset.vertical
            tableView.tableFooterView = noTransactionFooterView
        } else {
            tableHeaderView.transactionsHeaderView.isHidden = false
            tableView.tableFooterView = nil
        }
    }
    
    @objc private func presentFilter(_ sender: Any) {
        filterController.delegate = self
        present(filterController, animated: true, completion: nil)
    }
    
    @objc private func showTokenInfo(_ sender: Any) {
        AssetInfoWindow.instance().presentWindow(asset: token)
    }
    
    @objc private func balanceDidUpdate(_ notification: Notification) {
        guard let id = notification.userInfo?[UTXOService.assetIDUserInfoKey] as? String else {
            return
        }
        guard id == token.assetID else {
            return
        }
        reloadToken()
    }
    
    @objc private func assetsDidChange(_ notification: Notification) {
        guard let id = notification.userInfo?[TokenDAO.UserInfoKey.assetId] as? String else {
            return
        }
        guard id == token.assetID else {
            return
        }
        reloadToken()
    }
    
    @objc private func chainsDidChange(_ notification: Notification) {
        guard let id = notification.userInfo?[ChainDAO.UserInfoKey.chainId] as? String else {
            return
        }
        guard id == token.chainID else {
            return
        }
        reloadToken()
    }
    
    @objc private func revealOutputs(_ sender: Any) {
        let outputs = OutputsViewController(token: token)
        let container = ContainerViewController.instance(viewController: outputs, title: "Outputs")
        navigationController?.pushViewController(container, animated: true)
    }
    
}

extension TokenViewController: TransferActionViewDelegate {
    
    func transferActionView(_ view: TransferActionView, didSelect action: TransferActionView.Action) {
        switch action {
        case .send:
            send()
        case .receive:
            let deposit = DepositViewController.instance(token: token)
            navigationController?.pushViewController(deposit, animated: true)
        }
    }
    
}

extension TokenViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
    func barRightButtonTappedAction() {
        let token = self.token
        let wasHidden = token.isHidden
        let title = wasHidden ? R.string.localizable.show_asset() : R.string.localizable.hide_asset()
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: title, style: .default, handler: { _ in
            DispatchQueue.global().async {
                let extra = TokenExtra(assetID: token.assetID,
                                       kernelAssetID: token.kernelAssetID,
                                       isHidden: !wasHidden,
                                       balance: token.balance,
                                       updatedAt: Date().toUTCString())
                TokenExtraDAO.shared.insertOrUpdateHidden(extra: extra)
            }
            self.navigationController?.popViewController(animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        self.present(sheet, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        return R.image.ic_title_more()
    }
    
}

extension TokenViewController: SnapshotFilterViewController.Delegate {
    
    func snapshotFilterViewController(_ controller: SnapshotFilterViewController, didApplySort sort: Snapshot.Sort) {
        tableView.setContentOffset(.zero, animated: false)
        reloadData(with: sort)
    }
    
}

extension TokenViewController: SnapshotCellDelegate {
    
    func walletSnapshotCellDidSelectIcon(_ cell: SnapshotCell) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let snapshotID = dataSource.itemIdentifier(for: indexPath),
            let snapshot = items[snapshotID]
        else {
            return
        }
        guard let userId = snapshot.opponentUserID else {
            return
        }
        DispatchQueue.global().async {
            guard let user = UserDAO.shared.getUser(userId: userId) else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                let vc = UserProfileViewController(user: user)
                self?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
}

extension TokenViewController {
    
    private func send() {
        let token = self.token
        let selector = SendingDestinationSelectorViewController(destinations: [.address, .contact]) { destination in
            switch destination {
            case .address:
                let address = AddressViewController.instance(token: token)
                self.navigationController?.pushViewController(address, animated: true)
            case .contact:
                let receiver = TransferReceiverViewController.instance(asset: token)
                self.navigationController?.pushViewController(receiver, animated: true)
            }
        }
        present(selector, animated: true, completion: nil)
    }
    
    private func reloadToken() {
        let assetId = token.assetID
        DispatchQueue.global().async { [weak self] in
            guard let token = TokenDAO.shared.tokenItem(with: assetId) else {
                return
            }
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.token = token
                UIView.performWithoutAnimation {
                    self.tableHeaderView.render(token: token)
                    self.tableHeaderView.sizeToFit()
                }
            }
        }
    }
    
}
