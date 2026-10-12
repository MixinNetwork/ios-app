import UIKit
import MixinServices

final class DeleteAccountHintWindow: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    
    var onViewWallet: (() -> Void)?
    var onContinue: (() -> Void)?
    
    private let assets: [MixinTokenItem]
    private let maxTableHeight: CGFloat = AssetCell.height * 3
    
    init(assets: [MixinTokenItem]) {
        self.assets = assets
        let nib = R.nib.deleteAccountHintWindow
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.assetCell)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableViewHeightConstraint.constant = min(maxTableHeight, CGFloat(assets.count) * AssetCell.height)
    }
    
    @IBAction func closeAction(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func viewWalletAction(_ sender: Any) {
        let onViewWallet = self.onViewWallet
        dismiss(animated: true) {
            onViewWallet?()
        }
    }
    
    @IBAction func continueAction(_ sender: Any) {
        let onContinue = self.onContinue
        dismiss(animated: true) {
            onContinue?()
        }
    }
    
}

extension DeleteAccountHintWindow: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        assets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        if indexPath.row < assets.count {
            cell.render(token: assets[indexPath.row])
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        AssetCell.height
    }
    
}
